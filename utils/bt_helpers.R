#' Compute eta vector from lambda and design matrix
#'
#' @param lambda_hat Predicted lambda values (batch x k_minus_1)
#' @param design_batch Design matrix batch (batch x k_minus_1)
#' @return Eta vector (batch length)
#' @export
compute_eta_vec = function(lambda_hat, design_batch) {
  (lambda_hat * design_batch)$sum(dim = 2)$view(c(-1))
}

#' Binary cross-entropy with logits
#'
#' @param logits_vec Logits vector
#' @param y_vec Target vector
#' @return Loss tensor
#' @export
bce_logits_vec = function(logits_vec, y_vec) {
  if (length(logits_vec$size()) != 1) logits_vec = logits_vec$view(c(-1))
  if (length(y_vec$size())     != 1) y_vec       = y_vec$view(c(-1))
  nnf_binary_cross_entropy_with_logits(logits_vec, y_vec)
}

#' Evaluate loader performance
#'
#' @param model Trained model
#' @param loader Dataloader
#' @param device Device ("cpu" or "cuda")
#' @return Average loss
#' @export
evaluate_loader = function(model, loader, device = "cpu") {
  model$eval()
  total_loss = 0
  n_obs      = 0
  coro::loop(for (batch in loader) {
    x      = batch$x$to(device = device)
    design = batch$design$to(device = device)
    y      = batch$y$to(device = device)
    
    with_no_grad({
      if (length(y$size()) != 1) y = y$view(c(-1))
      lambda_hat = model(x)
      eta        = compute_eta_vec(lambda_hat, design)
      loss       = bce_logits_vec(eta, y)
    })
    
    bs = as.integer(y$size()[1])
    total_loss = total_loss + as.numeric(loss$item()) * bs
    n_obs      = n_obs + bs
  })
  total_loss / n_obs
}

#' Predict probabilities from loader
#'
#' @param model Trained model
#' @param loader Dataloader
#' @param device Device ("cpu" or "cuda")
#' @return Vector of predicted probabilities
#' @export
predict_loader_prob = function(model, loader, device = "cpu") {
  model$eval()
  preds = list()
  coro::loop(for (batch in loader) {
    x      = batch$x$to(device = device)
    design = batch$design$to(device = device)
    with_no_grad({
      lambda_hat = model(x)
      eta        = compute_eta_vec(lambda_hat, design)
      p          = eta$sigmoid()
    })
    preds[[length(preds) + 1]] = as.numeric(p$cpu())
  })
  unlist(preds)
}

#' Predict lambda values from loader
#'
#' @param model Trained model
#' @param loader Dataloader
#' @param device Device ("cpu" or "cuda")
#' @return Matrix of predicted lambda values (n x k_minus_1)
#' @export
predict_loader_lambda = function(model, loader, device = "cpu") {
  model$eval()
  out = list()
  coro::loop(for (batch in loader) {
    x = batch$x$to(device = device)
    with_no_grad({
      lambda_hat = model(x)
    })
    out[[length(out) + 1]] = as_array(lambda_hat$cpu())
  })
  do.call(rbind, out)
}

