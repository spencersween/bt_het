#' Fit classical Bradley-Terry model using logistic regression
#'
#' @param bt_df Dataframe with model_a, model_b, winner columns
#' @param base_model Name of base model (default: "gpt-4")
#' @return List containing coefficients, design matrix, and fitted model
#' @export
fit_classical_bt = function(bt_df, base_model = "gpt-4") {
  
  n = nrow(bt_df)
  
  # Outcome vector: 1 if model_a wins, 0 if model_b wins
  Y_bt = ifelse(bt_df$winner == "model_a", 1L, 0L)
  
  # All models that appear
  models = sort(unique(c(bt_df$model_a, bt_df$model_b)))
  K = length(models)
  
  # Map each model name to an index
  bt_df = bt_df %>%
    dplyr::mutate(
      idx_a = match(model_a, models),
      idx_b = match(model_b, models)
    )
  
  # Design matrix D_full: +1 for model_a, -1 for model_b, 0 otherwise
  D_full = matrix(0, nrow = n, ncol = K)
  colnames(D_full) = models
  rows = seq_len(n)
  D_full[cbind(rows, bt_df$idx_a)] = 1
  D_full[cbind(rows, bt_df$idx_b)] = -1
  
  # Set base model
  if (!base_model %in% models) {
    stop(paste0("Base model '", base_model, "' not found in models."))
  }
  base_col = which(models == base_model)
  
  # Drop base model column to identify model
  D_bt = D_full[, -base_col, drop = FALSE]
  
  # Fit logistic regression
  bt_fit = glm(
    Y_bt ~ D_bt - 1,
    family = binomial(link = "logit")
  )
  
  coef_hat = bt_fit$coefficients
  names(coef_hat) = colnames(D_bt)
  
  lambda = numeric(K)
  names(lambda) = models
  lambda[names(coef_hat)] = coef_hat
  lambda[base_model] = 0
  
  return(list(
    lambda = lambda,
    lambda_sorted = sort(lambda, decreasing = TRUE),
    coef_hat = coef_hat,
    models = models,
    D_full = D_full,
    D_bt = D_bt,
    fit = bt_fit
  ))
}

#' Compute Bradley-Terry probability that model_i beats model_j
#'
#' @param model_i First model name
#' @param model_j Second model name
#' @param lambda_vec Named vector of lambda coefficients
#' @return Probability that model_i beats model_j
#' @export
bt_prob = function(model_i, model_j, lambda_vec) {
  if (!all(c(model_i, model_j) %in% names(lambda_vec))) {
    stop("Both models must be present in the estimated lambda vector.")
  }
  eta = lambda_vec[model_i] - lambda_vec[model_j]
  1 / (1 + exp(-eta))
}

