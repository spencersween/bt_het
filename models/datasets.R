#' Bradley-Terry dataset class for torch
#'
#' @export
bt_dataset = dataset(
  name = "bt_dataset",
  initialize = function(x, design, y) {
    self$x      = x
    self$design = design
    self$y      = y
  },
  .getitem = function(i) {
    list(
      x      = torch_tensor(self$x[i, ], dtype = torch_float()),
      design = torch_tensor(self$design[i, ], dtype = torch_float()),
      y      = torch_tensor(as.numeric(self$y[i]), dtype = torch_float())
    )
  },
  .length = function() nrow(self$x)
)

#' Create dataloader for Bradley-Terry data
#'
#' @param x Feature matrix
#' @param design Design matrix
#' @param y Outcome vector
#' @param batch_size Batch size (default: 1024)
#' @param shuffle Whether to shuffle (default: TRUE)
#' @return Dataloader object
#' @export
make_loader = function(x, design, y, batch_size = 1024, shuffle = TRUE) {
  ds = bt_dataset(x = x, design = design, y = y)
  dataloader(ds, batch_size = batch_size, shuffle = shuffle, drop_last = FALSE)
}

#' Hessian dataset class for torch
#'
#' @export
hessian_dataset = dataset(
  name = "hessian_dataset",
  initialize = function(x, ymat) {
    self$x    = x
    self$ymat = ymat
  },
  .getitem = function(i) {
    list(
      x    = torch_tensor(self$x[i, ],    dtype = torch_float()),
      ymat = torch_tensor(self$ymat[i, ], dtype = torch_float())
    )
  },
  .length = function() nrow(self$x)
)

#' Create dataloader for Hessian data
#'
#' @param x Feature matrix
#' @param ymat Target matrix
#' @param batch_size Batch size (default: 1024)
#' @param shuffle Whether to shuffle (default: TRUE)
#' @return Dataloader object
#' @export
make_hessian_loader = function(x, ymat, batch_size = 1024, shuffle = TRUE) {
  ds = hessian_dataset(x = x, ymat = ymat)
  dataloader(ds, batch_size = batch_size, shuffle = shuffle, drop_last = FALSE)
}

