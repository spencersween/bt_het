################################################################################
## Structural Deep Learning for Bradley-Terry Models - ComparIA + Ecologits
################################################################################
##
## Data (bt_comparia.csv):
##   Y_lab    : binary outcome (1 if Creator_A wins, 0 otherwise)
##   Y_model  : binary outcome (1 if Creator_A wins, 0 otherwise)
##   LD_*     : treatments in {-1, 0, +1} (design for lab preferences)
##   MD_*     : treatments in {-1, 0, +1} (design for all model preferences)
##   ED_*     : treatments in {-1, 0, +1} (design for ecologits preferences)
##   X_*      : question-specific covariates (log-token length, embeddings)
##   did_vote : indicator of vote response
##   tied     : indicator of tied vote response
##   has_model_ecologits: indicator of ecologits data available
##
## Pipeline:
##   1. Neural net Theta_net: X -> theta(X) in R^K  (coefficient functions)
##   2. Bradley-Terry loss: eta_i = D_i · theta(X_i), p_i = sigmoid(eta_i)
##   3. At fitted theta_hat(X_i), construct per observation:
##        - gradient g_i = d ell_i / d theta(X_i)  (K-vector)
##        - Hessian  H_i = d^2 ell_i / d theta(X_i) d theta(X_i)'  (K x K)
##   4. Train Hessian net H_net: X -> H(X) (eigenvalues in (0, 0.25])
##   5. Influence style object per row i, parameter j:
##        IF_i,j = theta_hat_j(X_i) + e_j' H_hat(X_i)^{-1} g_i
##
## Cross fitting:
##   For each split s = 1, ..., Nsplits:
##     - Train Theta_net and Hessian_net on {Splits != s}
##     - Within that training set, use a 10 percent holdout for early stopping
##     - Use the trained nets to predict theta, g, and H_hat on {Splits == s}
##   Stacking across splits yields cross fitted nuisances for all observations.
##
################################################################################

rm(list = ls())
gc()

setwd("/Users/spencersween/Dropbox/bt_het")

library(torch)
library(coro)
library(tidyverse)
library(data.table)
library(dplyr)
library(ggplot2)
library(binsreg)
library(ggtext)

################################################################################
## 0. Setup
################################################################################

set.seed(42)
torch_manual_seed(42)

device <- if (cuda_is_available()) torch_device("cuda") else torch_device("cpu")

################################################################################
## 1. Load data and build design / covariate matrices
################################################################################

csv_path <- "/Users/spencersween/Downloads/bt_comparia.csv"

dat <- data.table::fread(csv_path) %>%
  as_tibble()

drop_nres <- TRUE   # Drop no-vote battles
drop_ties <- TRUE   # Drop tied battles

use_labs <- FALSE   # Model labs, not models
use_ecol <- TRUE    # Model ecologits models

base_lab <- "LDopenai"  # Use OpenAI as base lab
base_mod <- "MDgpt_5"   # Use GPT-5 as base model
base_eco <- "EDgpt_5"   # Use GPT-5 as base ecologits model

# Filter
dat_clean <- dat
if (drop_nres) dat_clean <- dat_clean %>% dplyr::filter(did_vote == 1)
if (drop_ties) dat_clean <- dat_clean %>% dplyr::filter(tied == 0)

if (use_labs & !use_ecol) {
  
  dat_clean <- dat_clean %>% 
    dplyr::select(-all_of(base_lab))
  
  nobs <- nrow(dat_clean)
  
  Y <- as.matrix(dat_clean$Y_lab, ncol = 1)
  
  d_cols <- grep("^LD", names(dat_clean), value = TRUE)
  D <- as.matrix(dat_clean[, d_cols, drop = FALSE])
  
  x_cols <- grep("^X_", names(dat_clean), value = TRUE)
  X <- as.matrix(dat_clean[, x_cols, drop = FALSE])
  
  J <- as.matrix(dat_clean$judge_id, ncol = 1)
  
  E <- matrix(0, nrow = nobs, ncol = 2)
  G <- matrix(0, nrow = nobs, ncol = 2)
  H <- matrix(0, nrow = nobs, ncol = 2)
}

if (use_labs & use_ecol) {
  
  dat_clean <- dat_clean %>% 
    dplyr::filter(has_model_ecologits == 1) %>% 
    dplyr::select(-all_of(base_lab))
  
  nobs <- nrow(dat_clean)
  
  Y <- as.matrix(dat_clean$Y_lab, ncol = 1)
  
  d_cols <- c("LDanthropic", "LDcohere", "LDmistral", "LDgoogle")
  D <- as.matrix(dat_clean[, d_cols, drop = FALSE])
  
  x_cols <- grep("^X_", names(dat_clean), value = TRUE)
  X <- as.matrix(dat_clean[, x_cols, drop = FALSE])
  
  J <- as.matrix(dat_clean$judge_id, ncol = 1)
  
  E <- cbind(dat_clean$log_energy_a, dat_clean$log_energy_b)
  G <- cbind(dat_clean$log_co2_a, dat_clean$log_co2_b)
  H <- cbind(dat_clean$log_h2o_a, dat_clean$log_h2o_b)
}

if (!use_labs & !use_ecol) {
  
  dat_clean <- dat_clean %>% 
    dplyr::select(-all_of(base_mod))
  
  nobs <- nrow(dat_clean)
  
  Y <- as.matrix(dat_clean$Y_model, ncol = 1)
  
  d_cols <- grep("^MD", names(dat_clean), value = TRUE)
  D <- as.matrix(dat_clean[, d_cols, drop = FALSE])
  
  x_cols <- grep("^X_", names(dat_clean), value = TRUE)
  X <- as.matrix(dat_clean[, x_cols, drop = FALSE])
  
  J <- as.matrix(dat_clean$judge_id, ncol = 1)
  
  E <- matrix(0, nrow = nobs, ncol = 2)
  G <- matrix(0, nrow = nobs, ncol = 2)
  H <- matrix(0, nrow = nobs, ncol = 2)
}

if (!use_labs & use_ecol) {
  
  dat_clean <- dat_clean %>% 
    dplyr::filter(has_model_ecologits == 1) %>% 
    dplyr::select(-all_of(base_eco))
  
  nobs <- nrow(dat_clean)
  
  Y <- as.matrix(dat_clean$Y_model, ncol = 1)
  
  d_cols <- grep("^ED", names(dat_clean), value = TRUE)
  D <- as.matrix(dat_clean[, d_cols, drop = FALSE])
  
  x_cols <- grep("^X_", names(dat_clean), value = TRUE)
  X <- as.matrix(dat_clean[, x_cols, drop = FALSE])
  
  J <- as.matrix(dat_clean$judge_id, ncol = 1)
  
  E <- cbind(dat_clean$log_energy_a, dat_clean$log_energy_b)
  G <- cbind(dat_clean$log_co2_a, dat_clean$log_co2_b)
  H <- cbind(dat_clean$log_h2o_a, dat_clean$log_h2o_b)
}

# Dimensions
nobs <- nrow(D)   # number of battles
dimD <- ncol(D)   # number of labs or models
dimX <- ncol(X)   # number of covariates

# Cross fitting splits at judge level
Nsplits <- 2

Splits <- tibble(J = J[, 1]) %>% 
  group_by(J) %>% 
  mutate(Splits = sample(1:Nsplits, size = 1)) %>% 
  ungroup() %>% 
  select(Splits) %>% 
  as.matrix() %>% 
  as.numeric()

Halves = matrix(rbinom(nobs*Nsplits, size = 1, prob = 0.5), nrow = nobs, ncol = Nsplits)

################################################################################
## 2. Convert to torch tensors
################################################################################

X_torch <- torch_tensor(X, dtype = torch_float(), device = device)$view(c(nobs, dimX))
D_torch <- torch_tensor(D, dtype = torch_float(), device = device)$view(c(nobs, dimD))
Y_torch <- torch_tensor(Y, dtype = torch_float(), device = device)$view(c(nobs, 1L))
J_torch <- torch_tensor(J, dtype = torch_float(), device = device)$view(c(nobs, 1L))
E_torch <- torch_tensor(E, dtype = torch_float(), device = device)$view(c(nobs, 2L))
G_torch <- torch_tensor(G, dtype = torch_float(), device = device)$view(c(nobs, 2L))
H_torch <- torch_tensor(H, dtype = torch_float(), device = device)$view(c(nobs, 2L))

# Convenient 1d outcome vector
Y_vec <- Y_torch$view(c(nobs))

################################################################################
## 3. Hyperparameters and generic MLP backbone
################################################################################

# Cross fitting and early stopping
patience_theta    <- 10L
patience_hessian  <- 10L
min_delta_theta   <- 1e-5
min_delta_hessian <- 1e-5

# Theta net hyperparameters
theta_hidden_dims <- c(32, 32)   # flexible depth and width
theta_activation  <- "leaky"     # "relu", "tanh", "elu", "leaky", "identity"
theta_dropout     <- 0.00
theta_batch_norm  <- FALSE
theta_lr          <- 1e-3
theta_num_epochs  <- 1000L
theta_batch_size  <- 1024L
theta_clamp_val   <- log((1 - 1e-5) / (1e-5))

# Hessian net hyperparameters
hessian_hidden_dims <- c(32, 32)
hessian_activation  <- "leaky"
hessian_dropout     <- 0.00
hessian_batch_norm  <- FALSE
hessian_lr          <- 1e-3
hessian_num_epochs  <- 100L
hessian_batch_size  <- 1024L
hessian_max_eig     <- 0.25

# Generic MLP backbone to allow modular architectures
GenericMLP <- nn_module(
  "GenericMLP",
  
  initialize = function(input_dim,
                        hidden_dims = c(64, 64),
                        activation  = "relu",
                        dropout     = 0.0,
                        batch_norm  = FALSE) {
    
    self$hidden_dims <- hidden_dims
    self$activation  <- activation
    self$dropout     <- dropout
    self$batch_norm  <- batch_norm
    
    self$layers <- nn_module_list()
    if (batch_norm) {
      self$bn_layers <- nn_module_list()
    }
    
    prev_dim <- input_dim
    for (h in hidden_dims) {
      self$layers$append(nn_linear(prev_dim, h))
      if (batch_norm) {
        self$bn_layers$append(nn_batch_norm1d(h))
      }
      prev_dim <- h
    }
    
    self$output_dim <- prev_dim
  },
  
  forward = function(x) {
    h <- x
    for (i in seq_along(self$hidden_dims)) {
      h <- self$layers[[i]](h)
      
      if (self$batch_norm) {
        h <- self$bn_layers[[i]](h)
      }
      
      if (self$activation == "relu") {
        h <- nnf_relu(h)
      } else if (self$activation == "leaky") {
        h <- nnf_leaky_relu(h)
      } else if (self$activation == "elu") {
        h <- nnf_elu(h)
      } else if (self$activation == "tanh") {
        h <- torch_tanh(h)
      } else {
        # identity
      }
      
      if (self$dropout > 0) {
        h <- nnf_dropout(h, p = self$dropout, training = self$training)
      }
    }
    h
  }
)

################################################################################
## 4. ThetaNet: neural net for coefficient functions theta(X)
################################################################################

ThetaNet <- nn_module(
  "ThetaNet",
  
  initialize = function(input_dim,
                        n_items,
                        hidden_dims = c(64, 64),
                        activation  = "relu",
                        dropout     = 0.0,
                        batch_norm  = FALSE,
                        clamp_val   = NULL) {
    
    self$n_items   <- n_items
    self$clamp_val <- clamp_val
    
    self$backbone <- GenericMLP(
      input_dim   = input_dim,
      hidden_dims = hidden_dims,
      activation  = activation,
      dropout     = dropout,
      batch_norm  = batch_norm
    )
    
    self$out <- nn_linear(self$backbone$output_dim, n_items)
  },
  
  forward = function(x) {
    h <- self$backbone(x)
    theta_raw <- self$out(h)
    
    if (!is.null(self$clamp_val)) {
      clamp <- self$clamp_val
      theta <- clamp * torch_tanh(theta_raw / clamp)
    } else {
      theta <- theta_raw
    }
    theta
  }
)

################################################################################
## 5. HessianLearner: conditional Hessian net H_net(X)
################################################################################

HessianLearner <- nn_module(
  "HessianLearner",
  
  initialize = function(input_dim,
                        n_items,
                        hidden_dims = c(64, 64),
                        activation  = "relu",
                        dropout     = 0.0,
                        batch_norm  = FALSE,
                        max_eig     = 0.25) {
    
    self$n_items <- n_items
    self$max_eig <- max_eig
    
    self$backbone <- GenericMLP(
      input_dim   = input_dim,
      hidden_dims = hidden_dims,
      activation  = activation,
      dropout     = dropout,
      batch_norm  = batch_norm
    )
    
    self$num_tril <- as.integer(n_items * (n_items + 1) / 2)
    self$out      <- nn_linear(self$backbone$output_dim, self$num_tril)
    
    tril_idx      <- torch_tril_indices(n_items, n_items, offset = 0)
    self$tril_row <- tril_idx[1, ]
    self$tril_col <- tril_idx[2, ]
  },
  
  forward = function(x) {
    # x: (B, input_dim)
    B <- x$size(1)
    n <- self$n_items
    
    # Backbone MLP
    h <- self$backbone(x)
    
    # Lower triangular entries for each batch item
    z <- self$out(h)    # (B, num_tril)
    
    # Build raw symmetric S: (B, n, n)
    S <- torch_zeros(
      c(B, n, n),
      dtype  = x$dtype,
      device = x$device
    )
    
    num_tril <- as.integer(self$tril_row$size(1))
    
    row_idx <- (self$tril_row + 1L)$unsqueeze(1)$expand(c(B, num_tril))
    col_idx <- (self$tril_col + 1L)$unsqueeze(1)$expand(c(B, num_tril))
    
    batch_idx <- torch_arange(
      start = 1, end = B, step = 1,
      dtype = torch_long(), device = x$device
    )$unsqueeze(2)$expand(c(B, num_tril))
    
    S$index_put_(
      indices = list(batch_idx, row_idx, col_idx),
      values  = z
    )
    
    # Symmetrize
    S_t   <- S$transpose(-1, -2)
    diagS <- torch_diagonal(S, dim1 = -2, dim2 = -1)
    S     <- S + S_t - torch_diag_embed(diagS)
    
    # Eigen decomposition
    eig   <- linalg_eigh(S)
    evals <- eig[[1]]   # (B, n)
    evecs <- eig[[2]]   # (B, n, n)
    
    # Squash eigenvalues into (0, max_eig]
    min_eig <- 1e-5
    max_eig <- self$max_eig
    
    mid   <- 0.5 * (max_eig + min_eig)
    range <- 0.5 * (max_eig - min_eig)
    
    eig_pos <- mid + range * torch_tanh(evals / mid)
    
    Lambda <- torch_diag_embed(eig_pos)    # (B, n, n)
    
    # Reconstruct SPD H(X) = Q Lambda Q'
    H <- evecs$matmul(Lambda)$matmul(evecs$transpose(-1, -2))
    
    H
  }
)

################################################################################
## 6. Dataset definitions for dataloaders (fixed shapes for batch norm)
################################################################################

bt_dataset <- dataset(
  name = "bt_dataset",
  
  initialize = function(X, D, y) {
    # X: (n, dimX), D: (n, dimD), y: (n,)
    self$X <- X
    self$D <- D
    self$y <- y
  },
  
  .getitem = function(i) {
    list(
      X = self$X[i, ],   # 1D -> stacked to (batch_size, dimX)
      D = self$D[i, ],   # 1D -> stacked to (batch_size, dimD)
      y = self$y[i]
    )
  },
  
  .length = function() {
    self$X$size()[[1]]
  }
)

hessian_dataset <- dataset(
  name = "hessian_dataset",
  
  initialize = function(X, H_true) {
    # X: (n_tv, dimX)
    # H_true: (n_tv, dimD, dimD)
    self$X      <- X
    self$H_true <- H_true
  },
  
  .getitem = function(i) {
    list(
      X = self$X[i, ],        # 1D -> (batch_size, dimX)
      H = self$H_true[i, , ]  # 2D -> (batch_size, dimD, dimD)
    )
  },
  
  .length = function() {
    self$X$size()[[1]]
  }
)

################################################################################
## 7. Cross fitted training for ThetaNet and HessianLearner using dataloaders
##    (no halves: training on all observations with Splits != s)
################################################################################

theta_all <- torch_zeros(c(nobs, dimD), dtype = torch_float(), device = device)
g_all     <- torch_zeros(c(nobs, dimD), dtype = torch_float(), device = device)
H_hat_all <- torch_zeros(c(nobs, dimD, dimD), dtype = torch_float(), device = device)

cat("Starting cross fitted training over", Nsplits, "splits.\n")

for (s in seq_len(Nsplits)) {
  cat("\n============================\n")
  cat("Split", s, "of", Nsplits, "\n")
  
  # Training set: all observations with Splits != s
  idx_train_full <- which(Splits != s)
  # Test set: held out fold
  idx_test       <- which(Splits == s)
  
  n_train_full <- length(idx_train_full)
  
  if (n_train_full < 20) {
    stop("Too few training observations in split ", s, " (", n_train_full, ").")
  }
  if (length(idx_test) == 0) {
    stop("No test observations in split ", s, ".")
  }
  
  # 10 percent internal holdout for early stopping
  n_val <- max(1L, floor(0.10 * n_train_full))
  set.seed(100 + s)
  idx_val   <- sample(idx_train_full, n_val)
  idx_train <- setdiff(idx_train_full, idx_val)
  
  cat("  Train size:", length(idx_train),
      "| Val size:", length(idx_val),
      "| Test size:", length(idx_test), "\n")
  
  ##############################################################################
  ## 7.1 Train ThetaNet with dataloader on {Splits != s}
  ##############################################################################
  
  train_ds_theta <- bt_dataset(
    X = X_torch[idx_train, , drop = FALSE],
    D = D_torch[idx_train, , drop = FALSE],
    y = Y_vec[idx_train]
  )
  
  val_ds_theta <- bt_dataset(
    X = X_torch[idx_val, , drop = FALSE],
    D = D_torch[idx_val, , drop = FALSE],
    y = Y_vec[idx_val]
  )
  
  train_dl_theta <- dataloader(
    train_ds_theta,
    batch_size = theta_batch_size,
    shuffle = TRUE
  )
  
  val_dl_theta <- dataloader(
    val_ds_theta,
    batch_size = theta_batch_size,
    shuffle = FALSE
  )
  
  theta_model <- ThetaNet(
    input_dim   = dimX,
    n_items     = dimD,
    hidden_dims = theta_hidden_dims,
    activation  = theta_activation,
    dropout     = theta_dropout,
    batch_norm  = theta_batch_norm,
    clamp_val   = theta_clamp_val
  )$to(device = device)
  
  optim_theta <- optim_adamw(theta_model$parameters, lr = theta_lr)
  
  best_val_loss_theta <- Inf
  best_state_theta    <- NULL
  bad_epochs_theta    <- 0L
  
  for (epoch in seq_len(theta_num_epochs)) {
    theta_model$train()
    epoch_loss <- 0
    n_train_batches <- 0
    
    coro::loop(for (batch in train_dl_theta) {
      X_batch <- batch$X
      D_batch <- batch$D
      y_batch <- batch$y$view(c(-1))
      
      optim_theta$zero_grad()
      
      theta_batch <- theta_model(X_batch)
      eta         <- (D_batch * theta_batch)$sum(dim = 2)
      
      loss <- nnf_binary_cross_entropy_with_logits(
        eta, y_batch, reduction = "mean"
      )
      
      loss$backward()
      optim_theta$step()
      
      epoch_loss <- epoch_loss + loss$item()
      n_train_batches <- n_train_batches + 1L
    })
    
    train_loss <- epoch_loss / max(1L, n_train_batches)
    
    # Validation
    theta_model$eval()
    val_loss_acc <- 0
    n_val_batches <- 0
    
    with_no_grad({
      coro::loop(for (batch in val_dl_theta) {
        X_val_b <- batch$X
        D_val_b <- batch$D
        y_val_b <- batch$y$view(c(-1))
        
        theta_val_b <- theta_model(X_val_b)
        eta_val_b   <- (D_val_b * theta_val_b)$sum(dim = 2)
        
        val_loss_tensor <- nnf_binary_cross_entropy_with_logits(
          eta_val_b, y_val_b, reduction = "mean"
        )
        
        val_loss_acc   <- val_loss_acc + val_loss_tensor$item()
        n_val_batches  <- n_val_batches + 1L
      })
    })
    
    val_loss <- val_loss_acc / max(1L, n_val_batches)
    
    cat(sprintf(
      "  [Split %d] Theta epoch %3d | train log10(loss)=%.6f | val log10(loss)=%.6f\n",
      s, epoch, log10(train_loss), log10(val_loss)
    ))
    
    if (val_loss < best_val_loss_theta - min_delta_theta) {
      best_val_loss_theta <- val_loss
      bad_epochs_theta    <- 0L
      best_state_theta    <- lapply(theta_model$state_dict(), function(x) x$clone())
    } else {
      bad_epochs_theta <- bad_epochs_theta + 1L
      if (bad_epochs_theta >= patience_theta) {
        cat("  Early stopping ThetaNet on split", s,
            "at epoch", epoch, "\n")
        break
      }
    }
  }
  
  if (!is.null(best_state_theta)) {
    theta_model$load_state_dict(best_state_theta)
  }
  theta_model$eval()
  
  ##############################################################################
  ## 7.2 Construct true Hessians H_true on {Splits != s}
  ##############################################################################
  
  X_tv <- X_torch[idx_train_full, , drop = FALSE]
  D_tv <- D_torch[idx_train_full, , drop = FALSE]
  
  with_no_grad({
    theta_tv <- theta_model(X_tv)
    eta_tv   <- (D_tv * theta_tv)$sum(dim = 2)
    p_hat_tv <- torch_sigmoid(eta_tv)
    w_tv     <- p_hat_tv * (1 - p_hat_tv)
    
    D_exp1_tv <- D_tv$unsqueeze(3)   # (n_tv, K, 1)
    D_exp2_tv <- D_tv$unsqueeze(2)   # (n_tv, 1, K)
    
    H_true_tv <- w_tv$view(c(length(idx_train_full), 1, 1)) *
      (D_exp1_tv * D_exp2_tv)       # (n_tv, K, K)
  })
  
  # Positions within idx_train_full corresponding to train and validation
  pos_train <- match(idx_train, idx_train_full)
  pos_val   <- match(idx_val,   idx_train_full)
  
  ##############################################################################
  ## 7.3 Train HessianLearner with dataloader on {Splits != s}
  ##############################################################################
  
  train_ds_H <- hessian_dataset(
    X      = X_tv[pos_train, , drop = FALSE],
    H_true = H_true_tv[pos_train, , ]
  )
  
  val_ds_H <- hessian_dataset(
    X      = X_tv[pos_val, , drop = FALSE],
    H_true = H_true_tv[pos_val, , ]
  )
  
  train_dl_H <- dataloader(
    train_ds_H,
    batch_size = hessian_batch_size,
    shuffle = TRUE
  )
  
  val_dl_H <- dataloader(
    val_ds_H,
    batch_size = hessian_batch_size,
    shuffle = FALSE
  )
  
  hessian_model <- HessianLearner(
    input_dim   = dimX,
    n_items     = dimD,
    hidden_dims = hessian_hidden_dims,
    activation  = hessian_activation,
    dropout     = hessian_dropout,
    batch_norm  = hessian_batch_norm,
    max_eig     = hessian_max_eig
  )$to(device = device)
  
  optim_H <- optim_adam(hessian_model$parameters, lr = hessian_lr)
  
  best_val_loss_H <- Inf
  best_state_H    <- NULL
  bad_epochs_H    <- 0L
  
  for (epoch in seq_len(hessian_num_epochs)) {
    hessian_model$train()
    epoch_loss_H <- 0
    n_train_batches_H <- 0
    
    coro::loop(for (batch in train_dl_H) {
      X_batch_H <- batch$X
      H_batch   <- batch$H
      
      optim_H$zero_grad()
      
      H_pred <- hessian_model(X_batch_H)
      loss_H <- nnf_mse_loss(H_pred, H_batch)
      
      loss_H$backward()
      optim_H$step()
      
      epoch_loss_H      <- epoch_loss_H + loss_H$item()
      n_train_batches_H <- n_train_batches_H + 1L
    })
    
    train_loss_H <- epoch_loss_H / max(1L, n_train_batches_H)
    
    # Validation
    hessian_model$eval()
    val_loss_acc_H <- 0
    n_val_batches_H <- 0
    
    with_no_grad({
      coro::loop(for (batch in val_dl_H) {
        X_val_H_b <- batch$X
        H_val_b   <- batch$H
        
        H_val_pr_b <- hessian_model(X_val_H_b)
        val_loss_H_tensor <- nnf_mse_loss(H_val_pr_b, H_val_b)
        
        val_loss_acc_H   <- val_loss_acc_H + val_loss_H_tensor$item()
        n_val_batches_H  <- n_val_batches_H + 1L
      })
    })
    
    val_loss_H <- val_loss_acc_H / max(1L, n_val_batches_H)
    
    cat(sprintf(
      "  [Split %d] Hessian epoch %3d | train log10(loss)=%.6f | val log10(loss)=%.6f\n",
      s, epoch, log10(train_loss_H), log10(val_loss_H)
    ))
    
    if (val_loss_H < best_val_loss_H - min_delta_hessian) {
      best_val_loss_H <- val_loss_H
      bad_epochs_H    <- 0L
      best_state_H    <- lapply(hessian_model$state_dict(), function(x) x$clone())
    } else {
      bad_epochs_H <- bad_epochs_H + 1L
      if (bad_epochs_H >= patience_hessian) {
        cat("  Early stopping HessianLearner on split", s,
            "at epoch", epoch, "\n")
        break
      }
    }
  }
  
  if (!is.null(best_state_H)) {
    hessian_model$load_state_dict(best_state_H)
  }
  hessian_model$eval()
  
  ##############################################################################
  ## 7.4 Cross fitted predictions on the held out fold {Splits == s}
  ##############################################################################
  
  with_no_grad({
    X_test <- X_torch[idx_test, , drop = FALSE]
    D_test <- D_torch[idx_test, , drop = FALSE]
    y_test <- Y_vec[idx_test]
    
    theta_test <- theta_model(X_test)
    eta_test   <- (D_test * theta_test)$sum(dim = 2)
    p_hat_test <- torch_sigmoid(eta_test)
    w_test     <- p_hat_test * (1 - p_hat_test)
    resid_test <- p_hat_test - y_test
    
    g_test     <- resid_test$unsqueeze(2) * D_test
    H_hat_test <- hessian_model(X_test)
    
    theta_all[idx_test, ]   <- theta_test
    g_all[idx_test, ]       <- g_test
    H_hat_all[idx_test, , ] <- H_hat_test
  })
  
  cat("Completed split", s, "\n")
}

cat("\nCross fitted training complete.\n\n")

# Quick diagnostic
theta_vec_cpu <- as.numeric(theta_all$to(device = "cpu")$view(c(-1)))
hist(theta_vec_cpu, 1000,
     main = "Histogram of cross fitted theta entries",
     xlab = "theta")

################################################################################
## 8. Influence function style correction for theta(X)
################################################################################

with_no_grad({
  
  # Gradient reshaped to (n, d, 1)
  g_vec <- g_all$unsqueeze(3)                      # (n, d, 1)
  
  # Enforce invertibility via eigenvalue clamping
  eps_val <- 1e-2
  
  eig_H   <- linalg_eigh(H_hat_all)
  evals_H <- eig_H[[1]]                            # (n, d)
  evecs_H <- eig_H[[2]]                            # (n, d, d)
  
  evals_clamped <- torch_clamp(
    evals_H,
    min = eps_val,
    max = hessian_max_eig - eps_val
  )
  Lambda     <- torch_diag_embed(evals_clamped)
  Lambda_inv <- torch_diag_embed(1 / evals_clamped)
  
  H_hat_all <- evecs_H$matmul(Lambda)$matmul(evecs_H$transpose(-1, -2))
  
  H_inv_all <- evecs_H$
    matmul(Lambda_inv)$
    matmul(evecs_H$transpose(-1, -2))             # (n, d, d)
  
  # adj = H^{-1} g
  adj_vec <- H_inv_all$matmul(g_vec)$squeeze(3)   # (n, d)
  
  # Influence for preference parameters theta
  IF_pref <- theta_all - adj_vec                  # (n, d)
})

# Probability of each model being "best"

theta_all$requires_grad_(TRUE)

n_tot <- theta_all$size(1)
d     <- theta_all$size(2)
K_ext <- d + 1L

T_temp <- 1   # temperature

theta_soft <- theta_all / T_temp

zero_col <- torch_zeros(
  c(n_tot, 1L),
  dtype  = theta_soft$dtype,
  device = theta_soft$device
)

logits_ext <- torch_cat(list(zero_col, theta_soft), dim = 2)

# Numerically stable softmax
logits_ext <- logits_ext - logits_ext$amax(dim = 2, keepdim = TRUE)
P <- nnf_softmax(logits_ext, dim = 2)   # (n, d + 1)

# Jacobian J = dP / d theta via autograd
J_list <- vector("list", K_ext)

for (k in seq_len(K_ext)) {
  
  out_k <- P[, k]$sum()
  
  grad_k <- autograd_grad(
    outputs      = list(out_k),
    inputs       = list(theta_all),
    retain_graph = TRUE,
    create_graph = FALSE
  )[[1]]                                          # (n, d)
  
  J_list[[k]] <- grad_k$unsqueeze(2)              # (n, 1, d)
}

J <- torch_cat(J_list, dim = 2)                   # (n, K_ext, d)

# Final influence for best model probabilities:
# IF_best = P - J (H^{-1} g)

IF_best <- P - J$matmul(H_inv_all$matmul(g_vec))$squeeze(3)   # (n, K_ext)

# Quick summary check
iff <- as.matrix(IF_best$to(device = "cpu"))
round(apply(iff, 2, mean), 2)

################################################################################
## 9A. Summary table for Preference Parameters (theta)
################################################################################

iff_pref <- as.matrix(IF_pref$to(device = "cpu"))   # (n, d)

n <- nrow(iff_pref)
d <- ncol(iff_pref)

# Point estimates and standard errors
est_pref <- colMeans(iff_pref)
se_pref  <- apply(iff_pref, 2, sd) / sqrt(n)

# Model names from D_ columns (if present)
model_names_pref <- sub("^D_", "", d_cols)

if (length(model_names_pref) != d) {
  stop("Length of model_names_pref != number of columns in iff_pref")
}

tab_pref <- data.frame(
  model = model_names_pref,
  est   = est_pref,
  se    = se_pref,
  stringsAsFactors = FALSE
)

# Sort by estimate
tab_pref <- tab_pref[order(tab_pref$est), ]

# Insert GPT-5 at zero
insert_pos <- nrow(tab_pref) + 1
signs <- sign(tab_pref$est)

switch_idx <- which(signs[-length(signs)] < 0 & signs[-1] > 0)
if (length(switch_idx) > 0) {
  insert_pos <- switch_idx[1] + 1
}

openai_row_pref <- data.frame(
  model = "gpt_5",
  est   = 0,
  se    = NA,
  stringsAsFactors = FALSE
)

if (insert_pos == 1) {
  tab_pref <- rbind(openai_row_pref, tab_pref)
} else if (insert_pos > nrow(tab_pref)) {
  tab_pref <- rbind(tab_pref, openai_row_pref)
} else {
  tab_pref <- rbind(
    tab_pref[seq_len(insert_pos - 1), ],
    openai_row_pref,
    tab_pref[seq(from = insert_pos, to = nrow(tab_pref)), , drop = FALSE]
  )
}

# z statistics and stars
tab_pref$z <- tab_pref$est / tab_pref$se

tab_pref <- tab_pref %>%
  mutate(
    est = round(est, 3),
    se  = round(se, 3),
    z   = round(z, 3),
    ` ` = ifelse(abs(z) > 1.96 & !is.na(z), "*", "")
  )

colnames(tab_pref) <- c("Model", "Estimate", "StdError", "Z", "")

tab_pref

################################################################################
## 9B. Summary table for Probability of Being Best
################################################################################

iff_best <- as.matrix(IF_best$to(device = "cpu"))   # (n, d + 1)

n     <- nrow(iff_best)
K_ext <- ncol(iff_best)

# Point estimates and standard errors
est_best <- colMeans(iff_best)
se_best  <- apply(iff_best, 2, sd) / sqrt(n)

# Model names: GPT-5 + non-base models
model_names_best <- c("gpt_5", model_names_pref)

if (length(model_names_best) != K_ext) {
  stop("Length of model_names_best != number of columns in iff_best")
}

tab_best <- data.frame(
  model = model_names_best,
  est   = est_best,
  se    = se_best,
  stringsAsFactors = FALSE
)

# Sort by probability of being best
tab_best <- tab_best[order(tab_best$est, decreasing = TRUE), ]

# z statistics and stars
tab_best$z <- tab_best$est / tab_best$se

tab_best <- tab_best %>%
  mutate(
    est = round(est, 4),
    se  = round(se, 4),
    z   = round(z, 3),
    ` ` = ifelse(abs(z) > 1.96 & !is.na(z), "*", "")
  )

colnames(tab_best) <- c("Model", "ProbBest", "StdError", "Z", "")

tab_best

################################################################################
## 10A. Uniform critical value for Preference Parameters theta (multiplier bootstrap)
################################################################################

iff_pref <- as.matrix(IF_pref$to(device = "cpu"))   # (n, d)

n <- nrow(iff_pref)
d <- ncol(iff_pref)

est_pref <- colMeans(iff_pref)
se_pref  <- apply(iff_pref, 2, sd) / sqrt(n)

set.seed(123)

B     <- 2000L
alpha <- 0.05

psi_centered_pref <- sweep(iff_pref, 2, est_pref, FUN = "-")

T_boot_pref <- numeric(B)

for (b in seq_len(B)) {
  xi <- rnorm(n)
  boot_score <- as.numeric(crossprod(xi, psi_centered_pref)) / n
  Zb <- boot_score / se_pref
  T_boot_pref[b] <- max(abs(Zb), na.rm = TRUE)
}

crit_pref <- as.numeric(quantile(T_boot_pref, probs = 1 - alpha, na.rm = TRUE))

cat("Uniform", 100 * (1 - alpha), "% critical value (Preference theta):",
    round(crit_pref, 3), "\n")

################################################################################
## 10B. Pointwise critical value for Probability of Being Best
################################################################################

iff_best <- as.matrix(IF_best$to(device = "cpu"))   # (n, d + 1)

n2 <- nrow(iff_best)
K2 <- ncol(iff_best)

est_best <- colMeans(iff_best)
se_best  <- apply(iff_best, 2, sd) / sqrt(n2)

# Pointwise Gaussian critical value
z_point <- qnorm(1 - alpha / 2)

cat("Pointwise 95 percent critical value for Prob(best):",
    round(z_point, 3), "\n")

################################################################################
## 11A. Summary Table for Preference Parameters theta (Uniform Inference)
################################################################################

model_names_pref_short <- sub("^ED", "", d_cols)

tab_pref_uni <- data.frame(
  Model    = model_names_pref_short,
  Estimate = est_pref,
  StdError = se_pref,
  stringsAsFactors = FALSE
)

tab_pref_uni <- tab_pref_uni[order(tab_pref_uni$Estimate), ]

# Insert GPT-5 as base with zero
openai_row_uni <- data.frame(
  Model    = "gpt_5",
  Estimate = 0,
  StdError = NA
)

tab_pref_uni <- rbind(openai_row_uni, tab_pref_uni)

tab_pref_uni$Z <- tab_pref_uni$Estimate / tab_pref_uni$StdError

tab_pref_uni <- tab_pref_uni %>%
  mutate(
    Estimate = round(Estimate, 3),
    StdError = round(StdError, 3),
    Z        = round(Z, 3),
    Stars    = ifelse(abs(Z) > crit_pref & !is.na(Z), "*", "")
  )

tab_pref_uni

################################################################################
## 11B. Summary Table for Probability of Being Best (Pointwise Inference)
################################################################################

model_names_best2 <- c("gpt_5", model_names_pref_short)

tab_best_pw <- data.frame(
  Model    = model_names_best2,
  ProbBest = est_best,
  StdError = se_best,
  stringsAsFactors = FALSE
)

tab_best_pw$Z <- tab_best_pw$ProbBest / tab_best_pw$StdError

tab_best_pw <- tab_best_pw %>%
  mutate(
    ProbBest = round(ProbBest, 4),
    StdError = round(StdError, 4),
    Z        = round(Z, 3),
    Stars    = ifelse(abs(Z) > z_point & !is.na(Z), "*", "")
  ) %>%
  arrange(desc(ProbBest))

tab_best_pw

################################################################################
## 12. Uniform Confidence Band Plot for Preference Parameters theta
################################################################################

tab_plot <- tab_pref_uni %>%
  filter(!is.na(StdError)) %>%
  mutate(
    Lower = Estimate - crit_pref * StdError,
    Upper = Estimate + crit_pref * StdError
  )

tab_plot$Model <- factor(tab_plot$Model, levels = tab_plot$Model)

ggplot(tab_plot, aes(x = Model, y = Estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.4) +
  geom_errorbar(
    aes(ymin = Lower, ymax = Upper),
    width = 0.2
  ) +
  geom_point(size = 2) +
  coord_flip() +
  labs(
    x     = "Model",
    y     = "Bradley-Terry Preference Parameter",
    title = "Uniform Confidence Bands for Preference Parameters"
  ) +
  theme_minimal(base_size = 12)

################################################################################
## 13. Token-Length Heterogeneity (theta only, single model)
################################################################################

# Token length is first covariate by construction
token_length <- as.numeric(X[, 1])

colnames(iff_pref) <- model_names_pref_short

plot_token_bins <- function(y_vec, main_title) {
  
  p_obj <- binsreg::binsreg(
    y          = y_vec,
    x          = token_length,
    dots       = c(2, 2),
    cb         = c(3, 3),
    line       = c(3, 3),
    plotxrange = c(0, log(8000)),
    nsims      = 2000,
    simsgrid   = 100,
    randcut    = 1
  )$bins_plot
  
  token_color <- "#D55E00"
  
  for (i in seq_along(p_obj$layers)) {
    g <- p_obj$layers[[i]]$geom
    if (inherits(g, "GeomRibbon")) {
      p_obj$layers[[i]]$aes_params$fill   <- token_color
      p_obj$layers[[i]]$aes_params$alpha  <- 0.5
    } else if (inherits(g, "GeomLine")) {
      p_obj$layers[[i]]$aes_params$colour    <- token_color
      p_obj$layers[[i]]$aes_params$linewidth <- 0.8
    } else if (inherits(g, "GeomPoint")) {
      p_obj$layers[[i]]$aes_params$colour <- token_color
    }
  }
  
  p_obj +
    geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.5) +
    scale_y_continuous(n.breaks = 10) +
    scale_x_continuous(n.breaks = 10, limits = c(0, log(8000))) +
    ylab("Preference Parameter Estimate and 95 percent UCB") +
    xlab("(Log) Input Message Token Length") +
    theme_bw() +
    ggtitle(main_title)
}

iff_mistral         <- iff_pref[, "mistral_medium_3_1"]
iff_gpt5_mini       <- iff_pref[, "gpt_5_mini"]
iff_mistral_vs_nano <- iff_pref[, "mistral_medium_3_1"] -
  iff_pref[, "gpt_5_nano"]

plot_token_bins(
  iff_mistral,
  "Conditional Bradley-Terry: Mistral Medium 3.1 vs GPT-5"
)

plot_token_bins(
  iff_gpt5_mini,
  "Conditional Bradley-Terry: GPT-5 Mini vs GPT-5"
)

plot_token_bins(
  iff_mistral_vs_nano,
  "Conditional Bradley-Terry: Mistral Medium 3.1 vs GPT-5 Nano"
)

################################################################################
## 14. Prompt-specific heterogeneity via cosine similarity (theta only)
################################################################################

prompts <- read.csv(
  "~/Dropbox/bt_het/Scripts/Python/prompt_embeddings.csv",
  stringsAsFactors = FALSE
)

prompt_mat <- as.matrix(prompts[, grep("^e[0-9]+$", names(prompts))])

task_names <- c("Coding Task", "Concept Explanation", "Text Generation")

row_normalize <- function(m) {
  norms <- sqrt(rowSums(m^2))
  norms[norms == 0] <- 1
  m / norms
}

doc_norm    <- row_normalize(X[, -1, drop = FALSE])
prompt_norm <- row_normalize(prompt_mat)

cosine_sim <- doc_norm %*% t(prompt_norm)
colnames(cosine_sim) <- task_names

model_plot <- "gpt_5_nano"
iff_plot   <- iff_pref[, model_plot, drop = TRUE]
nobs_plot  <- length(iff_plot)

dataset_plot <- data.frame(
  id  = c(
    rep(task_names[1], nobs_plot),
    rep(task_names[2], nobs_plot),
    rep(task_names[3], nobs_plot)
  ),
  iff = rep(iff_plot, 3),
  cos = as.vector(cosine_sim)
)

pal <- c(
  "Coding Task"          = "#0072B2",
  "Concept Explanation"  = "#D55E00",
  "Text Generation"      = "#009E73"
)

p <- binsreg::binsreg(
  y           = iff,
  x           = cos,
  by          = id,
  bycolors    = pal,
  bysymbols   = rep(16, 3),
  legendTitle = "Conversation Task Category",
  data        = dataset_plot,
  dots        = c(2, 2),
  cb          = c(3, 3),
  line        = c(3, 3),
  nsims       = 2000,
  simsgrid    = 100,
  randcut     = 1
)$bins_plot

p <- p +
  scale_color_manual(values = pal) +
  scale_fill_manual(values = pal)

ribbon_idx <- sapply(p$layers, function(ly) inherits(ly$geom, "GeomRibbon"))
for (i in which(ribbon_idx)) {
  p$layers[[i]]$aes_params$alpha <- 0.5
}

notes_text <- paste0(
  "**Coding Task**: \"Write a Python moving-average function.\"<br>",
  "**Concept Explanation**: \"Explain how interest rates affect inflation.\"<br>",
  "**Text Generation**: \"Rewrite this paragraph more professionally.\""
)

p_clean <- p +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.5) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.5) +
  scale_y_continuous(n.breaks = 10) +
  scale_x_continuous(n.breaks = 10, limits = c(-1, 1)) +
  xlab("Cosine Similarity") +
  ylab("Preference Parameter Estimate and 95 percent UCB") +
  ggtitle(
    "Conditional Bradley-Terry: GPT-5 Mini vs GPT-5",
    subtitle = "Prompt-Specific Heterogeneity by Task Similarity"
  ) +
  annotate("text", x = -0.5, y = Inf, label = "Less Similar",
           hjust = 0.5, vjust = 1.2, size = 4, fontface = "italic") +
  annotate("text", x =  0.5, y = Inf, label = "More Similar",
           hjust = 0.5, vjust = 1.2, size = 4, fontface = "italic") +
  labs(caption = notes_text) +
  theme_bw() +
  theme(
    plot.caption = ggtext::element_markdown(
      size   = 8,
      hjust  = 0,
      margin = margin(t = 8)
    )
  )

p_clean

################################################################################
## End of script
################################################################################

library(policytree)
train = rbinom(nobs, size = 1, prob = 0.5)
opt.tree <- policy_tree(X[train == 1,], cbind(iff_pref[train == 1,], "gpt_5" = rep(0,sum(train))), depth = 3)
opt.tree

best_iff = cbind(iff_pref[train == 0,], "gpt_5" = rep(0,sum(1-train)))
newD = predict(opt.tree, X[train == 0, ])
chosen_IF = best_iff[cbind(1:nrow(best_iff), newD)]
mean(chosen_IF)
sd(chosen_IF)/sqrt(sum(1-train))





