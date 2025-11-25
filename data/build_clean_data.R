#' Build cleaned dataset from raw parquet data
#'
#' @param df Raw dataframe from parquet file
#' @return Cleaned dataframe with extracted features
#' @export
build_clean_data = function(df) {
  
  # Vectorized extraction of conversation A and B
  conversation_a = purrr::map_df(df$conversation_a, extract_conversation) %>%
    dplyr::rename(
      question_a     = question,
      response_a     = response,
      conversation_a = conversation
    )
  
  conversation_b = purrr::map_df(df$conversation_b, extract_conversation) %>%
    dplyr::rename(
      question_b     = question,
      response_b     = response,
      conversation_b = conversation
    )
  
  # Core cleaned dataset
  df_clean = df %>%
    dplyr::select(
      question_id, model_a, model_b, winner, judge, turn,
      anony, language, tstamp
    ) %>%
    dplyr::bind_cols(
      df$openai_moderation$categories,
      df$openai_moderation$category_scores,
      df$openai_moderation$flagged,
      df$toxic_chat_tag$`roberta-large`,
      df$toxic_chat_tag$`t5-large`
    )
  
  colnames(df_clean) = c(
    "question_id", "model_a", "model_b", "winner", "judge", "turn",
    "anony", "language", "tstamp",
    "cat_harassment", "cat_harassthreat", "cat_hate",
    "cat_hatethreat", "cat_selfharm", "cat_selfharminstruct",
    "cat_selfharmintent", "cat_sexual", "cat_sexualminors",
    "cat_violence", "cat_violencegraphic",
    "score_harassment", "score_harassthreat", "score_hate",
    "score_hatethreat", "score_selfharm", "score_selfharminstruct",
    "score_selfharmintent", "score_sexual", "score_sexualminors",
    "score_violence", "score_violencegraphic",
    "openai_flagged",
    "roberta_toxic", "roberta_score",
    "t5large_toxic", "t5large_score"
  )
  
  # Add conversations, convert logicals to 0/1, extract time components, rank per judge
  df_clean = dplyr::bind_cols(df_clean, conversation_a, conversation_b) %>%
    dplyr::mutate(
      dplyr::across(dplyr::where(is.logical), ~ as.integer(.x)),
      
      tstamp = ifelse(
        tstamp > 1e12,
        tstamp / 1000,
        tstamp
      ),
      tstamp = as.POSIXct(tstamp, origin = "1970-01-01", tz = "UTC"),
      
      year  = lubridate::year(tstamp),
      month = lubridate::month(tstamp),
      day   = lubridate::day(tstamp),
      time  = format(tstamp, "%H:%M:%S")
    ) %>%
    dplyr::arrange(judge, tstamp) %>%
    dplyr::group_by(judge) %>%
    dplyr::mutate(judge_convo_number = dplyr::row_number()) %>%
    dplyr::ungroup() %>% 
    dplyr::group_by(question_b) %>% 
    dplyr::mutate(nquestion = dplyr::n()) %>% 
    dplyr::ungroup()
  
  return(df_clean)
}

