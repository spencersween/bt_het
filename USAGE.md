# Usage Guide

## Step-by-Step Execution

### 1. Setup

First, ensure all required packages are installed (see README.md).

### 2. Configure Paths

Edit `config/config.R` to set your data file paths:

```r
PATH_PARQUET = "path/to/your/train.parquet"
PATH_PROCESSED1 = "path/to/your/processed1.csv"
PATH_PROCESSED2 = "path/to/your/processed2.csv"
```

Alternatively, modify the paths directly in `scripts/main.R`.

### 3. Run Main Analysis

```r
# Option 1: Source the script
source("scripts/main.R")

# Option 2: Run from command line
Rscript scripts/main.R
```

This executes:
1. Data loading and preprocessing
2. Classical Bradley-Terry model fitting
3. Feature preparation
4. Cross-fitting with neural networks
5. Saving results

### 4. Analyze Results

```r
source("analysis/analyze_results.R")
```

This creates visualizations and comparison tables.

## Customizing the Model

### Adjust Hyperparameters

Edit `config/config.R` or pass parameters directly to `train_crossfit()`:

```r
fit = train_crossfit(
  X = X, D = D, Y = Y, S = S,
  hidden_bt = c(256, 128),      # BT network architecture
  hidden_h = c(128, 64),        # Hessian network architecture
  lr_bt = 1e-3,                 # Learning rates
  lr_h = 1e-3,
  batch_size_bt = 2048,         # Batch sizes
  batch_size_h = 2048,
  max_epochs_bt = 200,          # Training epochs
  max_epochs_h = 200,
  patience_bt = 15,             # Early stopping
  patience_h = 15,
  ...
)
```

### Change Cross-Validation Folds

```r
S = create_folds(bt_df, nfolds = 5, seed = 123)  # 5-fold CV
```

### Use GPU

```r
device = if (cuda_is_available()) "cuda" else "cpu"
fit = train_crossfit(..., device = device)
```

## Working with Results

### Access OOF Predictions

```r
# Load results
load("results/crossfit_results.RData")

# Out-of-fold predictions
prob_oof = fit$oof_prob_stage1      # Probabilities
lambda_oof = fit$oof_lambda         # Coefficients lambda(X)
psi_oof = fit$oof_psi               # Debiased coefficients
Hbar = fit$oof_Hbar_cols            # Conditional Hessians
```

### Compare Models

```r
# Classical BT coefficients
lambda_classical = lambda

# Mean heterogeneous coefficients
lambda_hetero_mean = colMeans(psi_oof, na.rm = TRUE)

# Compare
comparison = data.frame(
  model = names(lambda_classical),
  classical = lambda_classical,
  heterogeneous = lambda_hetero_mean[names(lambda_classical)]
)
```

## Troubleshooting

### Memory Issues

- Reduce `batch_size_bt` and `batch_size_h`
- Process data in chunks
- Use smaller networks (reduce `hidden_bt` and `hidden_h`)

### Slow Training

- Use GPU: `device = "cuda"`
- Increase batch sizes (if memory allows)
- Reduce `max_epochs` for quick testing

### Convergence Issues

- Adjust learning rates (`lr_bt`, `lr_h`)
- Increase `patience` for early stopping
- Try different network architectures

