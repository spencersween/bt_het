#' Fast AUC computation
#'
#' @param y True labels
#' @param p Predicted probabilities
#' @return AUC value
#' @export
auc_fast = function(y, p) {
  o = order(p)
  y = y[o]
  n_pos = sum(y == 1L)
  n_neg = sum(y == 0L)
  if (n_pos == 0L || n_neg == 0L) return(NA_real_)
  ranks = rank(p)
  (sum(ranks[y == 1L]) - n_pos * (n_pos + 1L) / 2) / (n_pos * n_neg)
}

#' Clip values to avoid numerical issues
#'
#' @param z Values to clip
#' @param min_val Minimum value (default: 1e-6)
#' @param max_val Maximum value (default: 1 - 1e-6)
#' @return Clipped values
#' @export
clip = function(z, min_val = 1e-6, max_val = 1 - 1e-6) {
  pmin(pmax(z, min_val), max_val)
}

#' Compute log loss
#'
#' @param y True labels
#' @param p Predicted probabilities
#' @return Log loss
#' @export
compute_logloss = function(y, p) {
  -mean(y * log(clip(p)) + (1 - y) * log(clip(1 - p)))
}

