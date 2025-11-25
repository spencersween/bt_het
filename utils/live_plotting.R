#' Simple progress bar with loss display
#'
#' @param epoch Current epoch
#' @param max_epochs Total epochs
#' @param train_loss Training loss
#' @param val_loss Validation loss
#' @param width Progress bar width (default: 50)
#' @export
print_progress_bar = function(epoch, max_epochs, train_loss, val_loss, width = 50) {
  progress = round(width * epoch / max_epochs)
  bar = paste(rep("=", progress), collapse = "")
  spaces = paste(rep(" ", width - progress), collapse = "")
  
  cat(sprintf("\rEpoch %3d/%d [%s%s] Train: %.6f  Val: %.6f",
              epoch, max_epochs, bar, spaces, train_loss, val_loss))
  flush.console()
}
