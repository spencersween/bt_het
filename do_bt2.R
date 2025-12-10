setwd("~/bt_het")

#!/usr/bin/env Rscript
# Main execution script for Heterogeneous Bradley-Terry model

############################################################
# Setup and Data Loading
############################################################

rm(list = ls())

# Source all functions (in a real package, these would be loaded via library())
source("R/zzz.R")
load_all()

# Load required libraries
library(dplyr)
library(purrr)
library(lubridate)
library(arrow)
library(torch)
library(coro)
library(ggplot2)
library(tidyr)
library(data.table)
library(binsreg)
library(grf)

############################################################
# 1. Read raw parquet and build core df_clean
############################################################

# cat("Loading data...\n")
# bt_df = data.table::fread("/Users/spencersween/my_bradley_terry/arena_bt_emb_pcoding.csv")
# 
# X = bt_df %>% dplyr::select(starts_with("e")) %>% as.matrix()
# Y = as.numeric(bt_df$y)
# D = bt_df %>% dplyr::select(starts_with("D")) %>% dplyr::select(-D_gpt_4) %>% as.matrix()
# P = as.numeric(bt_df$p_coding)
# J = as.numeric(as.factor(bt_df$judge))
# p = ncol(X)
# k_minus_1 = ncol(D)
# model_names_km1 = colnames(D)
# 
# S = create_folds(bt_df %>% mutate(judge = J), nfolds = 3, seed = 123)
# 
# library(data.table)
# library(dplyr)

bt_df <- fread("/Users/spencersween/my_bradley_terry/final_merged_chatbot.csv")

bt_df <- bt_df |>
  mutate(
    y = as.integer(winner == "model_a"),
    i_coding = as.integer(is_code),
    e_umap_1 = umap_1,
    e_umap_2 = umap_2,
    e_umap_3 = umap_3,
    e_umap_4 = umap_4,
    e_umap_5 = umap_5,
    judge = as.numeric(as.factor(judge_hash))
  )

models <- sort(unique(c(bt_df$model_a, bt_df$model_b)))
for (m in models) {
  col <- paste0("D_", m)
  bt_df[[col]] <- 0L
  bt_df[[col]][bt_df$model_a == m] <- 1L
  bt_df[[col]][bt_df$model_b == m] <- -1L
}

X <- bt_df %>% select(starts_with("e")) %>% as.matrix()
Y <- as.numeric(bt_df$y)
D <- bt_df %>% select(starts_with("D")) %>% select(-`D_gpt-4o-2024-08-06`) %>% as.matrix()
P <- as.numeric(bt_df$prob_cluster_0)
J <- as.numeric(as.factor(bt_df$judge))
p <- ncol(X)
k_minus_1 <- ncol(D)
model_names_km1 <- colnames(D)

S <- create_folds(bt_df %>% mutate(judge = J), nfolds = 10, seed = 123)


############################################################
# 4. Run neural net with cross-fitting (heterogeneous BT)
############################################################

cat("\n============================================================\n")
cat("Running heterogeneous BT with cross-fitting\n")
cat("============================================================\n")

device = "cpu"  # or if (cuda_is_available()) "cuda" else "cpu"

fit = train_crossfit(
  X             = X,
  D             = D,
  Y             = Y,
  S             = S,
  hidden_bt     = rep(20,3),
  dropout_bt    = rep(0.10,3),
  use_batchnorm_bt = TRUE,
  hidden_h      = rep(20, 3),
  dropout_h     = rep(0.10,3),
  use_batchnorm_h  = TRUE,
  lr_bt         = 1e-2,
  lr_h          = 1e-2,
  weight_decay_bt = 1e-3,
  weight_decay_h  = 1e-3,
  batch_size_bt = 2^15,
  batch_size_h  = 2^15,
  max_epochs_bt = 1000,
  max_epochs_h  = 1000,
  patience_bt   = 5,
  patience_h    = 5,
  device        = device,
  verbose       = TRUE,
  hess_ridge    = 1e-5
)

cat("\nCross-fitting completed successfully!\n")


cat("\n============================================================\n")
cat("Plotting training history\n")
cat("============================================================\n")

loss_hist_bt_df = purrr::imap_dfr(
  fit$history_bt,
  ~ dplyr::mutate(.x, fold = .y, stage = "BT")
)

loss_hist_h_df = purrr::imap_dfr(
  fit$history_h,
  ~ dplyr::mutate(.x, fold = .y, stage = "Hessian")
)

loss_hist_long = dplyr::bind_rows(loss_hist_bt_df, loss_hist_h_df) %>%
  tidyr::pivot_longer(
    cols = c(train_loss, val_loss),
    names_to = "set",
    values_to = "loss"
  )

p_loss = ggplot(loss_hist_long,
                aes(x = epoch, y = loss, color = set)) +
  geom_line() +
  facet_grid(stage ~ fold, scales = "free_y") +
  labs(
    title = "Training and validation loss by fold and stage",
    x = "Epoch",
    y = "Loss",
    color = "Set"
  ) +
  theme_minimal()

print(p_loss)

############################################################
# 4. Lambda(x) density plots
############################################################

cat("\n============================================================\n")
cat("Plotting lambda(x) distributions\n")
cat("============================================================\n")

lambda_oof = fit$oof_lambda
colnames(lambda_oof) = model_names_km1

dens_df = as.data.frame(lambda_oof) %>%
  dplyr::mutate(row = dplyr::row_number()) %>%
  tidyr::pivot_longer(-row, names_to = "model", values_to = "lambda_hat") %>%
  dplyr::filter(is.finite(lambda_hat))

p_dens = ggplot(dens_df, aes(x = lambda_hat, color = as.factor(model))) +
  geom_density(alpha = 0.25) +
  labs(
    title = "Density of Estimated Coefficients lambda_i(x) (OOF)",
    x = "lambda_i(x)",
    y = "Density"
  ) +
  theme_minimal()

print(p_dens)

############################################################
# 6. Binsreg example for a specific model
############################################################

psi_oof = fit$oof_psi

tau = as.data.frame(psi_oof) %>%
  dplyr::mutate(row = dplyr::row_number()) %>%
  tidyr::pivot_longer(-row, names_to = "model", values_to = "lambda_hat") %>%
  dplyr::filter(is.finite(lambda_hat)) %>%
  dplyr::filter(model == "D_gpt-4o-mini-2024-07-18") %>%
  dplyr::pull(lambda_hat) %>%
  as.numeric()

p_bins = binsreg::binsreg(
  y       = tau,
  x       = bt_df$prob_cluster_9,
  dots    = c(2,2),
  ci      = c(2,2),
  cb      = c(2, 2),
  polyreg = 3,
  randcut = 1, 
  cluster = J,
  nsims = 2000, simsgrid=50
)
print(p_bins$bins_plot + geom_hline(yintercept = 0, linetype = "dashed"))



utau = coef(glm(Y ~ -1 + D, family = "binomial"))
names(utau) = colnames(D)
point_estimates = colMeans(psi_oof)
standard_errors = sqrt(diag(sandwich::vcovCL(lm(psi_oof ~ 1), cluster = J)))
models = colnames(psi_oof)
results = tibble(Models = models, Logit = utau, Point_Estimates = point_estimates, Standard_Errors = standard_errors) %>% 
  mutate(Logit = round(Logit,3), 
         Point_Estimates = round(Point_Estimates,3),
         Standard_Errors = round(Standard_Errors,3)) %>% 
  arrange(-Logit) %>% 
  print(n = 50)







