#' Prepare feature matrices X, Y, D from processed data
#'
#' @param bt_df Bradley-Terry dataframe
#' @param final_df1 First processed dataframe
#' @param final_df2 Second processed dataframe
#' @return List containing X, Y, D, P, J matrices
#' @export
prepare_features = function(bt_df, final_df1, final_df2) {
  
  nobs = nrow(bt_df)
  
  Y = as.matrix(final_df1$Y, nrow = nobs, ncol = 1)
  
  D = final_df1 %>%
    dplyr::select(dplyr::starts_with("D")) %>%
    as.matrix()
  
  # No scaling: raw X and P
  X1 = final_df1 %>%
    dplyr::select(P) %>%
    as.matrix()
  X2 = final_df2 %>% 
    dplyr::select(dplyr::starts_with("X_")) %>% 
    as.matrix()
  X3 = bt_df %>% 
    dplyr::mutate(is_english = as.numeric(language == "English")) %>% 
    dplyr::select(dplyr::starts_with("score"), roberta_score, t5large_score, is_english) %>% 
    as.matrix()
  X = cbind(X1, X2, X3)
  
  P = final_df1$P
  
  J = bt_df %>%
    dplyr::select(judge) %>% 
    as.matrix() %>% 
    as.vector()
  
  if (is.matrix(Y)) {
    stopifnot(ncol(Y) == 1)
    Y = as.numeric(Y[, 1])
  } else {
    Y = as.numeric(Y)
  }
  
  n = length(Y)
  stopifnot(is.matrix(D), nrow(D) == n, is.matrix(X), nrow(X) == n)
  
  p         = ncol(X)
  k_minus_1 = ncol(D)
  if (is.null(colnames(D))) colnames(D) = paste0("model_", seq_len(k_minus_1))
  
  return(list(
    X = X,
    Y = Y,
    D = D,
    P = P,
    J = J,
    p = p,
    k_minus_1 = k_minus_1,
    n = n,
    model_names_km1 = colnames(D)
  ))
}

#' Create cross-validation folds
#'
#' @param bt_df Bradley-Terry dataframe
#' @param nfolds Number of folds (default: 2)
#' @param seed Random seed (default: 123)
#' @return Fold assignment vector S
#' @export
create_folds = function(bt_df, nfolds = 2, seed = 123) {
  set.seed(seed)
  fold_df = bt_df %>%
    dplyr::group_by(judge) %>%
    dplyr::mutate(S = sample.int(nfolds, 1L)) %>%
    dplyr::ungroup()
  as.integer(fold_df$S)
}

