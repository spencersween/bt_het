#' Extract question, response, and combined conversation from conversation data
#'
#' @param conv A conversation object with content field
#' @return A tibble with question, response, and conversation columns
#' @export
extract_conversation = function(conv) {
  dplyr::tibble(
    question = conv$content[1],
    response = conv$content[2],
    conversation = paste(
      "{User}: ", conv$content[1],
      " {Assistant}: ", conv$content[2],
      sep = ""
    )
  )
}

