#' Live plotting utilities for training progress
#'
#' Creates real-time plots that update during training

#' Initialize live plot window for training losses
#'
#' @param title Plot title
#' @param xlab X-axis label (default: "Epoch")
#' @param ylab Y-axis label (default: "Loss")
#' @param device Device to use ("window", "png", or "both")
#' @param plot_file File path for PNG output (if device includes "png")
#' @return Plot device info (invisible)
#' @export
init_live_plot = function(title = "Training Progress",
                         xlab = "Epoch",
                         ylab = "Loss",
                         device = "window",
                         plot_file = "plots/training_live.png") {
  
  # Ensure plots directory exists
  dir.create("plots", showWarnings = FALSE)
  
  # Initialize storage for plot data
  plot_env = new.env()
  plot_env$epochs = numeric()
  plot_env$train_loss = numeric()
  plot_env$val_loss = numeric()
  plot_env$title = title
  plot_env$xlab = xlab
  plot_env$ylab = ylab
  plot_env$device = device
  plot_env$plot_file = plot_file
  plot_env$plot_dev_num = NULL  # Always define this to avoid missing variable bugs
  
  # Open plotting device (will be created on first update for windows)
  if ((device == "window" || device == "both") && interactive()) {
    # Don't open device yet, let update_live_plot handle
    plot_env$plot_dev_num = NULL
  }
  
  if (device == "png" || device == "both") {
    png(plot_file, width = 800, height = 600, res = 100)
    # Create empty plot
    plot(1, type = "n", 
         xlim = c(1, 100), 
         ylim = c(0, 1),
         xlab = xlab,
         ylab = ylab,
         main = title)
    legend("topright", 
           legend = c("Train Loss", "Val Loss"),
           col = c("blue", "red"),
           lty = 1,
           lwd = 2)
    dev.off()
  }
  
  # If only window device, initialize empty plot if interactive
  if ((device == "window") && interactive()) {
    # Not opening, waiting for update_live_plot to handle device
    # But just for safety, don't plot until there's real data
  }

  return(plot_env)
}

#' Update live plot with new loss values
#'
#' @param plot_env Plot environment from init_live_plot()
#' @param epoch Current epoch
#' @param train_loss Training loss
#' @param val_loss Validation loss
#' @param max_epochs Maximum epochs (for x-axis limits)
#' @export
update_live_plot = function(plot_env, epoch, train_loss, val_loss, max_epochs = NULL) {
  
  # Store data
  plot_env$epochs = c(plot_env$epochs, epoch)
  plot_env$train_loss = c(plot_env$train_loss, train_loss)
  plot_env$val_loss = c(plot_env$val_loss, val_loss)
  
  # Determine x-axis limits
  if (is.null(max_epochs)) {
    xlim = c(1, max(100, max(plot_env$epochs) * 1.1))
  } else {
    xlim = c(1, max_epochs)
  }
  
  # Determine y-axis limits (handle all NA/loss = 0 cases)
  all_losses = c(plot_env$train_loss, plot_env$val_loss)
  ymax = ifelse(length(all_losses[is.finite(all_losses)]) == 0, 1, max(all_losses[is.finite(all_losses)]) * 1.1)
  ylim = c(0, ymax)
  
  device = plot_env$device
  plot_file = plot_env$plot_file
  
  # Update plot: window
  if ((device == "window" || device == "both") && interactive()) {
    # Open plot window if necessary
    if (is.null(plot_env$plot_dev_num) || !plot_env$plot_dev_num %in% dev.list()) {
      plot_env$plot_dev_num = dev.new(width = 8, height = 6, title = plot_env$title)
    } else {
      dev.set(plot_env$plot_dev_num)
    }
    plot(plot_env$epochs, plot_env$train_loss,
         type = "l",
         col = "blue",
         lwd = 2,
         xlim = xlim,
         ylim = ylim,
         xlab = plot_env$xlab,
         ylab = plot_env$ylab,
         main = plot_env$title)
    lines(plot_env$epochs, plot_env$val_loss,
          col = "red",
          lwd = 2)
    legend("topright",
           legend = c("Train Loss", "Val Loss"),
           col = c("blue", "red"),
           lty = 1,
           lwd = 2)
    # Force redraw
    grid()
  }
  
  # Update PNG file
  if (device == "png" || device == "both") {
    png(plot_file, width = 800, height = 600, res = 100)
    plot(plot_env$epochs, plot_env$train_loss,
         type = "l",
         col = "blue",
         lwd = 2,
         xlim = xlim,
         ylim = ylim,
         xlab = plot_env$xlab,
         ylab = plot_env$ylab,
         main = plot_env$title)
    lines(plot_env$epochs, plot_env$val_loss,
          col = "red",
          lwd = 2)
    legend("topright",
           legend = c("Train Loss", "Val Loss"),
           col = c("blue", "red"),
           lty = 1,
           lwd = 2)
    grid()
    dev.off()
  }
  
  invisible(plot_env)
}

#' Close live plot device
#'
#' @param plot_env Plot environment from init_live_plot()
#' @export
close_live_plot = function(plot_env) {
  if (interactive() && !is.null(plot_env$plot_dev_num) && plot_env$plot_dev_num %in% dev.list()) {
    dev.set(plot_env$plot_dev_num)
    dev.off()
    plot_env$plot_dev_num <- NULL
  }
  invisible(plot_env)
}

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
