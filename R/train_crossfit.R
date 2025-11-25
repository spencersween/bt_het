#' Multi-fold cross-fitting for heterogeneous Bradley-Terry with Hessian net
#'
#' For each fold s in S:
#'   - Train BT net and Hessian net on S != s (with 10% validation).
#'   - Predict λ(X), p(X), and H(X) on S == s only.
#'   - Aggregate to get out-of-fold (OOF) estimates for all i.
#'
#' @param X Feature matrix (n x p)
#' @param D Design matrix (n x k_minus_1)
#' @param Y Outcome vector (n)
#' @param S Fold assignment vector (n)
#' @param hidden_bt Hidden layers for BT net (default: c(256, 128))
#' @param dropout_bt Dropout for BT net (default: 0.10)
#' @param use_batchnorm_bt Batch norm for BT net (default: FALSE)
#' @param hidden_h Hidden layers for Hessian net (default: c(128, 64))
#' @param dropout_h Dropout for Hessian net (default: 0.10)
#' @param use_batchnorm_h Batch norm for Hessian net (default: FALSE)
#' @param lr_bt Learning rate for BT net (default: 1e-3)
#' @param lr_h Learning rate for Hessian net (default: 1e-3)
#' @param weight_decay_bt Weight decay for BT net (default: 1e-2)
#' @param weight_decay_h Weight decay for Hessian net (default: 1e-2)
#' @param batch_size_bt Batch size for BT net (default: 2048)
#' @param batch_size_h Batch size for Hessian net (default: 2048)
#' @param max_epochs_bt Max epochs for BT net (default: 200)
#' @param max_epochs_h Max epochs for Hessian net (default: 200)
#' @param patience_bt Patience for BT net (default: 15)
#' @param patience_h Patience for Hessian net (default: 15)
#' @param hess_ridge Ridge regularization for Hessian inversion (default: 1e-6)
#' @param device Device ("cpu" or "cuda", default: auto-detect)
#' @param verbose Whether to print progress (default: TRUE)
#' @return List with OOF predictions, models, and histories
#' @export
train_crossfit = function(X, D, Y, S,
                          hidden_bt        = c(256, 128),
                          dropout_bt       = 0.10,
                          use_batchnorm_bt = FALSE,
                          hidden_h         = c(128, 64),
                          dropout_h        = 0.10,
                          use_batchnorm_h  = FALSE,
                          lr_bt            = 1e-3,
                          lr_h             = 1e-3,
                          weight_decay_bt  = 1e-2,
                          weight_decay_h   = 1e-2,
                          batch_size_bt    = 2048,
                          batch_size_h     = 2048,
                          max_epochs_bt    = 200,
                          max_epochs_h     = 200,
                          patience_bt      = 15,
                          patience_h       = 15,
                          hess_ridge       = 1e-6,
                          device           = NULL,
                          verbose          = TRUE) {
  
  if (is.null(device)) device = if (cuda_is_available()) "cuda" else "cpu"
  
  n         = nrow(X)
  p         = ncol(X)
  k_minus_1 = ncol(D)
  stopifnot(nrow(D) == n, length(Y) == n)
  
  if (verbose) {
    cat("============================================================\n")
    cat("Starting multi-fold heterogeneous BT with Hessian net\n")
    cat("============================================================\n")
  }
  
  folds = sort(unique(S))
  
  # Precompute lower-tri indices used in Hessian stage
  idx_lower = lower_tri_indices(k_minus_1)
  num_lower = nrow(idx_lower)
  if (verbose) {
    cat(sprintf("Hessian lower-tri dimension: %d (k_minus_1 = %d)\n",
                num_lower, k_minus_1))
  }
  
  # Containers for OOF predictions
  oof_prob_stage1 = rep(NA_real_, n)
  oof_eta_stage1  = rep(NA_real_, n)
  oof_lambda      = matrix(NA_real_, nrow = n, ncol = k_minus_1)
  colnames(oof_lambda) = colnames(D)
  
  oof_Hbar_cols = array(NA_real_, dim = c(n, k_minus_1, k_minus_1))
  oof_psi       = matrix(NA_real_, nrow = n, ncol = k_minus_1)
  colnames(oof_psi) = colnames(D)
  
  # For histories
  fold_models_bt = list()
  fold_hist_bt   = list()
  fold_models_h  = list()
  fold_hist_h    = list()
  
  for (fold_idx in seq_along(folds)) {
    s = folds[fold_idx]
    
    if (verbose) {
      cat(sprintf("\n============================================================\n"))
      cat(sprintf("Outer fold %d / %d: S == %s held out as test\n", fold_idx, length(folds), s))
      cat("============================================================\n")
    }
    
    test_idx  = which(S == s)
    train_idx = which(S != s)
    
    if (length(test_idx) == 0L) {
      warning("Fold ", s, " has zero test observations, skipping.")
      next
    }
    if (length(train_idx) <= 1L) {
      stop("Not enough training data for fold S == ", s)
    }
    
    if (verbose) {
      cat(sprintf("Test size:   %d\n", length(test_idx)))
      cat(sprintf("Train size:  %d\n", length(train_idx)))
    }
    
    # 10% validation within training
    set.seed(20240601 + as.integer(s))
    val_size = max(1L, floor(0.10 * length(train_idx)))
    val_idx  = sample(train_idx, size = val_size, replace = FALSE)
    core_train_idx = setdiff(train_idx, val_idx)
    
    if (verbose) {
      cat(sprintf("Validation size: %d (%.1f%% of training)\n",
                  length(val_idx),
                  100 * length(val_idx) / length(train_idx)))
      cat(sprintf("Core training size: %d\n", length(core_train_idx)))
    }
    
    # --------------------------------------------------------
    # Stage 1: preference network λ(X)
    # --------------------------------------------------------
    if (verbose) {
      cat("\n------------------------------------------------------------\n")
      cat("Stage 1: Training preference (BT) network on this fold's training set\n")
      cat("------------------------------------------------------------\n")
    }
    
    bt_fit = train_bt_single(
      X           = X,
      D           = D,
      Y           = Y,
      train_idx   = core_train_idx,
      val_idx     = val_idx,
      hidden      = hidden_bt,
      dropout     = dropout_bt,
      use_batchnorm = use_batchnorm_bt,
      lr          = lr_bt,
      weight_decay = weight_decay_bt,
      batch_size  = batch_size_bt,
      max_epochs  = max_epochs_bt,
      patience    = patience_bt,
      device      = device,
      verbose     = verbose
    )
    bt_model = bt_fit$model
    hist_bt  = bt_fit$history
    
    fold_models_bt[[as.character(s)]] = bt_model
    fold_hist_bt[[as.character(s)]]   = hist_bt
    
    if (verbose) cat("\nStage 1: Predicting λ(X), p(X) on this fold's test set...\n")
    bt_pred_test = predict_bt_full(
      bt_model,
      X[test_idx, , drop = FALSE],
      D[test_idx, , drop = FALSE],
      batch_size = batch_size_bt,
      device     = device
    )
    
    oof_prob_stage1[test_idx] = bt_pred_test$prob
    oof_eta_stage1[test_idx]  = bt_pred_test$eta
    oof_lambda[test_idx, ]    = bt_pred_test$lambda
    
    # --------------------------------------------------------
    # Stage 2: Hessian net for E[D_i D_j | X_i] (lower-tri)
    # --------------------------------------------------------
    if (verbose) {
      cat("\n------------------------------------------------------------\n")
      cat("Stage 2: Training Hessian network on this fold's training set\n")
      cat("------------------------------------------------------------\n")
    }
    
    h_fit = train_hessian_lower_single(
      X           = X,
      D           = D,
      train_idx   = core_train_idx,
      val_idx     = val_idx,
      idx_lower   = idx_lower,
      hidden      = hidden_h,
      dropout     = dropout_h,
      use_batchnorm = use_batchnorm_h,
      lr          = lr_h,
      weight_decay = weight_decay_h,
      batch_size  = batch_size_h,
      max_epochs  = max_epochs_h,
      patience    = patience_h,
      device      = device,
      verbose     = verbose
    )
    h_model = h_fit$model
    hist_h  = h_fit$history
    
    fold_models_h[[as.character(s)]] = h_model
    fold_hist_h[[as.character(s)]]   = hist_h
    
    if (verbose) cat("\nStage 2: Predicting E[D_i D_j | X_i] (lower-tri) on this fold's test set...\n")
    EH_lower_test = predict_hessian_lower(
      h_model,
      X[test_idx, , drop = FALSE],
      batch_size = batch_size_h,
      device     = device
    )
    
    stopifnot(nrow(EH_lower_test) == length(test_idx),
              ncol(EH_lower_test) == num_lower)
    
    # --------------------------------------------------------
    # Construct conditional Hessian H_i = Var(Y|X_i) * E[D D' | X_i]
    # for test observations in this fold
    # --------------------------------------------------------
    if (verbose) cat("\nConstructing conditional Hessian matrices for this fold's test set...\n")
    
    for (k in seq_along(test_idx)) {
      i = test_idx[k]
      p_i = oof_prob_stage1[i]
      if (!is.finite(p_i)) next
      v_i = p_i * (1 - p_i)
      
      lower_vec_i = EH_lower_test[k, ]
      M_i         = lower_to_full(lower_vec_i, idx_lower, k_minus_1)
      
      H_i = v_i * M_i
      H_i = 0.5 * (H_i + t(H_i))
      oof_Hbar_cols[i, , ] = H_i
    }
  } # end loop over folds
  
  # --------------------------------------------------------
  # Influence function ψ_i = λ̂(X_i) − H_i^{-1} J_i
  # OOF because λ̂ and H_i for each i come from the fold that held i out.
  # --------------------------------------------------------
  if (verbose) cat("\nComputing out-of-fold influence functions for all observations...\n")
  
  for (i in seq_len(n)) {
    if (any(is.na(oof_Hbar_cols[i, , ]))) next
    
    p_i = oof_prob_stage1[i]
    y_i = Y[i]
    D_i = D[i, ]
    
    grad_i = (p_i - y_i) * D_i
    
    H_i    = oof_Hbar_cols[i, , ]
    H_i    = 0.5 * (H_i + t(H_i))
    H_i_reg = H_i + diag(hess_ridge, k_minus_1)
    
    delta_i = tryCatch(
      solve(H_i_reg, grad_i),
      error = function(e) MASS::ginv(H_i_reg) %*% grad_i
    )
    
    oof_psi[i, ] = oof_lambda[i, ] - as.numeric(delta_i)
  }
  
  if (verbose) {
    cat("\n============================================================\n")
    cat("Finished multi-fold cross-fitting and influence computation\n")
    cat("============================================================\n")
  }
  
  list(
    oof_prob_stage1 = oof_prob_stage1,
    oof_eta_stage1  = oof_eta_stage1,
    oof_lambda      = oof_lambda,
    oof_psi         = oof_psi,
    oof_Hbar_cols   = oof_Hbar_cols,
    models_bt       = fold_models_bt,
    history_bt      = fold_hist_bt,
    models_h        = fold_models_h,
    history_h       = fold_hist_h
  )
}

