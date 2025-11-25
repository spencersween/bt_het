#' Prepare Bradley-Terry dataset from cleaned data
#'
#' @param df_clean Cleaned dataframe
#' @param final_df1 First processed dataframe
#' @param final_df2 Second processed dataframe
#' @return List containing bt_df, final_df1, final_df2 with matching rows
#' @export
prepare_bt_data = function(df_clean, final_df1, final_df2) {
  
  bt_df = df_clean %>%
    dplyr::filter(winner %in% c("model_a", "model_b")) %>%
    dplyr::filter(turn == 1) %>%
    dplyr::filter(t5large_toxic == 0 & roberta_toxic == 0) %>%
    dplyr::select(model_a, model_b, winner, nquestion, judge, language, 
                  dplyr::starts_with("score_"), roberta_score, t5large_score)
  
  which_rows = which(bt_df$nquestion == 1)
  bt_df = bt_df[which_rows, ]
  final_df1 = final_df1[which_rows, ]
  final_df2 = final_df2[which_rows, ]
  
  return(list(
    bt_df = bt_df,
    final_df1 = final_df1,
    final_df2 = final_df2
  ))
}

