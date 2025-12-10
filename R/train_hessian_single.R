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
#' @param lr Initial learning rate
#' @param weight_decay Weight decay
#' @param batch_size Batch size
#' @param max_epochs Maximum epochs
#' @param patience Early stopping patience (in epochs)
#' @param device Device ("cpu" or "cuda")
#' @param verbose Whether to print progress
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
                                      verbose = TRUE) {
  
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
  
  # Plateau learning rate scheduler (ReduceLROnPlateau)
  # You can tune factor / lr_patience / min_lr as needed
  lr_factor   = 0.5          # multiply lr by this when plateau
  lr_patience = max(1L, floor(patience / 2))  # epochs with no improvement before lr reduction
  min_lr      = 1e-6
  
  scheduler = torch::lr_reduce_on_plateau(
    optimizer = opt,
    mode      = "min",
    factor    = lr_factor,
    patience  = lr_patience,
    threshold = 1e-4,
    cooldown  = 0,
    min_lr    = min_lr,
    eps       = 1e-8,
    verbose   = verbose
  )
  
  mse_loss         = nn_mse_loss()
  best_val         = Inf
  best_state       = NULL
  epochs_no_improv = 0
  hist = data.frame(epoch = integer(), train_loss = double(), val_loss = double())
  
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
    
    # Step the ReduceLROnPlateau scheduler on validation loss
    scheduler$step(val_loss)
    
    if (verbose) {
      current_lr = opt$param_groups[[1]]$lr
      cat(sprintf(
        "  [Stage 2] epoch %03d  train=%.6f  val=%.6f  lr=%.6g\n",
        epoch, train_loss, val_loss, current_lr
      ))
    }
    
    hist = rbind(
      hist,
      data.frame(epoch = epoch, train_loss = train_loss, val_loss = val_loss)
    )
    
    if (val_loss + 1e-8 < best_val) {
      best_val         = val_loss
      best_state       = model$state_dict()
      epochs_no_improv = 0
    } else {
      epochs_no_improv = epochs_no_improv + 1
    }
    
    if (epochs_no_improv >= patience) {
      if (verbose) {
        cat(sprintf("  [Stage 2] early stopping at epoch %d (best val=%.6f)\n",
                    epoch, best_val))
      }
      break
    }
  }
  
  if (!is.null(best_state)) model$load_state_dict(best_state)
  
  list(model = model$to(device = "cpu"), history = hist)
}
