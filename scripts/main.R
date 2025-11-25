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

cat("Loading data...\n")
df = arrow::read_parquet("~/Downloads/train-00000-of-00001-cced8514c7ed782a.parquet")

cat("Building cleaned dataset...\n")
df_clean = build_clean_data(df)

cat("Loading processed data files...\n")
final_df1 = data.table::fread("/Users/spencersween/Downloads/chatbot_processed.csv")
final_df2 = data.table::fread("/Users/spencersween/Downloads/chatbot_processed2.csv")

cat("Preparing Bradley-Terry data...\n")
data_list = prepare_bt_data(df_clean, final_df1, final_df2)
bt_df = data_list$bt_df
final_df1 = data_list$final_df1
final_df2 = data_list$final_df2

############################################################
# 2. Classical Bradley Terry logit on strictly non toxic
############################################################

cat("\n============================================================\n")
cat("Fitting classical Bradley-Terry model\n")
cat("============================================================\n")

bt_classical = fit_classical_bt(bt_df, base_model = "gpt-4")
lambda = bt_classical$lambda
lambda_sorted = bt_classical$lambda_sorted

cat("\nClassical BT coefficients (sorted):\n")
print(round(lambda_sorted, digits = 3))

cat("\nExample: P(claude-v1 beats gpt-4) =\n")
cat(round(bt_prob("claude-v1", "gpt-4", lambda), digits = 3), "\n")

# Pooled BT coefficients that will be aligned to the stage 1 D later
bt_coef_pool = bt_classical$coef_hat

############################################################
# 3. Prepare features for neural network
############################################################

cat("\n============================================================\n")
cat("Preparing features for neural network\n")
cat("============================================================\n")

features = prepare_features(bt_df, final_df1, final_df2)
X = features$X
Y = features$Y
D = features$D
P = features$P
J = features$J
p = features$p
k_minus_1 = features$k_minus_1
model_names_km1 = features$model_names_km1

# Create cross-validation folds
cat("Creating cross-validation folds...\n")
S = create_folds(bt_df, nfolds = 10, seed = 123)

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
  hidden_bt     = rep(100, 2),
  dropout_bt    = rep(0.1, 2),
  use_batchnorm_bt = FALSE,
  hidden_h      = rep(100, 2),
  dropout_h     = rep(0.1, 2),
  use_batchnorm_h  = FALSE,
  lr_bt         = 1e-3,
  lr_h          = 1e-3,
  weight_decay_bt = 1e-3,
  weight_decay_h  = 1e-3,
  batch_size_bt = 2^15,
  batch_size_h  = 2^15,
  max_epochs_bt = 1000,
  max_epochs_h  = 1000,
  patience_bt   = 20,
  patience_h    = 20,
  device        = device,
  verbose       = TRUE,
  hess_ridge    = 1e-5
)

cat("\nCross-fitting completed successfully!\n")

############################################################
# 5. Save results
############################################################

cat("\nSaving results...\n")
save(fit, bt_classical, lambda, lambda_sorted, 
     X, Y, D, P, J, S, bt_df,
     file = "results/crossfit_results.RData")

cat("Results saved to results/crossfit_results.RData\n")

