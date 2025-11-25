# Complete Guide: Where Everything Is & What To Do

## ✅ What Was Fixed

**File:** `models/hessian_net.R`

**Issue:** Dropout layers were called incorrectly in the forward pass
- **Wrong:** `h = h$dropout(self$drop1)` 
- **Fixed:** `h = self$drop1(h)`

This now correctly uses the torch API for dropout layers.

---

## 📍 WHERE EVERYTHING IS

### Main Entry Points (Start Here!)

1. **`scripts/main.R`** ← **RUN THIS FIRST**
   - Complete pipeline from data loading to saving results
   - Loads data → fits models → saves to `results/`

2. **`analysis/analyze_results.R`** ← **RUN THIS SECOND**
   - Analyzes saved results
   - Creates plots in `plots/` directory

### Configuration

3. **`config/config.R`**
   - **EDIT THIS** to set your file paths and hyperparameters
   - All model settings (learning rates, batch sizes, etc.)

### Core Functions

#### Data Processing (`data/`)
- **`extract_conversation.R`** - Extracts question/response from conversations
- **`build_clean_data.R`** - Builds cleaned dataset from raw parquet
- **`prepare_bt_data.R`** - Prepares data for Bradley-Terry modeling

#### Models (`models/`)
- **`datasets.R`** - Torch dataset classes for batching
- **`bt_net.R`** - Bradley-Terry neural network definition
- **`hessian_net.R`** - Hessian network definition (✓ FIXED)

#### Training (`R/`)
- **`train_bt_single.R`** - Trains a single BT network
- **`train_hessian_single.R`** - Trains a single Hessian network
- **`train_crossfit.R`** - **Main training orchestrator** (does cross-fitting)

#### Utilities (`utils/`)
- **`bt_classical.R`** - Classical BT logistic regression
- **`bt_helpers.R`** - Helper functions for BT networks
- **`hessian_helpers.R`** - Helper functions for Hessian operations
- **`prepare_features.R`** - Builds feature matrices (X, Y, D)
- **`metrics.R`** - Evaluation metrics (AUC, log loss)

#### Helpers (`R/zzz.R`)
- **`load_all()`** - Convenience function to source all R files

### Output Directories

- **`results/`** - Saved results (`.RData` files)
- **`plots/`** - Generated plots (`.png` files)

---

## 🎯 WHAT TO DO (Step by Step)

### Step 1: Setup (One Time)

1. **Install R packages:**
   ```r
   install.packages(c("dplyr", "purrr", "lubridate", "arrow", "torch", 
                      "coro", "ggplot2", "tidyr", "data.table", 
                      "binsreg", "grf", "MASS"))
   
   library(torch)
   install_torch()  # Install PyTorch backend
   ```

2. **Set your data paths:**
   - Open `config/config.R`
   - Edit these lines:
     ```r
     PATH_PARQUET = "path/to/your/train.parquet"
     PATH_PROCESSED1 = "path/to/your/processed1.csv"
     PATH_PROCESSED2 = "path/to/your/processed2.csv"
     ```
   - OR edit paths directly in `scripts/main.R` (lines 20-22)

### Step 2: Run the Analysis

**Option A: From R Console/RStudio**
```r
# Set working directory to bt_het folder
setwd("/Users/spencersween/bt_het")

# Run main pipeline
source("scripts/main.R")

# Analyze results
source("analysis/analyze_results.R")
```

**Option B: From Command Line**
```bash
cd /Users/spencersween/bt_het
Rscript scripts/main.R
Rscript analysis/analyze_results.R
```

### Step 3: Review Results

**Check output files:**
- `results/crossfit_results.RData` - All results saved here
- `plots/training_history.png` - Loss curves
- `plots/lambda_density.png` - Coefficient distributions
- `plots/binsreg_*.png` - Binsreg visualizations

**Load and explore results:**
```r
load("results/crossfit_results.RData")

# Out-of-fold predictions
prob_oof = fit$oof_prob_stage1
lambda_oof = fit$oof_lambda
psi_oof = fit$oof_psi

# Classical BT coefficients
lambda_classical = lambda

# Compare
colMeans(psi_oof, na.rm = TRUE)  # Mean heterogeneous coefficients
```

---

## 🔍 FUNCTION INDEX (What Does What?)

### Data Loading & Processing
| Function | File | Purpose |
|----------|------|---------|
| `extract_conversation()` | `data/extract_conversation.R` | Extract Q&A from conversation object |
| `build_clean_data()` | `data/build_clean_data.R` | Clean raw parquet → clean dataframe |
| `prepare_bt_data()` | `data/prepare_bt_data.R` | Filter and prepare BT data |
| `prepare_features()` | `utils/prepare_features.R` | Build X, Y, D feature matrices |
| `create_folds()` | `utils/prepare_features.R` | Create cross-validation folds |

### Model Fitting
| Function | File | Purpose |
|----------|------|---------|
| `fit_classical_bt()` | `utils/bt_classical.R` | Fit classical BT with logistic regression |
| `bt_prob()` | `utils/bt_classical.R` | Compute P(model_i beats model_j) |
| `train_crossfit()` | `R/train_crossfit.R` | **Main function** - cross-fitting pipeline |
| `train_bt_single()` | `R/train_bt_single.R` | Train single BT network |
| `train_hessian_lower_single()` | `R/train_hessian_single.R` | Train single Hessian network |

### Prediction
| Function | File | Purpose |
|----------|------|---------|
| `predict_bt_full()` | `R/train_bt_single.R` | Get predictions from BT model |
| `predict_hessian_lower()` | `utils/hessian_helpers.R` | Get Hessian predictions |
| `predict_loader_prob()` | `utils/bt_helpers.R` | Predict probabilities from loader |
| `predict_loader_lambda()` | `utils/bt_helpers.R` | Predict lambdas from loader |

### Evaluation
| Function | File | Purpose |
|----------|------|---------|
| `evaluate_loader()` | `utils/bt_helpers.R` | Evaluate BT model |
| `evaluate_hessian_loader()` | `utils/hessian_helpers.R` | Evaluate Hessian model |
| `auc_fast()` | `utils/metrics.R` | Fast AUC computation |
| `compute_logloss()` | `utils/metrics.R` | Log loss metric |

### Hessian Utilities
| Function | File | Purpose |
|----------|------|---------|
| `lower_tri_indices()` | `utils/hessian_helpers.R` | Get lower triangular indices |
| `build_lower_targets()` | `utils/hessian_helpers.R` | Build Hessian target matrix |
| `lower_to_full()` | `utils/hessian_helpers.R` | Convert lower-tri to full matrix |

---

## 🛠️ CUSTOMIZATION GUIDE

### Change Model Architecture

Edit `config/config.R`:
```r
HIDDEN_BT = c(256, 128)      # BT network: 2 hidden layers (256, 128)
HIDDEN_H = c(128, 64)        # Hessian network: 2 hidden layers (128, 64)
DROPOUT_BT = 0.1             # 10% dropout
USE_BATCHNORM_BT = FALSE     # No batch normalization
```

### Change Training Settings

```r
LR_BT = 1e-3                 # Learning rate for BT network
BATCH_SIZE_BT = 2048         # Batch size
MAX_EPOCHS_BT = 200          # Max training epochs
PATIENCE_BT = 15             # Early stopping patience
```

### Change Cross-Validation

In `scripts/main.R`, find:
```r
S = create_folds(bt_df, nfolds = 2, seed = 123)
```

Change to:
```r
S = create_folds(bt_df, nfolds = 5, seed = 123)  # 5-fold CV
```

### Use GPU

In `config/config.R` or `scripts/main.R`:
```r
device = if (cuda_is_available()) "cuda" else "cpu"
```

---

## 📊 UNDERSTANDING THE OUTPUT

### What is `fit$oof_prob_stage1`?
- Out-of-fold predicted probabilities P(Y=1 | X)
- Each prediction uses model trained on other folds
- Used for evaluation

### What is `fit$oof_lambda`?
- Out-of-fold predicted coefficients λ(X)
- Heterogeneous: varies with covariates X
- Shape: (n_observations × n_models)

### What is `fit$oof_psi`?
- Debiased coefficients ψ = λ(X) - H⁻¹J
- Uses influence function correction
- Better for inference than raw λ(X)

### What is `fit$oof_Hbar_cols`?
- Conditional Hessian matrices H(X)
- Shape: (n_observations × n_models × n_models)
- Used for debiasing in ψ computation

---

## 🚨 COMMON ISSUES & SOLUTIONS

### "Error: cannot open file..."
**Solution:** Check file paths in `config/config.R` or `scripts/main.R`

### "Out of memory"
**Solution:** 
- Reduce `BATCH_SIZE_BT` and `BATCH_SIZE_H` in config
- Use smaller networks (fewer hidden units)
- Process in chunks

### "Training very slow"
**Solution:**
- Use GPU: `device = "cuda"`
- Increase batch sizes (if memory allows)
- Reduce `MAX_EPOCHS_*` for testing

### "Model not converging"
**Solution:**
- Adjust learning rates (`LR_BT`, `LR_H`)
- Increase `PATIENCE_*` for early stopping
- Try different architectures

### "Error in dropout"
**Solution:** Already fixed! Use the updated `hessian_net.R`

---

## 📚 ADDITIONAL DOCUMENTATION

- **`README.md`** - Full package documentation
- **`USAGE.md`** - Detailed usage instructions
- **`STRUCTURE.md`** - Code organization explanation
- **`QUICK_START.md`** - Quick reference guide
- **`COMPLETE_GUIDE.md`** - This file!

---

## 🎓 SUMMARY

1. **Fixed:** `models/hessian_net.R` - Dropout calls corrected
2. **Run:** `scripts/main.R` - Main pipeline
3. **Analyze:** `analysis/analyze_results.R` - Results analysis
4. **Configure:** `config/config.R` - Settings and paths
5. **Output:** `results/` and `plots/` directories

**That's it! You're ready to run your heterogeneous Bradley-Terry analysis.** 🚀

