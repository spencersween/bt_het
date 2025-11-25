#!/usr/bin/env Rscript
# Analysis script for cross-fitting results

library(dplyr)
library(purrr)
library(ggplot2)
library(tidyr)
library(binsreg)

# Source all functions
source("R/zzz.R")
load_all()

############################################################
# 1. Load results
############################################################

if (!exists("fit")) {
  load("results/crossfit_results.RData")
}

############################################################
# 2. Training and validation loss curves per outer fold and stage
############################################################

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
ggsave("plots/training_history.png", p_loss, width = 10, height = 6)

############################################################
# 3. OOF BT net metrics and lambda(x) plots
############################################################

cat("\n============================================================\n")
cat("Computing out-of-fold metrics\n")
cat("============================================================\n")

oof_p = fit$oof_prob_stage1
oof_y = Y

stopifnot(!any(is.na(oof_p)))

oof_auc     = auc_fast(oof_y, oof_p)
oof_logloss = compute_logloss(oof_y, oof_p)

cat(sprintf("\nOOF AUC (BT net): %.4f   OOF LogLoss: %.6f\n", oof_auc, oof_logloss))

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
ggsave("plots/lambda_density.png", p_dens, width = 10, height = 6)

############################################################
# 5. Compare mean heterogeneous coefficients to unconditional BT logit
############################################################

cat("\n============================================================\n")
cat("Comparing heterogeneous vs unconditional coefficients\n")
cat("============================================================\n")

psi_oof = fit$oof_psi
colnames(psi_oof) = model_names_km1

lambda_nn_mean = colMeans(psi_oof, na.rm = TRUE)

lambda_nn_df = dplyr::tibble(
  model_col       = names(lambda_nn_mean),
  model           = sub("^D_", "", model_col),
  lambda_nn_mean  = as.numeric(lambda_nn_mean)
)

lambda_uncond_df = dplyr::tibble(
  model          = names(lambda),
  lambda_uncond  = as.numeric(lambda)
)

coef_compare = lambda_nn_df %>%
  dplyr::left_join(lambda_uncond_df, by = "model") %>%
  dplyr::arrange(desc(lambda_uncond)) %>%
  dplyr::mutate(
    lambda_nn_mean = round(lambda_nn_mean, 3),
    lambda_uncond  = round(lambda_uncond, 3)
  )

cat("\n=== Mean heterogeneous lambda_i(x) (OOF) vs unconditional BT coefficients ===\n")
print(coef_compare)

############################################################
# 6. Binsreg example for a specific model
############################################################

cat("\n============================================================\n")
cat("Binsreg analysis for D_claude-v1\n")
cat("============================================================\n")

tau = as.data.frame(psi_oof) %>%
  dplyr::mutate(row = dplyr::row_number()) %>%
  tidyr::pivot_longer(-row, names_to = "model", values_to = "lambda_hat") %>%
  dplyr::filter(is.finite(lambda_hat)) %>%
  dplyr::filter(model == "D_claude-v1") %>%
  dplyr::pull(lambda_hat) %>%
  as.numeric()

p_bins = binsreg::binsreg(
  y       = tau,
  x       = P,
  dots    = c(2, 2),
  cb      = c(3, 3),
  polyreg = 3,
  randcut = 1, 
  cluster = J
)

print(p_bins$bins_plot + geom_hline(yintercept = 0, linetype = "dashed"))
ggsave("plots/binsreg_claude-v1.png", p_bins$bins_plot + geom_hline(yintercept = 0, linetype = "dashed"), 
       width = 10, height = 6)

utau = lambda_uncond_df %>%
  dplyr::filter(model == "claude-v1") %>%
  dplyr::select(lambda_uncond) %>%
  as.matrix() %>%
  as.numeric()

p_tau_dens = dplyr::tibble(tau = tau) %>%
  ggplot2::ggplot(aes(x = tau)) +
  geom_density() +
  geom_vline(xintercept = utau) +
  labs(
    title = "Density of tau for claude-v1 vs unconditional coefficient",
    x = "tau (heterogeneous lambda)",
    y = "Density"
  ) +
  theme_minimal()

print(p_tau_dens)
ggsave("plots/tau_density_claude-v1.png", p_tau_dens, width = 8, height = 6)

############################################################
# 7. Save tables and summaries
############################################################

cat("\n============================================================\n")
cat("Saving tables and summaries\n")
cat("============================================================\n")

# Ensure tables directory exists
dir.create("tables", showWarnings = FALSE)

# Save coefficient comparison
write.csv(coef_compare, 
          "tables/coefficient_comparison.csv", 
          row.names = FALSE)

# Save metrics summary
metrics_summary = data.frame(
  metric = c("AUC", "Log Loss"),
  value = c(oof_auc, oof_logloss)
)
write.csv(metrics_summary, 
          "tables/metrics_summary.csv", 
          row.names = FALSE)

# Save lambda summary (heterogeneous vs unconditional)
lambda_summary = lambda_nn_df %>%
  dplyr::left_join(lambda_uncond_df, by = "model") %>%
  dplyr::arrange(desc(lambda_uncond))

write.csv(lambda_summary, 
          "tables/lambda_summary.csv", 
          row.names = FALSE)

cat("Tables saved to tables/ directory\n")
cat("\n============================================================\n")
cat("All analysis complete!\n")
cat("  - Plots: plots/ directory\n")
cat("  - Tables: tables/ directory\n")
cat("============================================================\n")

