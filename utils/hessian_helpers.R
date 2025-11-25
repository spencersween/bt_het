#' Get lower triangular indices
#'
#' @param k Dimension of matrix
#' @return Matrix with row and col indices for lower triangular entries
#' @export
lower_tri_indices = function(k) {
  which(lower.tri(matrix(1, k, k), diag = TRUE), arr.ind = TRUE)
}

#' Build lower triangular targets from design matrix
#'
#' @param D_sub Design matrix subset
#' @param idx_lower Lower triangular indices
#' @return Matrix of lower triangular targets (n x num_lower)
#' @export
build_lower_targets = function(D_sub, idx_lower) {
  n_sub = nrow(D_sub)
  k     = ncol(D_sub)
  num_lower = nrow(idx_lower)
  out   = matrix(NA_real_, n_sub, num_lower)
  for (i in seq_len(n_sub)) {
    M = tcrossprod(D_sub[i, ], D_sub[i, ])  # k x k, in {-1,0,1}
    out[i, ] = M[cbind(idx_lower[, "row"], idx_lower[, "col"])]
  }
  out
}

#' Convert lower triangular vector to full symmetric matrix
#'
#' @param lower_vec Lower triangular entries
#' @param idx_lower Lower triangular indices
#' @param k Dimension of full matrix
#' @return Full symmetric matrix (k x k)
#' @export
lower_to_full = function(lower_vec, idx_lower, k) {
  M = matrix(0, nrow = k, ncol = k)
  M[cbind(idx_lower[, "row"], idx_lower[, "col"])] = lower_vec
  for (ell in seq_len(nrow(idx_lower))) {
    i = idx_lower[ell, "row"]
    j = idx_lower[ell, "col"]
    M[j, i] = M[i, j]
  }
  M
}

#' Evaluate Hessian loader performance
#'
#' @param model Trained Hessian model
#' @param loader Dataloader
#' @param device Device ("cpu" or "cuda")
#' @return Average MSE loss
#' @export
evaluate_hessian_loader = function(model, loader, device = "cpu") {
  model$eval()
  total_loss = 0
  n_obs      = 0
  mse_loss   = nn_mse_loss()
  coro::loop(for (batch in loader) {
    x    = batch$x$to(device = device)
    ymat = batch$ymat$to(device = device)
    with_no_grad({
      pred = model(x)
      loss = mse_loss(pred, ymat)
    })
    bs = as.integer(ymat$size()[1])
    total_loss = total_loss + as.numeric(loss$item()) * bs
    n_obs      = n_obs + bs
  })
  total_loss / n_obs
}

#' Predict Hessian lower triangular entries
#'
#' @param model Trained Hessian model
#' @param X_sub Feature matrix subset
#' @param batch_size Batch size (default: 2048)
#' @param device Device ("cpu" or "cuda")
#' @return Matrix of predicted lower triangular entries (n x num_lower)
#' @export
predict_hessian_lower = function(model, X_sub, batch_size = 2048, device = "cpu") {
  model$to(device = device)
  model$eval()
  
  ds = dataset(
    name = "X_dataset_for_H",
    initialize = function(x) self$x <- x,
    .getitem = function(i) list(x = torch_tensor(self$x[i, ], dtype = torch_float())),
    .length = function() nrow(self$x)
  )
  loader = dataloader(ds(X_sub), batch_size = batch_size, shuffle = FALSE, drop_last = FALSE)
  
  preds = list()
  coro::loop(for (batch in loader) {
    x = batch$x$to(device = device)
    with_no_grad({
      out = model(x)
    })
    preds[[length(preds) + 1L]] = as_array(out$cpu())
  })
  
  do.call(rbind, preds)
}

