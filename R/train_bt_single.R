#' Train a single Bradley-Terry network
#'
#' @param X Feature matrix (n x p)
#' @param D Design matrix (n x k_minus_1)
#' @param Y Outcome vector (n)
#' @param train_idx Training indices
#' @param val_idx Validation indices
#' @param hidden Hidden layer sizes (vector)
#' @param dropout Dropout rates (scalar or vector)
#' @param use_batchnorm Whether to use batch normalization
#' @param lr Learning rate
#' @param weight_decay Weight decay
#' @param batch_size Batch size
#' @param max_epochs Maximum epochs
#' @param patience Early stopping patience
#' @param device Device ("cpu" or "cuda")
#' @param verbose Whether to print progress
#' @param live_plot Whether to show live plot window (default: FALSE)
#' @param plot_file Optional file path to save live plot PNG (default: NULL)
#' @return List with model and training history
#' @export
train_bt_single = function(X, D, Y,
                           train_idx, val_idx,
                           hidden, dropout, use_batchnorm,
                           lr, weight_decay,
                           batch_size,
                           max_epochs, patience,
                           device,
                           verbose = TRUE,
                           live_plot = FALSE,
                           plot_file = NULL) {
  
  p         = ncol(X)
  k_minus_1 = ncol(D)
  
  X_tr = X[train_idx, , drop = FALSE]
  X_va = X[val_idx,   , drop = FALSE]
  D_tr = D[train_idx, , drop = FALSE]
  D_va = D[val_idx,   , drop = FALSE]
  Y_tr = as.numeric(Y[train_idx])
  Y_va = as.numeric(Y[val_idx])
  
  train_loader = make_loader(X_tr, D_tr, Y_tr, batch_size = batch_size, shuffle = TRUE)
  val_loader   = make_loader(X_va, D_va, Y_va, batch_size = batch_size, shuffle = FALSE)
  
  model = bt_net(
    p             = p,
    k_minus_1     = k_minus_1,
    hidden        = hidden,
    dropout       = dropout,
    use_batchnorm = use_batchnorm
  )
  model$to(device = device)
  
  opt = optim_adamw(
    params       = model$parameters,
    lr           = lr,
    weight_decay = weight_decay
  )
  
  best_val          = Inf
  best_state        = NULL
  epochs_no_improve = 0
  hist = data.frame(epoch = integer(), train_loss = double(), val_loss = double())
  
  # Initialize live plotting if requested
  plot_env = NULL
  if (live_plot) {
    if (is.null(plot_file)) {
      plot_file = "plots/training_live_stage1.png"
    }
    plot_env = init_live_plot(
      title = "[Stage 1] BT Network Training",
      device = if (interactive()) "both" else "png",
      plot_file = plot_file
    )
  }
  
  for (epoch in 1:max_epochs) {
    model$train()
    run_loss = 0
    seen     = 0
    
    coro::loop(for (batch in train_loader) {
      x      = batch$x$to(device = device)
      design = batch$design$to(device = device)
      y      = batch$y$to(device = device)
      if (length(y$size()) != 1) y = y$view(c(-1))
      
      opt$zero_grad()
      lambda_hat = model(x)
      eta        = compute_eta_vec(lambda_hat, design)
      loss       = bce_logits_vec(eta, y)
      loss$backward()
      opt$step()
      
      bs       = as.integer(y$size()[1])
      run_loss = run_loss + as.numeric(loss$item()) * bs
      seen     = seen + bs
    })
    
    train_loss = run_loss / seen
    val_loss   = evaluate_loader(model, val_loader, device = device)
    
    hist = rbind(
      hist,
      data.frame(epoch = epoch, train_loss = train_loss, val_loss = val_loss)
    )
    
    # Update live plot if enabled
    if (live_plot && !is.null(plot_env)) {
      update_live_plot(plot_env, epoch, train_loss, val_loss, max_epochs)
    }
    
    if (val_loss + 1e-8 < best_val) {
      best_val          = val_loss
      best_state        = model$state_dict()
      epochs_no_improve = 0
    } else {
      epochs_no_improve = epochs_no_improve + 1
    }
    
    if (verbose) {
      cat(sprintf("  [Stage 1] epoch %03d  train=%.6f  val=%.6f\n", epoch, train_loss, val_loss))
    }
    if (epochs_no_improve >= patience) {
      if (verbose) cat(sprintf("  [Stage 1] early stopping at epoch %d (best val=%.6f)\n", epoch, best_val))
      break
    }
  }
  
  if (!is.null(best_state)) model$load_state_dict(best_state)
  
  # Close live plot if enabled
  if (live_plot && !is.null(plot_env)) {
    close_live_plot(plot_env)
  }
  
  list(model = model$to(device = "cpu"), history = hist)
}

#' Predict from trained BT model
#'
#' @param model Trained BT model
#' @param X Feature matrix
#' @param D Design matrix
#' @param batch_size Batch size (default: 2048)
#' @param device Device ("cpu" or "cuda")
#' @return List with prob, eta, and lambda predictions
#' @export
predict_bt_full = function(model, X, D, batch_size = 2048, device = "cpu") {
  model$to(device = device)
  
  dummy_Y = rep(0, nrow(X))
  loader  = make_loader(X, D, dummy_Y, batch_size = batch_size, shuffle = FALSE)
  
  model$eval()
  prob_list   = list()
  lambda_list = list()
  
  coro::loop(for (batch in loader) {
    x      = batch$x$to(device = device)
    design = batch$design$to(device = device)
    with_no_grad({
      lambda_hat = model(x)
      eta        = compute_eta_vec(lambda_hat, design)
      p          = eta$sigmoid()
    })
    prob_list[[length(prob_list) + 1L]]   = as.numeric(p$cpu())
    lambda_list[[length(lambda_list) + 1L]] = as_array(lambda_hat$cpu())
  })
  
  prob   = unlist(prob_list)
  lambda = do.call(rbind, lambda_list)
  eta    = qlogis(pmin(pmax(prob, 1e-6), 1 - 1e-6))
  
  list(prob = prob, eta = eta, lambda = lambda)
}

