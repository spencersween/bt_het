# Package initialization and source helper

#' Source all functions from a directory
#'
#' Helper function to load all R files from a directory
#'
#' @param path Directory path to source from
#' @param recursive Whether to search recursively (default: TRUE)
#' @return NULL (sources files as side effect)
#' @export
source_dir = function(path, recursive = TRUE) {
  if (!dir.exists(path)) {
    warning(paste("Directory does not exist:", path))
    return(invisible(NULL))
  }
  
  pattern = "\\.R$"
  files = list.files(path, pattern = pattern, full.names = TRUE, recursive = recursive)
  
  for (file in files) {
    tryCatch({
      source(file, local = FALSE)
    }, error = function(e) {
      warning(paste("Error sourcing", file, ":", e$message))
    })
  }
  
  invisible(NULL)
}

#' Load all package functions
#'
#' Convenience function to source all directories
#'
#' @return NULL (sources files as side effect)
#' @export
load_all = function() {
  # Load required packages first
  if (!requireNamespace("torch", quietly = TRUE)) {
    stop("torch package is required but not installed")
  }
  library(torch)
  
  # Source in dependency order
  source_dir("data", recursive = FALSE)
  source_dir("utils", recursive = FALSE)
  source_dir("models", recursive = FALSE)
  source_dir("R", recursive = FALSE)
  invisible(NULL)
}

