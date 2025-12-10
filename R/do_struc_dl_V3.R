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
## Preference pipeline:
##   1. Theta_net: X -> theta(X) in R^K  (coefficient functions, K = #non-base models)
##   2. Bradley-Terry loss: eta_i = D_pref,i · theta(X_i), p_i = sigmoid(eta_i)
##   3. At fitted theta_hat(X_i), construct per observation:
##        - gradient g_pref,i = d ell_i / d theta(X_i)  (K-vector)
##        - Hessian  H_pref,i = d^2 ell_i / d theta(X_i) d theta(X_i)'  (K x K)
##   4. Train Hessian net H_pref_net: X -> H_pref(X) (SPD, eigenvalues in (0, 0.25])
##   5. Influence-style object for preference parameters:
##        IF_pref,i = theta_hat(X_i) - H_pref_hat(X_i)^{-1} g_pref,i
##
## Cost pipeline (energy E only):
##   - We keep a separate design D_cost with **all** models, in order:
##       model 1 = base model (e.g., GPT-5),
##       models 2..K_ext = non-base models (same order as D_pref).
##   - E is 2D:
##       E[,1] is energy for A side model
##       E[,2] is energy for B side model
##   - For each model k and observation i:
##       if D_cost,ik =  1 then C_ik = E_i1
##       if D_cost,ik = -1 then C_ik = E_i2
##       if D_cost,ik =  0 then C_ik is unobserved
##   - Cost_net: X -> kappa(X) in R^K_ext (per-model cost functions, base included).
##   - Squared loss:
##        ell_i^cost = 0.5 * sum_k m_ik (kappa_ik(X_i) - C_ik)^2,
##        where m_ik = 1 if |D_cost,ik| = 1, else 0.
##   - Gradient: g_cost,i = m_i ⊙ (kappa_i - C_i).
##   - Cost Hessian block:
##        H_cost(x) = diag(pi(x)),
##        where pi_k(x) = P(m_k = 1 | X = x) is a propensity.
##   - PropensityNet: X -> bounded logits for m_ik, trained with BCE.
##     Then pi_hat_k(X) = sigmoid(logit_k(X)), and
##        H_cost_hat(X) = diag(pi_hat(X)).
##   - Influence-style object for cost parameters:
##        IF_cost,i = kappa_hat(X_i) - H_cost_hat(X_i)^{-1} g_cost,i
##
## Influence function targets:
##   1) Preference parameters theta_j (non-base only).
##   2) Probabilities P_j(X) of being the best model (base + non-base).
##   3) Cost parameters kappa_j (base + non-base).
##   4) Cost × probability-best: f_j(X) = kappa_j(X) * P_j(X) (base + non-base).
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

use_labs <- FALSE    # TRUE: use LD_* (labs); FALSE: use MD_* / ED_*
use_ecol <- TRUE    # TRUE: ecologits (ED / energy costs) available

base_lab <- "LDopenai"  # Use OpenAI as base lab
base_mod <- "MDgpt_5"   # Use GPT-5 as base model
base_eco <- "EDgpt_5"   # Use GPT-5 as base ecologits model

# Basic filtering
dat_clean <- dat
if (drop_nres) dat_clean <- dat_clean %>% dplyr::filter(did_vote == 1)
if (drop_ties) dat_clean <- dat_clean %>% dplyr::filter(tied == 0)
if (use_ecol)  dat_clean <- dat_clean %>% dplyr::filter(has_model_ecologits == 1)

# Decide which family of treatments we are using
if (use_labs) {
  # Use labs LD_*
  base_name <- base_lab
  prefix    <- "^LD"
  Y         <- as.matrix(dat_clean$Y_lab, ncol = 1)
} else {
  if (use_ecol) {
    # Ecologits ED_* on Y_model
    base_name <- base_eco
    prefix    <- "^ED"
    Y         <- as.matrix(dat_clean$Y_model, ncol = 1)
  } else {
    # All models MD_* on Y_model
    base_name <- base_mod
    prefix    <- "^MD"
    Y         <- as.matrix(dat_clean$Y_model, ncol = 1)
  }
}

if(use_ecol & use_labs) {
  d_cols_pref = c("LDanthropic", "LDcohere", "LDmistral", "LDgoogle")
  D_pref      <- as.matrix(dat_clean[, d_cols_pref, drop = FALSE])
  d_cols_cost = c("LDanthropic", "LDcohere", "LDmistral", "LDgoogle", "LDopenai")
  D_cost      <- as.matrix(dat_clean[, d_cols_cost, drop = FALSE])
} else {
  
  # All treatment columns of the chosen family, base included
  all_d_cols <- grep(prefix, names(dat_clean), value = TRUE)
  
  # Preference design: drop base (reference)
  d_cols_pref <- setdiff(all_d_cols, base_name)
  D_pref      <- as.matrix(dat_clean[, d_cols_pref, drop = FALSE])
  
  # Cost design: base first, then non-base in same order as D_pref
  d_cols_cost <- c(base_name, d_cols_pref)
  D_cost      <- as.matrix(dat_clean[, d_cols_cost, drop = FALSE])
}

# Covariates
x_cols <- grep("^X_", names(dat_clean), value = TRUE)
X      <- as.matrix(dat_clean[, x_cols, drop = FALSE])

# Judge ids
Judge <- as.matrix(dat_clean$judge_id, ncol = 1)

# Energy (E), CO2 (G), water (H)
if (use_ecol) {
  E <- cbind(dat_clean$log_energy_a, dat_clean$log_energy_b)
  G <- cbind(dat_clean$log_co2_a,    dat_clean$log_co2_b)
  H <- cbind(dat_clean$log_h2o_a,    dat_clean$log_h2o_b)
} else {
  nobs_tmp <- nrow(dat_clean)
  E <- matrix(0, nrow = nobs_tmp, ncol = 2)
  G <- matrix(0, nrow = nobs_tmp, ncol = 2)
  H <- matrix(0, nrow = nobs_tmp, ncol = 2)
}

# Dimensions
nobs       <- nrow(D_pref)      # number of battles
dimD_pref  <- ncol(D_pref)      # #non-base models
dimD_cost  <- ncol(D_cost)      # #all models (base + non-base)
dimX       <- ncol(X)           # covariates
dimD       <- dimD_pref         # alias for "preference dimension"

# For convenience later
d_cols <- d_cols_pref

# Cross fitting splits at judge level
Nsplits <- 2

Splits <- tibble(Judge = Judge[, 1]) %>%
  group_by(Judge) %>%
  mutate(Splits = sample(1:Nsplits, size = 1)) %>%
  ungroup() %>%
  pull(Splits)

################################################################################
## 2. Convert to torch tensors
################################################################################

X_torch      <- torch_tensor(X,       dtype = torch_float(), device = device)$view(c(nobs, dimX))
D_pref_torch <- torch_tensor(D_pref,  dtype = torch_float(), device = device)$view(c(nobs, dimD_pref))
D_cost_torch <- torch_tensor(D_cost,  dtype = torch_float(), device = device)$view(c(nobs, dimD_cost))
Y_torch      <- torch_tensor(Y,       dtype = torch_float(), device = device)$view(c(nobs, 1L))
Judge_torch  <- torch_tensor(Judge,       dtype = torch_float(), device = device)$view(c(nobs, 1L))
E_torch      <- torch_tensor(E,       dtype = torch_float(), device = device)$view(c(nobs, 2L))
G_torch      <- torch_tensor(G,       dtype = torch_float(), device = device)$view(c(nobs, 2L))
H_torch      <- torch_tensor(H,       dtype = torch_float(), device = device)$view(c(nobs, 2L))

# Convenient 1d outcome vector
Y_vec <- Y_torch$view(c(nobs))

################################################################################
## 2B. Cost targets and masks (energy E only, using D_cost_torch)
################################################################################
## D_cost_torch has dimension dimD_cost = 1 (base) + dimD_pref (non-base)

mask_pos_cost <- (D_cost_torch ==  1)   # model on A side
mask_neg_cost <- (D_cost_torch == -1)   # model on B side
mask_active_torch <- (mask_pos_cost | mask_neg_cost)$to(dtype = torch_float())  # m_ik

# Build cost targets C_ik from E
E_A <- E_torch[, 1]$unsqueeze(2)$expand(c(nobs, dimD_cost))
E_B <- E_torch[, 2]$unsqueeze(2)$expand(c(nobs, dimD_cost))

Cost_target_torch <- mask_pos_cost$to(dtype = torch_float()) * E_A +
  mask_neg_cost$to(dtype = torch_float()) * E_B

################################################################################
## 3. Hyperparameters, activations, and generic MLP backbone
################################################################################

# Early stopping
patience_theta    <- 20L
patience_hessian  <- 20L
min_delta_theta   <- 1e-5
min_delta_hessian <- 1e-5

# Theta net hyperparameters
theta_hidden_dims      <- c(5,5)
theta_activation       <- "relu"     # "relu", "tanh", "elu", "identity", "leaky"
theta_final_activation <- "identity"  # optional final activation on theta output
theta_dropout          <- 0.00
theta_batch_norm       <- FALSE
theta_lr               <- 1e-2
theta_num_epochs       <- 1000L
theta_batch_size       <- 128L
theta_clamp_val        <- log((1 - 1e-5) / (1e-5))

# Hessian net for preference
hessian_hidden_dims <- c(5,5)
hessian_activation  <- "relu"
hessian_dropout     <- 0.00
hessian_batch_norm  <- FALSE
hessian_lr          <- 1e-2
hessian_num_epochs  <- 1000L
hessian_batch_size  <- 128L
hessian_max_eig     <- 0.25

# Cost net hyperparameters (kappa)
cost_hidden_dims      <- c(5,5)
cost_activation       <- "relu"
cost_final_activation <- "identity"
cost_dropout          <- 0.00
cost_batch_norm       <- FALSE
cost_lr               <- 1e-2
cost_num_epochs       <- 1000L
cost_batch_size       <- 128L

# Propensity net hyperparameters (for cost Hessian)
prop_hidden_dims      <- c(5,5)
prop_activation       <- "relu"
prop_final_activation <- "identity"  # identity on bounded logits
prop_dropout          <- 0.00
prop_batch_norm       <- FALSE
prop_lr               <- 1e-2
prop_num_epochs       <- 1000L
prop_batch_size       <- 128L
prop_logit_clamp      <- log((1 - 1e-5) / (1e-5))  # bounds for logits

# Gaussian critical value for pointwise CIs
alpha   <- 0.05
z_point <- qnorm(1 - alpha / 2)

# Helper activation
apply_activation <- function(x, act) {
  if (is.null(act) || act == "identity") {
    x
  } else if (act == "relu") {
    nnf_relu(x)
  } else if (act == "leaky") {
    nnf_leaky_relu(x)
  } else if (act == "elu") {
    nnf_elu(x)
  } else if (act == "tanh") {
    torch_tanh(x)
  } else if (act == "sigmoid") {
    torch_sigmoid(x)
  } else {
    x
  }
}

# Generic MLP backbone
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
                        hidden_dims      = c(64, 64),
                        activation       = "relu",
                        final_activation = "identity",
                        dropout          = 0.0,
                        batch_norm       = FALSE,
                        clamp_val        = NULL) {
    
    self$n_items          <- n_items
    self$clamp_val        <- clamp_val
    self$final_activation <- final_activation
    
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
    
    theta <- apply_activation(theta, self$final_activation)
    theta
  }
)

################################################################################
## 5. HessianLearner: conditional Hessian net H_pref(X) for preference block
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
    B <- x$size(1)
    n <- self$n_items
    
    h <- self$backbone(x)
    z <- self$out(h)    # (B, num_tril)
    
    S <- torch_zeros(c(B, n, n), dtype = x$dtype, device = x$device)
    
    num_tril <- as.integer(self$tril_row$size(1))
    
    row_idx <- (self$tril_row + 1L)$unsqueeze(1)$expand(c(B, num_tril))
    col_idx <- (self$tril_col + 1L)$unsqueeze(1)$expand(c(B, num_tril))
    batch_idx <- torch_arange(
      start = 1, end = B, step = 1,
      dtype = torch_long(), device = x$device
    )$unsqueeze(2)$expand(c(B, num_tril))
    
    S$index_put_(indices = list(batch_idx, row_idx, col_idx), values = z)
    
    S_t   <- S$transpose(-1, -2)
    diagS <- torch_diagonal(S, dim1 = -2, dim2 = -1)
    S     <- S + S_t - torch_diag_embed(diagS)
    
    # Add a small jitter on the diagonal to avoid ill conditioned matrices
    eps_eig <- 1e-5
    eye_n <- torch_eye(n, dtype = x$dtype, device = x$device)$unsqueeze(1)$expand(c(B, n, n))
    S <- S + eps_eig * eye_n
    
    eig   <- linalg_eigh(S)
    evals <- eig[[1]]
    evecs <- eig[[2]]
    
    min_eig <- 1e-5
    max_eig <- self$max_eig
    
    mid   <- 0.5 * (max_eig + min_eig)
    range <- 0.5 * (max_eig - min_eig)
    
    eig_pos <- mid + range * torch_tanh(evals / mid)
    
    Lambda  <- torch_diag_embed(eig_pos)
    H       <- evecs$matmul(Lambda)$matmul(evecs$transpose(-1, -2))
    H
  }
)

################################################################################
## 6. CostNet and PropensityNet (cost side has base + non-base models)
################################################################################

CostNet <- nn_module(
  "CostNet",
  
  initialize = function(input_dim,
                        n_items,
                        hidden_dims      = c(32, 32),
                        activation       = "leaky",
                        final_activation = "identity",
                        dropout          = 0.0,
                        batch_norm       = FALSE) {
    
    self$n_items          <- n_items
    self$final_activation <- final_activation
    
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
    kappa_raw <- self$out(h)
    kappa     <- apply_activation(kappa_raw, self$final_activation)
    kappa
  }
)

PropensityNet <- nn_module(
  "PropensityNet",
  
  initialize = function(input_dim,
                        n_items,
                        hidden_dims      = c(32, 32),
                        activation       = "leaky",
                        final_activation = "identity",
                        dropout          = 0.0,
                        batch_norm       = FALSE,
                        logit_clamp      = NULL) {
    
    self$n_items          <- n_items
    self$logit_clamp      <- logit_clamp
    self$final_activation <- final_activation
    
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
    logits_raw <- self$out(h)
    
    if (!is.null(self$logit_clamp)) {
      L <- self$logit_clamp
      logits_raw <- L * torch_tanh(logits_raw / L)
    }
    
    logits <- apply_activation(logits_raw, self$final_activation)
    logits
  }
)

################################################################################
## 7. Dataset definitions for dataloaders
################################################################################

bt_dataset <- dataset(
  name = "bt_dataset",
  
  initialize = function(X, D, y) {
    self$X <- X
    self$D <- D
    self$y <- y
  },
  
  .getitem = function(i) {
    list(
      X = self$X[i, ],
      D = self$D[i, ],
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
    self$X      <- X
    self$H_true <- H_true
  },
  
  .getitem = function(i) {
    list(
      X = self$X[i, ],
      H = self$H_true[i, , ]
    )
  },
  
  .length = function() {
    self$X$size()[[1]]
  }
)

cost_dataset <- dataset(
  name = "cost_dataset",
  
  initialize = function(X, Cost_target, mask_active) {
    self$X           <- X
    self$Cost_target <- Cost_target
    self$mask_active <- mask_active
  },
  
  .getitem = function(i) {
    list(
      X           = self$X[i, ],
      Cost_target = self$Cost_target[i, ],
      mask_active = self$mask_active[i, ]
    )
  },
  
  .length = function() {
    self$X$size()[[1]]
  }
)

propensity_dataset <- dataset(
  name = "propensity_dataset",
  
  initialize = function(X, mask_active) {
    self$X           <- X
    self$mask_active <- mask_active
  },
  
  .getitem = function(i) {
    list(
      X = self$X[i, ],
      m = self$mask_active[i, ]
    )
  },
  
  .length = function() {
    self$X$size()[[1]]
  }
)

################################################################################
## 8. Cross fitted training for ThetaNet, HessianLearner, CostNet, PropensityNet
################################################################################

theta_all      <- torch_zeros(c(nobs, dimD_pref), dtype = torch_float(), device = device)
g_all          <- torch_zeros(c(nobs, dimD_pref), dtype = torch_float(), device = device)
H_hat_all      <- torch_zeros(c(nobs, dimD_pref, dimD_pref), dtype = torch_float(), device = device)

kappa_all      <- torch_zeros(c(nobs, dimD_cost), dtype = torch_float(), device = device)
g_cost_all     <- torch_zeros(c(nobs, dimD_cost), dtype = torch_float(), device = device)
pi_hat_all     <- torch_zeros(c(nobs, dimD_cost), dtype = torch_float(), device = device)
H_hat_cost_all <- torch_zeros(c(nobs, dimD_cost, dimD_cost), dtype = torch_float(), device = device)

cat("Starting cross fitted training over", Nsplits, "splits.\n")

for (s in seq_len(Nsplits)) {
  cat("\n============================\n")
  cat("Split", s, "of", Nsplits, "\n")
  
  idx_train_full <- which(Splits != s)
  idx_test       <- which(Splits == s)
  
  n_train_full <- length(idx_train_full)
  
  if (n_train_full < 20) {
    stop("Too few training observations in split ", s, " (", n_train_full, ").")
  }
  if (length(idx_test) == 0) {
    stop("No test observations in split ", s, ".")
  }
  
  # Internal validation for early stopping
  n_val <- max(1L, floor(0.10 * n_train_full))
  set.seed(100 + s)
  idx_val   <- sample(idx_train_full, n_val)
  idx_train <- setdiff(idx_train_full, idx_val)
  
  cat("  Train size:", length(idx_train),
      "| Val size:", length(idx_val),
      "| Test size:", length(idx_test), "\n")
  
  ##############################################################################
  ## 8.1 Preference: Train ThetaNet on D_pref
  ##############################################################################
  
  train_ds_theta <- bt_dataset(
    X = X_torch[idx_train, , drop = FALSE],
    D = D_pref_torch[idx_train, , drop = FALSE],
    y = Y_vec[idx_train]
  )
  
  val_ds_theta <- bt_dataset(
    X = X_torch[idx_val, , drop = FALSE],
    D = D_pref_torch[idx_val, , drop = FALSE],
    y = Y_vec[idx_val]
  )
  
  train_dl_theta <- dataloader(
    train_ds_theta,
    batch_size = theta_batch_size,
    shuffle    = TRUE
  )
  
  val_dl_theta <- dataloader(
    val_ds_theta,
    batch_size = theta_batch_size,
    shuffle    = FALSE
  )
  
  theta_model <- ThetaNet(
    input_dim        = dimX,
    n_items          = dimD_pref,
    hidden_dims      = theta_hidden_dims,
    activation       = theta_activation,
    final_activation = theta_final_activation,
    dropout          = theta_dropout,
    batch_norm       = theta_batch_norm,
    clamp_val        = theta_clamp_val
  )$to(device = device)
  
  optim_theta <- optim_adamw(theta_model$parameters, lr = theta_lr)
  
  best_val_loss_theta <- Inf
  best_state_theta    <- NULL
  bad_epochs_theta    <- 0L
  
  for (epoch in seq_len(theta_num_epochs)) {
    theta_model$train()
    epoch_loss      <- 0
    n_train_batches <- 0L
    
    coro::loop(for (batch in train_dl_theta) {
      X_batch <- batch$X
      D_batch <- batch$D
      y_batch <- batch$y$view(c(-1))
      
      optim_theta$zero_grad()
      
      theta_batch <- theta_model(X_batch)             # (B, dimD_pref)
      eta         <- (D_batch * theta_batch)$sum(dim = 2)
      
      loss <- nnf_binary_cross_entropy_with_logits(
        eta, y_batch, reduction = "mean"
      )
      
      loss$backward()
      optim_theta$step()
      
      epoch_loss      <- epoch_loss + loss$item()
      n_train_batches <- n_train_batches + 1L
    })
    
    train_loss <- epoch_loss / max(1L, n_train_batches)
    
    # Validation
    theta_model$eval()
    val_loss_acc  <- 0
    n_val_batches <- 0L
    
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
        
        val_loss_acc  <- val_loss_acc + val_loss_tensor$item()
        n_val_batches <- n_val_batches + 1L
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
  ## 8.2 Preference: True Hessians on {Splits != s} and HessianLearner training
  ##############################################################################
  
  X_tv      <- X_torch[idx_train_full, , drop = FALSE]
  D_pref_tv <- D_pref_torch[idx_train_full, , drop = FALSE]
  Y_tv      <- Y_vec[idx_train_full]
  
  with_no_grad({
    theta_tv <- theta_model(X_tv)                        # (n_tv, dimD_pref)
    eta_tv   <- (D_pref_tv * theta_tv)$sum(dim = 2)
    p_hat_tv <- torch_sigmoid(eta_tv)
    w_tv     <- p_hat_tv * (1 - p_hat_tv)
    
    resid_tv <- p_hat_tv - Y_tv
    
    D_exp1_tv <- D_pref_tv$unsqueeze(3)   # (n_tv, K, 1)
    D_exp2_tv <- D_pref_tv$unsqueeze(2)   # (n_tv, 1, K)
    
    H_true_tv <- w_tv$view(c(length(idx_train_full), 1, 1)) *
      (D_exp1_tv * D_exp2_tv)             # (n_tv, K, K)
  })
  
  pos_train <- match(idx_train, idx_train_full)
  pos_val   <- match(idx_val,   idx_train_full)
  
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
    shuffle    = TRUE
  )
  
  val_dl_H <- dataloader(
    val_ds_H,
    batch_size = hessian_batch_size,
    shuffle    = FALSE
  )
  
  hessian_model <- HessianLearner(
    input_dim   = dimX,
    n_items     = dimD_pref,
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
    epoch_loss_H      <- 0
    n_train_batches_H <- 0L
    
    coro::loop(for (batch in train_dl_H) {
      X_b <- batch$X
      H_b <- batch$H
      
      optim_H$zero_grad()
      
      H_pred_b <- hessian_model(X_b)
      loss_H   <- nnf_mse_loss(H_pred_b, H_b)
      
      loss_H$backward()
      optim_H$step()
      
      epoch_loss_H      <- epoch_loss_H + loss_H$item()
      n_train_batches_H <- n_train_batches_H + 1L
    })
    
    train_loss_H <- epoch_loss_H / max(1L, n_train_batches_H)
    
    hessian_model$eval()
    val_loss_acc_H  <- 0
    n_val_batches_H <- 0L
    
    with_no_grad({
      coro::loop(for (batch in val_dl_H) {
        X_b <- batch$X
        H_b <- batch$H
        
        H_val_b           <- hessian_model(X_b)
        val_loss_H_tensor <- nnf_mse_loss(H_val_b, H_b)
        
        val_loss_acc_H  <- val_loss_acc_H + val_loss_H_tensor$item()
        n_val_batches_H <- n_val_batches_H + 1L
      })
    })
    
    val_loss_H <- val_loss_acc_H / max(1L, n_val_batches_H)
    
    cat(sprintf(
      "  [Split %d] Hessian pref epoch %3d | train log10(loss)=%.6f | val log10(loss)=%.6f\n",
      s, epoch, log10(train_loss_H), log10(val_loss_H)
    ))
    
    if (val_loss_H < best_val_loss_H - min_delta_hessian) {
      best_val_loss_H <- val_loss_H
      bad_epochs_H    <- 0L
      best_state_H    <- lapply(hessian_model$state_dict(), function(x) x$clone())
    } else {
      bad_epochs_H <- bad_epochs_H + 1L
      if (bad_epochs_H >= patience_hessian) {
        cat("  Early stopping HessianLearner (pref) on split", s,
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
  ## 8.3 Preference: Cross fitted predictions on held out fold {Splits == s}
  ##############################################################################
  
  with_no_grad({
    X_test      <- X_torch[idx_test, , drop = FALSE]
    D_pref_test <- D_pref_torch[idx_test, , drop = FALSE]
    y_test      <- Y_vec[idx_test]
    
    theta_test <- theta_model(X_test)                    # (n_test, dimD_pref)
    eta_test   <- (D_pref_test * theta_test)$sum(dim = 2)
    p_hat_test <- torch_sigmoid(eta_test)
    w_test     <- p_hat_test * (1 - p_hat_test)
    resid_test <- p_hat_test - y_test
    
    g_test     <- resid_test$unsqueeze(2) * D_pref_test
    H_hat_test <- hessian_model(X_test)
    
    theta_all[idx_test, ]   <- theta_test
    g_all[idx_test, ]       <- g_test
    H_hat_all[idx_test, , ] <- H_hat_test
  })
  
  ##############################################################################
  ## 8.4 Cost: CostNet training on {Splits != s}
  ##############################################################################
  
  train_ds_cost <- cost_dataset(
    X           = X_torch[idx_train, , drop = FALSE],
    Cost_target = Cost_target_torch[idx_train, , drop = FALSE],
    mask_active = mask_active_torch[idx_train, , drop = FALSE]
  )
  
  val_ds_cost <- cost_dataset(
    X           = X_torch[idx_val, , drop = FALSE],
    Cost_target = Cost_target_torch[idx_val, , drop = FALSE],
    mask_active = mask_active_torch[idx_val, , drop = FALSE]
  )
  
  train_dl_cost <- dataloader(
    train_ds_cost,
    batch_size = cost_batch_size,
    shuffle    = TRUE
  )
  
  val_dl_cost <- dataloader(
    val_ds_cost,
    batch_size = cost_batch_size,
    shuffle    = FALSE
  )
  
  cost_model <- CostNet(
    input_dim        = dimX,
    n_items          = dimD_cost,    # base + non-base
    hidden_dims      = cost_hidden_dims,
    activation       = cost_activation,
    final_activation = cost_final_activation,
    dropout          = cost_dropout,
    batch_norm       = cost_batch_norm
  )$to(device = device)
  
  optim_cost <- optim_adam(cost_model$parameters, lr = cost_lr)
  
  best_val_cost   <- Inf
  best_state_cost <- NULL
  bad_epochs_cost <- 0L
  
  for (epoch in seq_len(cost_num_epochs)) {
    cost_model$train()
    train_loss_acc <- 0
    n_batches      <- 0L
    
    coro::loop(for (batch in train_dl_cost) {
      X_b  <- batch$X
      Ct_b <- batch$Cost_target
      m_b  <- batch$mask_active
      
      optim_cost$zero_grad()
      
      kappa_b <- cost_model(X_b)          # (B, dimD_cost)
      res_b   <- (kappa_b - Ct_b) * m_b
      loss_b  <- 0.5 * (res_b^2)$mean()
      
      loss_b$backward()
      optim_cost$step()
      
      train_loss_acc <- train_loss_acc + loss_b$item()
      n_batches      <- n_batches + 1L
    })
    
    train_loss <- train_loss_acc / max(1L, n_batches)
    
    cost_model$eval()
    val_loss_acc  <- 0
    n_val_batches <- 0L
    
    with_no_grad({
      coro::loop(for (batch in val_dl_cost) {
        X_b  <- batch$X
        Ct_b <- batch$Cost_target
        m_b  <- batch$mask_active
        
        kappa_b <- cost_model(X_b)
        res_b   <- (kappa_b - Ct_b) * m_b
        loss_b  <- 0.5 * (res_b^2)$mean()
        
        val_loss_acc  <- val_loss_acc + loss_b$item()
        n_val_batches <- n_val_batches + 1L
      })
    })
    
    val_loss <- val_loss_acc / max(1L, n_val_batches)
    
    cat(sprintf(
      "  [Split %d] Cost epoch %3d | train log10(MSE)=%.6f | val log10(MSE)=%.6f\n",
      s, epoch, log10(train_loss), log10(val_loss)
    ))
    
    if (val_loss < best_val_cost - min_delta_hessian) {
      best_val_cost   <- val_loss
      bad_epochs_cost <- 0L
      best_state_cost <- lapply(cost_model$state_dict(), function(x) x$clone())
    } else {
      bad_epochs_cost <- bad_epochs_cost + 1L
      if (bad_epochs_cost >= patience_hessian) {
        cat("  Early stopping CostNet on split", s,
            "at epoch", epoch, "\n")
        break
      }
    }
  }
  
  if (!is.null(best_state_cost)) {
    cost_model$load_state_dict(best_state_cost)
  }
  cost_model$eval()
  
  ##############################################################################
  ## 8.5 Cost Hessian: PropensityNet training on {Splits != s}
  ##############################################################################
  
  train_ds_prop <- propensity_dataset(
    X           = X_torch[idx_train, , drop = FALSE],
    mask_active = mask_active_torch[idx_train, , drop = FALSE]
  )
  
  val_ds_prop <- propensity_dataset(
    X           = X_torch[idx_val, , drop = FALSE],
    mask_active = mask_active_torch[idx_val, , drop = FALSE]
  )
  
  train_dl_prop <- dataloader(
    train_ds_prop,
    batch_size = prop_batch_size,
    shuffle    = TRUE
  )
  
  val_dl_prop <- dataloader(
    val_ds_prop,
    batch_size = prop_batch_size,
    shuffle    = FALSE
  )
  
  prop_model <- PropensityNet(
    input_dim        = dimX,
    n_items          = dimD_cost,
    hidden_dims      = prop_hidden_dims,
    activation       = prop_activation,
    final_activation = prop_final_activation,
    dropout          = prop_dropout,
    batch_norm       = prop_batch_norm,
    logit_clamp      = prop_logit_clamp
  )$to(device = device)
  
  optim_prop <- optim_adam(prop_model$parameters, lr = prop_lr)
  
  best_val_prop   <- Inf
  best_state_prop <- NULL
  bad_epochs_prop <- 0L
  
  for (epoch in seq_len(prop_num_epochs)) {
    prop_model$train()
    train_loss_acc <- 0
    n_batches      <- 0L
    
    coro::loop(for (batch in train_dl_prop) {
      X_b <- batch$X
      m_b <- batch$m
      
      optim_prop$zero_grad()
      
      logits_b <- prop_model(X_b)
      loss_b   <- nnf_binary_cross_entropy_with_logits(
        logits_b, m_b, reduction = "mean"
      )
      
      loss_b$backward()
      optim_prop$step()
      
      train_loss_acc <- train_loss_acc + loss_b$item()
      n_batches      <- n_batches + 1L
    })
    
    train_loss <- train_loss_acc / max(1L, n_batches)
    
    prop_model$eval()
    val_loss_acc  <- 0
    n_val_batches <- 0L
    
    with_no_grad({
      coro::loop(for (batch in val_dl_prop) {
        X_b <- batch$X
        m_b <- batch$m
        
        logits_b <- prop_model(X_b)
        loss_b   <- nnf_binary_cross_entropy_with_logits(
          logits_b, m_b, reduction = "mean"
        )
        
        val_loss_acc  <- val_loss_acc + loss_b$item()
        n_val_batches <- n_val_batches + 1L
      })
    })
    
    val_loss <- val_loss_acc / max(1L, n_val_batches)
    
    cat(sprintf(
      "  [Split %d] Propensity epoch %3d | train log10(BCE)=%.6f | val log10(BCE)=%.6f\n",
      s, epoch, log10(train_loss), log10(val_loss)
    ))
    
    if (val_loss < best_val_prop - min_delta_hessian) {
      best_val_prop   <- val_loss
      bad_epochs_prop <- 0L
      best_state_prop <- lapply(prop_model$state_dict(), function(x) x$clone())
    } else {
      bad_epochs_prop <- bad_epochs_prop + 1L
      if (bad_epochs_prop >= patience_hessian) {
        cat("  Early stopping PropensityNet on split", s,
            "at epoch", epoch, "\n")
        break
      }
    }
  }
  
  if (!is.null(best_state_prop)) {
    prop_model$load_state_dict(best_state_prop)
  }
  prop_model$eval()
  
  ##############################################################################
  ## 8.6 Cost: cross fitted predictions on held out fold {Splits == s}
  ##############################################################################
  
  with_no_grad({
    X_test_cf <- X_torch[idx_test, , drop = FALSE]
    Ct_test   <- Cost_target_torch[idx_test, , drop = FALSE]
    m_test    <- mask_active_torch[idx_test, , drop = FALSE]
    
    # Cost means
    kappa_test  <- cost_model(X_test_cf)          # (n_test, dimD_cost)
    res_cost    <- (kappa_test - Ct_test) * m_test
    g_cost_test <- res_cost                       # grad of 0.5 * res^2
    
    # Propensities and cost Hessian
    logits_test <- prop_model(X_test_cf)
    pi_test     <- torch_sigmoid(logits_test)
    H_cost_test <- torch_diag_embed(pi_test)
    
    kappa_all[idx_test, ]        <- kappa_test
    g_cost_all[idx_test, ]       <- g_cost_test
    pi_hat_all[idx_test, ]       <- pi_test
    H_hat_cost_all[idx_test, , ] <- H_cost_test
  })
  
  cat("Completed split", s, "\n")
}

cat("\nCross fitted training complete.\n\n")

################################################################################
## Diagnostics
################################################################################

theta_vec_cpu <- as.numeric(theta_all$to(device = "cpu")$view(c(-1)))
hist(theta_vec_cpu, 1000,
     main = "Histogram of cross fitted theta entries",
     xlab = "theta")

kappa_vec_cpu <- as.numeric(kappa_all$to(device = "cpu")$view(c(-1)))
hist(kappa_vec_cpu, 1000,
     main = "Histogram of cross fitted kappa entries",
     xlab = "kappa")

################################################################################
## 9. Influence functions
##  9A. IF for preference parameters theta (non-base)
##  9B. IF for probabilities of being best model (base + non-base)
##  9C. IF for cost parameters kappa (base + non-base)
##  9D. IF for cost × probability-best (base + non-base)
################################################################################

n      <- nobs
d_pref <- dimD_pref
d_cost <- dimD_cost          # should equal d_pref + 1
K_ext  <- d_cost

## 9A. Preference parameters theta #############################################

# Gradient stack g_pref
g_vec <- g_all$unsqueeze(3)                      # (n, d_pref, 1)

# Eigen-based inversion for H_pref
eps_val <- 1e-5

eig_pref   <- linalg_eigh(H_hat_all)
evals_pref <- eig_pref[[1]]                      # (n, d_pref)
evecs_pref <- eig_pref[[2]]                      # (n, d_pref, d_pref)

evals_pref_clamped <- torch_clamp(
  evals_pref,
  min = eps_val,
  max = hessian_max_eig - eps_val
)

Lambda_pref     <- torch_diag_embed(evals_pref_clamped)
Lambda_pref_inv <- torch_diag_embed(1 / evals_pref_clamped)

H_hat_all <- evecs_pref$matmul(Lambda_pref)$matmul(evecs_pref$transpose(-1, -2))

# H_inv_all <- evecs_pref$matmul(Lambda_pref_inv)$matmul(evecs_pref$transpose(-1, -2))
H_inv_all = linalg_pinv(H_hat_all) # + torch_tensor(diag(1e-5, nrow = dimD, ncol = dimD)))

# One-step IF for theta
adj_pref <- H_inv_all$matmul(g_vec)$squeeze(3)   # (n, d_pref)
IF_pref  <- theta_all - adj_pref                 # (n, d_pref)

apply(as.matrix(IF_pref), 2, mean)
apply(as.matrix(IF_pref), 2, sd) / sqrt(n)

## 9B. Probabilities of being best model #######################################

theta_for_prob <- theta_all$detach()$clone()
theta_for_prob$requires_grad_(TRUE)

theta_soft <- theta_for_prob   # temperature = 1
zero_col   <- torch_zeros(
  c(n, 1L),
  dtype  = theta_soft$dtype,
  device = theta_soft$device
)

logits_ext <- torch_cat(list(zero_col, theta_soft), dim = 2)   # (n, 1 + d_pref)
P <- nnf_softmax(logits_ext, dim = 2)                         # (n, K_ext = 1 + d_pref)

# Jacobian J = dP / d theta via autograd
J_list <- vector("list", K_ext)
for (k_idx in seq_len(K_ext)) {
  out_k <- P[, k_idx]$sum()
  grad_k <- autograd_grad(
    outputs      = list(out_k),
    inputs       = list(theta_for_prob),
    retain_graph = TRUE,
    create_graph = FALSE
  )[[1]]                                        # (n, d_pref)
  J_list[[k_idx]] <- grad_k$unsqueeze(2)        # (n, 1, d_pref)
}
J <- torch_cat(J_list, dim = 2)                 # (n, K_ext, d_pref)

# IF for P (best probabilities) using same H_inv_all and g_vec
delta_theta <- H_inv_all$matmul(g_vec)               # (n, d_pref, 1)
IF_best     <- P - J$matmul(delta_theta)$squeeze(3)  # (n, K_ext)

apply(as.matrix(IF_best), 2, mean)
apply(as.matrix(IF_best), 2, sd) / sqrt(n)

## 9C. Cost parameters kappa ###################################################

eps_cost <- 1e-5

pi_clamped <- torch_clamp(
  pi_hat_all,
  min = eps_cost,
  max = 1 - eps_cost
)

H_inv_cost_all <- torch_diag_embed(1 / pi_clamped)  # (n, d_cost, d_cost)

g_cost_vec <- g_cost_all$unsqueeze(3)               # (n, d_cost, 1)
adj_cost   <- H_inv_cost_all$matmul(g_cost_vec)$squeeze(3)
IF_cost    <- kappa_all - adj_cost                  # (n, d_cost)

apply(as.matrix(IF_cost), 2, mean)
apply(as.matrix(IF_cost), 2, sd) / sqrt(n)


## 9D. Cost × probability-best #################################################
## f_ij = kappa_ij * P_ij, for all models j = 1..K_ext (base + non-base).
## Gradient w.r.t psi = (theta, kappa):
##   ∂f_ij/∂theta_l = kappa_ij * ∂P_ij/∂theta_l   (l = 1..d_pref)
##   ∂f_ij/∂kappa_l = P_ij if l = j, else 0       (l = 1..K_ext)

# Combined psi and gradients
psi_all   <- torch_cat(list(theta_all, kappa_all), dim = 2)   # (n, d_pref + d_cost)
g_total   <- torch_cat(list(g_all, g_cost_all), dim = 2)      # (n, d_pref + d_cost)
g_total_v <- g_total$unsqueeze(3)                             # (n, d_pref + d_cost, 1)

# Block-diagonal H_inv_big
H_inv_big <- torch_zeros(c(n, d_pref + d_cost, d_pref + d_cost),
                         dtype = torch_float(), device = device)
H_inv_big[, 1:d_pref, 1:d_pref] <- H_inv_all
H_inv_big[, (d_pref + 1):(d_pref + d_cost), (d_pref + 1):(d_pref + d_cost)] <- H_inv_cost_all

delta_psi_all <- H_inv_big$matmul(g_total_v)$squeeze(3)       # (n, d_pref + d_cost)

# Gradients of f_ij w.r.t theta: (n, K_ext, d_pref)
kappa_exp <- kappa_all$unsqueeze(3)                           # (n, K_ext, 1)
grad_theta <- kappa_exp * J                                   # (n, K_ext, d_pref)

# Gradients of f_ij w.r.t kappa: diag(P) per obs -> (n, K_ext, K_ext)
grad_kappa <- torch_diag_embed(P)                             # (n, K_ext, K_ext)

# Combine into gradient w.r.t psi: (n, K_ext, d_pref + d_cost)
grad_psi <- torch_cat(list(grad_theta, grad_kappa), dim = 3)

# Apply delta_psi_all: (n, 1, d_pref + d_cost)
delta_exp <- delta_psi_all$unsqueeze(2)                       # (n, 1, d_pref + d_cost)

# adj_cost_best_ij = sum_l grad_psi_ij,l * delta_psi_i,l
adj_cost_best <- (grad_psi * delta_exp)$sum(dim = 3)          # (n, K_ext)

# Plug-in f_ij
f_hat <- kappa_all * P                                        # (n, K_ext)

IF_cost_best <- f_hat - adj_cost_best                         # (n, K_ext)

# 1. Parameter estimates (θ_f_hat, θ_p_hat) as sample means
theta_f_hat <- torch_mean(IF_cost_best, dim = 1)  # (K)
theta_p_hat <- torch_mean(IF_best,      dim = 1)  # (K)

# 2. Reshape for broadcasting: (1, K)
theta_f_hat_b <- theta_f_hat$unsqueeze(1)  # (1, K)
theta_p_hat_b <- theta_p_hat$unsqueeze(1)  # (1, K)

# 3. Delta-method influence for ratio θ_r = θ_f / θ_p:
#    IF_r = IF_f / θ_p - (θ_f / θ_p^2) * IF_p
IF_ratio <- IF_cost_best / theta_p_hat_b -
  (theta_f_hat_b / (theta_p_hat_b^2)) * (IF_best - theta_p_hat)

IF_cost_best = IF_ratio

apply(as.matrix(IF_cost_best), 2, mean)
apply(as.matrix(IF_cost_best), 2, sd) / sqrt(n)


################################################################################
## 10. Pointwise tables for the four functionals
################################################################################

# Model naming
# Non-base model internal names (e.g. "EDmistral") from D_pref
model_names_pref_internal <- d_cols_pref
# Short names: strip LD/MD/ED prefixes
model_names_pref_short    <- sub("^LD|^MD|^ED", "", d_cols_pref)

# Base model label (short)
base_internal <- base_name
base_short    <- sub("^LD|^MD|^ED", "", base_internal)

# All models (base + non-base) for cost / prob-best / cost×best
model_names_cost_short <- c(base_short, model_names_pref_short)

########## 10A. Preference parameters theta ####################################

iff_pref <- as.matrix(IF_pref$to(device = "cpu"))   # (n, d_pref)

n_pref <- nrow(iff_pref)
d_p    <- ncol(iff_pref)

est_pref <- colMeans(iff_pref)
se_pref  <- apply(iff_pref, 2, sd) / sqrt(n_pref)
z_pref   <- est_pref / se_pref

if (length(model_names_pref_short) != d_p) {
  stop("Length of model_names_pref_short != number of columns in iff_pref")
}

tab_pref <- data.frame(
  Model    = model_names_pref_short,
  Estimate = est_pref,
  StdError = se_pref,
  Z        = z_pref,
  stringsAsFactors = FALSE
)

tab_pref <- tab_pref[order(tab_pref$Estimate), ]

tab_pref <- tab_pref %>%
  mutate(
    Estimate = round(Estimate, 3),
    StdError = round(StdError, 3),
    Z        = round(Z, 3),
    Stars    = ifelse(abs(Z) > z_point & !is.na(Z), "*", "")
  )

tab_pref

########## 10B. Probabilities of being best ####################################

iff_best <- as.matrix(IF_best$to(device = "cpu"))   # (n, K_ext)

n2     <- nrow(iff_best)
K2    <- ncol(iff_best)

est_best <- colMeans(iff_best)
se_best  <- apply(iff_best, 2, sd) / sqrt(n2)
z_best   <- est_best / se_best

if (length(model_names_cost_short) != K2) {
  stop("Length of model_names_cost_short != number of columns in iff_best")
}

tab_best <- data.frame(
  Model    = model_names_cost_short,
  ProbBest = est_best,
  StdError = se_best,
  Z        = z_best,
  stringsAsFactors = FALSE
)

tab_best <- tab_best[order(tab_best$ProbBest, decreasing = TRUE), ]

tab_best <- tab_best %>%
  mutate(
    ProbBest = round(ProbBest, 4),
    StdError = round(StdError, 4),
    Z        = round(Z, 3),
    Stars    = ifelse(abs(Z) > z_point & !is.na(Z), "*", "")
  )

tab_best

########## 10C. Cost parameters kappa (base + non-base) ########################

iff_cost <- as.matrix(IF_cost$to(device = "cpu"))   # (n, d_cost)

n_c  <- nrow(iff_cost)
d_c  <- ncol(iff_cost)

est_cost <- colMeans(iff_cost)
se_cost  <- apply(iff_cost, 2, sd) / sqrt(n_c)
z_cost   <- est_cost / se_cost

if (length(model_names_cost_short) != d_c) {
  stop("Length of model_names_cost_short != number of columns in iff_cost")
}

tab_cost <- data.frame(
  Model    = model_names_cost_short,
  Cost     = est_cost,
  StdError = se_cost,
  Z        = z_cost,
  stringsAsFactors = FALSE
)

tab_cost <- tab_cost[order(tab_cost$Cost), ]

tab_cost <- tab_cost %>%
  mutate(
    Cost     = round(Cost, 4),
    StdError = round(StdError, 4),
    Z        = round(Z, 3),
    Stars    = ifelse(abs(Z) > z_point & !is.na(Z), "*", "")
  )

tab_cost

########## 10D. Cost × probability-best (base + non-base) ######################

iff_cost_best <- as.matrix(IF_cost_best$to(device = "cpu"))   # (n, K_ext)

n_cb    <- nrow(iff_cost_best)
d_cb    <- ncol(iff_cost_best)

est_cost_best <- colMeans(iff_cost_best)
se_cost_best  <- apply(iff_cost_best, 2, sd) / sqrt(n_cb)
z_cost_best   <- est_cost_best / se_cost_best

if (length(model_names_cost_short) != d_cb) {
  stop("Length of model_names_cost_short != number of columns in iff_cost_best")
}

tab_cost_best <- data.frame(
  Model         = model_names_cost_short,
  CostTimesBest = est_cost_best,
  StdError      = se_cost_best,
  Z             = z_cost_best,
  stringsAsFactors = FALSE
)

tab_cost_best <- tab_cost_best[order(tab_cost_best$CostTimesBest), ]

tab_cost_best <- tab_cost_best %>%
  mutate(
    CostTimesBest = round(CostTimesBest, 4),
    StdError      = round(StdError, 4),
    Z             = round(Z, 3),
    Stars         = ifelse(abs(Z) > z_point & !is.na(Z), "*", "")
  )

tab_cost_best

################################################################################
## 11. Uniform critical values and confidence bands (all four functionals)
################################################################################

set.seed(123)
B <- 2000L

bootstrap_uniform_crit <- function(iff_mat, est_vec, se_vec, B = 2000L, alpha = 0.05) {
  n  <- nrow(iff_mat)
  psi_centered <- sweep(iff_mat, 2, est_vec, FUN = "-")
  T_boot <- numeric(B)
  for (b in seq_len(B)) {
    xi <- rnorm(n)
    boot_score <- as.numeric(crossprod(xi, psi_centered)) / n
    Zb <- boot_score / se_vec
    T_boot[b] <- max(abs(Zb), na.rm = TRUE)
  }
  as.numeric(quantile(T_boot, probs = 1 - alpha, na.rm = TRUE))
}

########## 11A. Uniform critical for theta #####################################

crit_theta_uni <- bootstrap_uniform_crit(
  iff_mat = iff_pref,
  est_vec = est_pref,
  se_vec  = se_pref,
  B       = B,
  alpha   = alpha
)

cat("Uniform", 100 * (1 - alpha), "% critical value (theta):",
    round(crit_theta_uni, 3), "\n")

########## 11B. Uniform critical for Prob(best) ################################

crit_best_uni <- bootstrap_uniform_crit(
  iff_mat = iff_best,
  est_vec = est_best,
  se_vec  = se_best,
  B       = B,
  alpha   = alpha
)

cat("Uniform", 100 * (1 - alpha), "% critical value (Prob best):",
    round(crit_best_uni, 3), "\n")

########## 11C. Uniform critical for cost ######################################

crit_cost_uni <- bootstrap_uniform_crit(
  iff_mat = iff_cost,
  est_vec = est_cost,
  se_vec  = se_cost,
  B       = B,
  alpha   = alpha
)

cat("Uniform", 100 * (1 - alpha), "% critical value (cost):",
    round(crit_cost_uni, 3), "\n")

########## 11D. Uniform critical for cost × best ###############################

crit_costbest_uni <- bootstrap_uniform_crit(
  iff_mat = iff_cost_best,
  est_vec = est_cost_best,
  se_vec  = se_cost_best,
  B       = B,
  alpha   = alpha
)

cat("Uniform", 100 * (1 - alpha), "% critical value (cost × best):",
    round(crit_costbest_uni, 3), "\n")

################################################################################
## 12. Confidence band plots (ggplot) for each functional
################################################################################

########## 12A. Preference parameters theta ####################################

tab_theta_band <- data.frame(
  Model    = model_names_pref_short,
  Estimate = est_pref,
  StdError = se_pref,
  stringsAsFactors = FALSE
)

tab_theta_band <- tab_theta_band[order(tab_theta_band$Estimate), ]

tab_theta_band <- tab_theta_band %>%
  mutate(
    Lower = Estimate - crit_theta_uni * StdError,
    Upper = Estimate + crit_theta_uni * StdError
  )

tab_theta_band$Model <- factor(tab_theta_band$Model, levels = tab_theta_band$Model)

ggplot(tab_theta_band, aes(x = Model, y = Estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.4) +
  geom_errorbar(aes(ymin = Lower, ymax = Upper), width = 0.2) +
  geom_point(size = 2) +
  coord_flip() +
  labs(
    x     = "Model",
    y     = "Bradley-Terry Preference Parameter",
    title = "Uniform Confidence Bands for Preference Parameters"
  ) +
  theme_minimal(base_size = 12)

########## 12B. Probabilities of being best ####################################

tab_best_band <- data.frame(
  Model    = model_names_cost_short,
  Estimate = est_best,
  StdError = se_best,
  stringsAsFactors = FALSE
)

tab_best_band <- tab_best_band[order(tab_best_band$Estimate, decreasing = TRUE), ]

tab_best_band <- tab_best_band %>%
  mutate(
    Lower = Estimate - crit_best_uni * StdError,
    Upper = Estimate + crit_best_uni * StdError
  )

tab_best_band$Model <- factor(tab_best_band$Model, levels = tab_best_band$Model)

ggplot(tab_best_band, aes(x = Model, y = Estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.4) +
  geom_errorbar(aes(ymin = Lower, ymax = Upper), width = 0.2) +
  geom_point(size = 2) +
  coord_flip() +
  labs(
    x     = "Model",
    y     = "Probability of Being Best",
    title = "Uniform Confidence Bands for Probability of Being Best"
  ) +
  theme_minimal(base_size = 12)

########## 12C. Cost parameters kappa ##########################################

tab_cost_band <- data.frame(
  Model    = model_names_cost_short,
  Estimate = est_cost,
  StdError = se_cost,
  stringsAsFactors = FALSE
)

tab_cost_band <- tab_cost_band[order(tab_cost_band$Estimate), ]

tab_cost_band <- tab_cost_band %>%
  mutate(
    Lower = Estimate - crit_cost_uni * StdError,
    Upper = Estimate + crit_cost_uni * StdError
  )

tab_cost_band$Model <- factor(tab_cost_band$Model, levels = tab_cost_band$Model)

ggplot(tab_cost_band, aes(x = Model, y = Estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.4) +
  geom_errorbar(aes(ymin = Lower, ymax = Upper), width = 0.2) +
  geom_point(size = 2) +
  coord_flip() +
  labs(
    x     = "Model",
    y     = "Energy Cost Parameter (log scale)",
    title = "Uniform Confidence Bands for Cost Parameters"
  ) +
  theme_minimal(base_size = 12)

########## 12D. Cost × probability-best ########################################

tab_costbest_band <- data.frame(
  Model    = model_names_cost_short,
  Estimate = est_cost_best,
  StdError = se_cost_best,
  stringsAsFactors = FALSE
)

tab_costbest_band <- tab_costbest_band[order(tab_costbest_band$Estimate), ]

tab_costbest_band <- tab_costbest_band %>%
  mutate(
    Lower = Estimate - crit_costbest_uni * StdError,
    Upper = Estimate + crit_costbest_uni * StdError
  )

tab_costbest_band$Model <- factor(tab_costbest_band$Model, levels = tab_costbest_band$Model)

ggplot(tab_costbest_band, aes(x = Model, y = Estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.4) +
  geom_errorbar(aes(ymin = Lower, ymax = Upper), width = 0.2) +
  geom_point(size = 2) +
  coord_flip() +
  labs(
    x     = "Model",
    y     = "Cost × Probability Best",
    title = "Uniform Confidence Bands for Cost × Probability Best"
  ) +
  theme_minimal(base_size = 12)

################################################################################
## 13. Token-Length Heterogeneity (theta only, as template)
################################################################################

token_length <- as.numeric(X[, 1])

# Keep internal names with prefixes so your existing references like "LDanthropic" work
colnames(iff_pref) <- model_names_pref_internal

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
    ylab("Estimate and 95 percent Uniform Band") +
    xlab("(Log) Input Message Token Length") +
    theme_bw() +
    ggtitle(main_title)
}

# Example: theta-based heterogeneity
iff_cond_token <- iff_pref[, model_names_pref_internal[1]]
plot_token_bins(
  iff_cond_token,
  "Conditional Bradley-Terry"
)

################################################################################
## 14. Prompt-specific heterogeneity via cosine similarity (theta only, template)
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

model_plot <- model_names_pref_internal[1]
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
    "Conditional Bradley-Terry",
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

opt.bestcost <- policy_tree(X, -iff_cost_best, depth = 1) #, split.step = 10)
newD_bestcost = predict(opt.bestcost, X)
policy_iff_cost_bestcost = iff_cost[cbind(1:nrow(iff_cost), newD_bestcost)]
policy_iff_best_bestcost = iff_best[cbind(1:nrow(iff_best), newD_bestcost)]
results_bestcost = tibble(cost = policy_iff_cost_bestcost, 
                          best = policy_iff_best_bestcost,
                          judge = Judge)
fixest::feols(c(cost, best) ~ 1, results_bestcost, cluster = ~judge)

opt.best <- policy_tree(X, iff_best, depth = 1) #, split.step = 10)
newD_best = predict(opt.best, X)
policy_iff_cost_best = iff_cost[cbind(1:nrow(iff_cost), newD_best)]
policy_iff_best_best = iff_best[cbind(1:nrow(iff_best), newD_best)]
results_best = tibble(cost = policy_iff_cost_best, 
                      best = policy_iff_best_best,
                      judge = Judge)
fixest::feols(c(cost, best) ~ 1, results_best, cluster = ~judge)

opt.cost <- policy_tree(X, -iff_cost, depth = 1) #, split.step = 10)
newD_cost = predict(opt.cost, X)
policy_iff_cost_cost = iff_cost[cbind(1:nrow(iff_cost), newD_cost)]
policy_iff_best_cost = iff_best[cbind(1:nrow(iff_best), newD_cost)]
results_cost = tibble(cost = policy_iff_cost_cost, 
                      best = policy_iff_best_cost,
                      judge = Judge)
fixest::feols(c(cost, best) ~ 1, results_cost, cluster = ~judge)

bestcost_vs_best = tibble(cost = policy_iff_cost_bestcost - policy_iff_cost_best,
                          best = policy_iff_best_bestcost - policy_iff_best_best,
                          judge = Judge)
fixest::feols(c(cost, best) ~ 1, bestcost_vs_best, cluster = ~judge)

bestcost_vs_cost = tibble(cost = policy_iff_cost_bestcost - policy_iff_cost_cost,
                          best = policy_iff_best_bestcost - policy_iff_best_cost,
                          judge = Judge)
fixest::feols(c(cost, best) ~ 1, bestcost_vs_cost, cluster = ~judge)




