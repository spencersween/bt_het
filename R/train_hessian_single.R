#' Train a single Hessian network (lower-triangular)
#'
#' @param X Feature matrix (n x p)
#' @param D Design matrix (n x k_minus_1)
#' @param train_idx Training indices
#' @param val_idx Validation indices
#' @param idx_lower Lower triangular indices
#' @param hidden Hidden layer sizes (vector)
#' @param dropout Dropout rates (scalar or vector)
#' @param use_batchnorm Whether to use batch normalization
#' @param lr Learning rate
#' @param weight_decay Weight decay
#' @param batch_size Batch size
#' @param max_epochs Maximum epochs
#' @param patience Early stopping patience
#' @param device Device ("cpu" or "cuda")
#' @param verbose Whether to print progress
#' @param live_plot Whether to show live plot window (default: FALSE)
#' @param plot_file Optional file path to save live plot PNG (default: NULL)
#' @return List with model and training history
#' @export
train_hessian_lower_single = function(X, D,
                                      train_idx, val_idx,
                                      idx_lower,
                                      hidden, dropout, use_batchnorm,
                                      lr, weight_decay,
                                      batch_size,
                                      max_epochs, patience,
                                      device,
                                      verbose = TRUE,
                                      live_plot = FALSE,
                                      plot_file = NULL) {
  
  p         = ncol(X)
  k_minus_1 = ncol(D)
  
  X_tr = X[train_idx, , drop = FALSE]
  X_va = X[val_idx,   , drop = FALSE]
  D_tr = D[train_idx, , drop = FALSE]
  D_va = D[val_idx,   , drop = FALSE]
  
  YH_tr = build_lower_targets(D_tr, idx_lower)
  YH_va = build_lower_targets(D_va, idx_lower)
  
  train_loader = make_hessian_loader(X_tr, YH_tr, batch_size = batch_size, shuffle = TRUE)
  val_loader   = make_hessian_loader(X_va, YH_va, batch_size = batch_size, shuffle = FALSE)
  
  model = hessian_net_lower(
    p             = p,
    k_minus_1     = k_minus_1,
    hidden        = hidden,
    dropout       = dropout,
    use_batchnorm = use_batchnorm
  )
  model$to(device = device)
  
  opt = optim_adamw(
    params       = model$parameters,
    lr           = lr,
    weight_decay = weight_decay
  )
  
  mse_loss         = nn_mse_loss()
  best_val         = Inf
  best_state       = NULL
  epochs_no_improv = 0
  hist = data.frame(epoch = integer(), train_loss = double(), val_loss = double())
  
  # Initialize live plotting if requested
  plot_env = NULL
  if (live_plot) {
    if (is.null(plot_file)) {
      plot_file = "plots/training_live_stage2.png"
    }
    plot_env = init_live_plot(
      title = "[Stage 2] Hessian Network Training",
      device = if (interactive()) "both" else "png",
      plot_file = plot_file
    )
  }
  
  for (epoch in 1:max_epochs) {
    model$train()
    run_loss = 0
    seen     = 0
    
    coro::loop(for (batch in train_loader) {
      x    = batch$x$to(device = device)
      ymat = batch$ymat$to(device = device)
      
      opt$zero_grad()
      pred = model(x)
      loss = mse_loss(pred, ymat)
      loss$backward()
      opt$step()
      
      bs       = as.integer(ymat$size()[1])
      run_loss = run_loss + as.numeric(loss$item()) * bs
      seen     = seen + bs
    })
    
    train_loss = run_loss / seen
    val_loss   = evaluate_hessian_loader(model, val_loader, device = device)
    
    hist = rbind(
      hist,
      data.frame(epoch = epoch, train_loss = train_loss, val_loss = val_loss)
    )
    
    # Update live plot if enabled
    if (live_plot && !is.null(plot_env)) {
      update_live_plot(plot_env, epoch, train_loss, val_loss, max_epochs)
    }
    
    if (val_loss + 1e-8 < best_val) {
      best_val         = val_loss
      best_state       = model$state_dict()
      epochs_no_improv = 0
    } else {
      epochs_no_improv = epochs_no_improv + 1
    }
    
    if (verbose) {
      cat(sprintf("  [Stage 2] epoch %03d  train=%.6f  val=%.6f\n", epoch, train_loss, val_loss))
    }
    if (epochs_no_improv >= patience) {
      if (verbose) cat(sprintf("  [Stage 2] early stopping at epoch %d (best val=%.6f)\n", epoch, best_val))
      break
    }
  }
  
  if (!is.null(best_state)) model$load_state_dict(best_state)
  
  # Close live plot if enabled
  if (live_plot && !is.null(plot_env)) {
    close_live_plot(plot_env)
  }
  
  list(model = model$to(device = "cpu"), history = hist)
}

