# Quick Start Guide - Complete Codebase Overview

## 🗂️ Complete File Structure

```
bt_het/
│
├── 📁 R/                          # Core training functions
│   ├── train_bt_single.R          # Train single BT neural network
│   ├── train_hessian_single.R     # Train single Hessian network  
│   ├── train_crossfit.R           # Main cross-fitting orchestrator
│   └── zzz.R                      # Helper: load_all() function
│
├── 📁 data/                       # Data processing functions
│   ├── extract_conversation.R     # Extract Q&A from conversation data
│   ├── build_clean_data.R         # Clean raw parquet → clean dataframe
│   └── prepare_bt_data.R          # Prepare data for BT modeling
│
├── 📁 models/                     # Neural network definitions
│   ├── datasets.R                 # Torch dataset classes (bt_dataset, hessian_dataset)
│   ├── bt_net.R                   # Bradley-Terry neural network module
│   └── hessian_net.R              # Hessian network module (FIXED ✓)
│
├── 📁 utils/                      # Utility functions
│   ├── bt_classical.R             # Classical BT logistic regression
│   ├── bt_helpers.R               # BT network helpers (eta, BCE, evaluation)
│   ├── hessian_helpers.R          # Hessian utilities (lower-tri, matrix ops)
│   ├── prepare_features.R         # Build X, Y, D feature matrices
│   └── metrics.R                  # Evaluation metrics (AUC, log loss)
│
├── 📁 scripts/                    # Execution scripts
│   └── main.R                     # Main pipeline: load → fit → save
│
├── 📁 analysis/                   # Results analysis
│   └── analyze_results.R          # Plot results, compare models
│
├── 📁 config/                     # Configuration
│   └── config.R                   # All hyperparameters and paths
│
├── 📁 results/                    # Output directory (created automatically)
├── 📁 plots/                      # Plot output directory
│
└── 📄 Documentation
    ├── README.md                  # Full documentation
    ├── USAGE.md                   # Detailed usage guide
    ├── STRUCTURE.md               # Code organization explanation
    └── QUICK_START.md             # This file!
```

## 🚀 Step-by-Step Usage

### Step 1: Install Dependencies

```r
install.packages(c(
  "dplyr", "purrr", "lubridate", "arrow", "torch", "coro",
  "ggplot2", "tidyr", "data.table", "binsreg", "grf", "MASS"
))

# Install PyTorch backend for torch
library(torch)
install_torch()
```

### Step 2: Configure Your Data Paths

Edit `config/config.R`:

```r
PATH_PARQUET = "~/Downloads/train-00000-of-00001-cced8514c7ed782a.parquet"
PATH_PROCESSED1 = "/Users/spencersween/Downloads/chatbot_processed.csv"
PATH_PROCESSED2 = "/Users/spencersween/Downloads/chatbot_processed2.csv"
```

Or modify paths directly in `scripts/main.R` (lines 20-22).

### Step 3: Run the Main Pipeline

```r
# From R console or RStudio
source("scripts/main.R")
```

**What this does:**
1. ✅ Loads raw parquet file and processed CSVs
2. ✅ Cleans and processes data
3. ✅ Fits classical Bradley-Terry model (baseline)
4. ✅ Prepares features (X, Y, D matrices)
5. ✅ Creates cross-validation folds
6. ✅ Trains heterogeneous BT networks with cross-fitting
7. ✅ Saves results to `results/crossfit_results.RData`

### Step 4: Analyze Results

```r
source("analysis/analyze_results.R")
```

**What this does:**
1. ✅ Loads saved results
2. ✅ Plots training/validation loss curves → `plots/training_history.png`
3. ✅ Computes out-of-fold metrics (AUC, log loss)
4. ✅ Plots lambda(x) distributions → `plots/lambda_density.png`
5. ✅ Compares heterogeneous vs. unconditional coefficients
6. ✅ Generates binsreg visualizations → `plots/binsreg_*.png`

## 📊 Key Outputs

### Results File (`results/crossfit_results.RData`)
- `fit`: Complete cross-fitting results
  - `oof_prob_stage1`: Out-of-fold probabilities
  - `oof_lambda`: Heterogeneous coefficients λ(X)
  - `oof_psi`: Debiased coefficients ψ
  - `oof_Hbar_cols`: Conditional Hessian matrices
  - `models_bt`, `models_h`: Trained models per fold
  - `history_bt`, `history_h`: Training histories
- `bt_classical`: Classical BT model results
- `lambda`, `lambda_sorted`: Classical coefficients
- `X`, `Y`, `D`, `P`, `J`, `S`: Input data

### Plot Files (`plots/`)
- `training_history.png`: Loss curves by fold and stage
- `lambda_density.png`: Distribution of λ(X) coefficients
- `binsreg_claude-v1.png`: Binsreg visualization
- `tau_density_claude-v1.png`: Coefficient density comparison

## 🔧 Customization

### Change Hyperparameters

Edit `config/config.R` or pass to `train_crossfit()`:

```r
fit = train_crossfit(
  X = X, D = D, Y = Y, S = S,
  hidden_bt = c(256, 128),        # BT network architecture
  hidden_h = c(128, 64),          # Hessian network architecture
  lr_bt = 1e-3,                   # Learning rates
  batch_size_bt = 2048,           # Batch sizes
  max_epochs_bt = 200,            # Training epochs
  patience_bt = 15,               # Early stopping patience
  device = "cuda"                 # Use GPU if available
)
```

### Use GPU

```r
device = if (cuda_is_available()) "cuda" else "cpu"
```

## 📖 Function Reference by Use Case

### "I want to process my data"
- `extract_conversation()` - Extract Q&A pairs
- `build_clean_data()` - Clean raw data
- `prepare_bt_data()` - Filter for BT modeling
- `prepare_features()` - Build feature matrices

### "I want to fit a model"
- `fit_classical_bt()` - Classical BT (fast baseline)
- `train_crossfit()` - Heterogeneous BT with cross-fitting
  - Calls `train_bt_single()` internally
  - Calls `train_hessian_lower_single()` internally

### "I want to make predictions"
- `predict_bt_full()` - Get probabilities and lambdas
- `predict_hessian_lower()` - Get Hessian predictions
- `bt_prob()` - Compute BT probability between two models

### "I want to evaluate"
- `evaluate_loader()` - Evaluate BT network
- `evaluate_hessian_loader()` - Evaluate Hessian network
- `auc_fast()` - Compute AUC
- `compute_logloss()` - Compute log loss

### "I want to work with Hessians"
- `lower_tri_indices()` - Get lower triangular indices
- `build_lower_targets()` - Build target matrix
- `lower_to_full()` - Convert to full symmetric matrix

## 🐛 Troubleshooting

**Memory errors?**
- Reduce `batch_size_bt` and `batch_size_h` in config
- Use smaller networks (fewer hidden units)

**Slow training?**
- Use GPU: `device = "cuda"` (if available)
- Increase batch sizes (if memory allows)
- Reduce `max_epochs` for quick testing

**Convergence issues?**
- Adjust learning rates (`lr_bt`, `lr_h`)
- Increase `patience` for early stopping
- Try different architectures

## 📝 Quick Command Reference

```r
# Load all functions
source("R/zzz.R")
load_all()

# Run full pipeline
source("scripts/main.R")

# Analyze results  
source("analysis/analyze_results.R")

# Access saved results
load("results/crossfit_results.RData")
prob_oof = fit$oof_prob_stage1
lambda_oof = fit$oof_lambda
psi_oof = fit$oof_psi
```

## 🎯 What Was Fixed

The `hessian_net_lower` function in `models/hessian_net.R` had incorrect dropout calls:
- **Before:** `h = h$dropout(self$drop1)` ❌
- **After:** `h = self$drop1(h)` ✅

This is now fixed and matches the correct torch API.

