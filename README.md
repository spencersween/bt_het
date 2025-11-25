# Heterogeneous Bradley-Terry Models with Torch

This package implements heterogeneous Bradley-Terry models using neural networks for preference learning, with support for cross-fitting and influence function estimation.

## Overview

This codebase implements a two-stage approach to modeling heterogeneous preferences:

1. **Stage 1**: Neural network predicts model-specific coefficients λ(X) that vary with covariates X
2. **Stage 2**: Hessian network predicts conditional covariance structure for debiased inference

The implementation uses cross-fitting to ensure out-of-fold predictions and proper statistical inference.

## Structure

```
bt_het/
├── R/                    # Core R functions
│   ├── train_bt_single.R       # Single BT network training
│   ├── train_hessian_single.R  # Single Hessian network training
│   └── train_crossfit.R        # Cross-fitting orchestration
├── data/                 # Data processing functions
│   ├── extract_conversation.R  # Extract conversations from raw data
│   ├── build_clean_data.R      # Build cleaned dataset
│   └── prepare_bt_data.R       # Prepare BT-specific data
├── models/               # Neural network model definitions
│   ├── datasets.R              # Torch dataset classes
│   ├── bt_net.R                # Bradley-Terry network module
│   └── hessian_net.R           # Hessian network module
├── utils/                # Utility functions
│   ├── bt_classical.R          # Classical BT model fitting
│   ├── bt_helpers.R            # BT network helper functions
│   ├── hessian_helpers.R       # Hessian network helpers
│   ├── prepare_features.R      # Feature preparation
│   └── metrics.R               # Evaluation metrics
├── scripts/              # Execution scripts
│   └── main.R                  # Main execution script
├── analysis/             # Analysis and visualization
│   └── analyze_results.R       # Results analysis script
├── config/               # Configuration files
│   └── config.R               # Model hyperparameters
├── tests/                # Unit tests (to be added)
├── results/              # Output directory for results
├── plots/                # Output directory for plots
└── docs/                 # Additional documentation
```

## Installation

### Required R Packages

```r
# Core data manipulation
install.packages(c("dplyr", "purrr", "tidyr", "data.table"))

# Date/time processing
install.packages("lubridate")

# Data I/O
install.packages("arrow")

# Neural networks
install.packages("torch")
library(torch)
install_torch()  # Install PyTorch backend

# Async/iteration
install.packages("coro")

# Visualization
install.packages(c("ggplot2", "binsreg"))

# Statistical methods
install.packages("grf")

# Matrix operations
install.packages("MASS")
```

## Quick Start

### 1. Prepare Your Data

Place your data files in the expected locations (or update paths in `config/config.R`):
- Raw parquet file: `~/Downloads/train-00000-of-00001-cced8514c7ed782a.parquet`
- Processed CSV 1: `/Users/spencersween/Downloads/chatbot_processed.csv`
- Processed CSV 2: `/Users/spencersween/Downloads/chatbot_processed2.csv`

### 2. Run the Main Script

```r
source("scripts/main.R")
```

This will:
1. Load and preprocess the data
2. Fit a classical Bradley-Terry model for comparison
3. Prepare features for neural network training
4. Run cross-fitting with heterogeneous BT networks
5. Save results to `results/crossfit_results.RData`

### 3. Analyze Results

```r
source("analysis/analyze_results.R")
```

This will:
1. Plot training/validation loss curves
2. Compute out-of-fold metrics (AUC, log loss)
3. Compare heterogeneous vs. unconditional coefficients
4. Generate visualizations saved to `plots/` directory

## Configuration

Edit `config/config.R` to adjust:
- File paths
- Model hyperparameters (hidden layers, dropout, learning rates, etc.)
- Training parameters (batch size, epochs, patience)
- Number of cross-validation folds

## Key Functions

### Data Processing
- `extract_conversation()`: Extract question/response pairs from conversation data
- `build_clean_data()`: Build cleaned dataset from raw parquet
- `prepare_bt_data()`: Prepare data for Bradley-Terry modeling
- `prepare_features()`: Create feature matrices X, Y, D

### Classical Bradley-Terry
- `fit_classical_bt()`: Fit standard BT model with logistic regression
- `bt_prob()`: Compute probability that one model beats another

### Neural Network Training
- `train_bt_single()`: Train a single BT network
- `train_hessian_lower_single()`: Train a single Hessian network
- `train_crossfit()`: Orchestrate multi-fold cross-fitting

### Prediction & Evaluation
- `predict_bt_full()`: Get predictions from trained BT model
- `predict_hessian_lower()`: Get Hessian predictions
- `evaluate_loader()`: Evaluate model on data loader
- `auc_fast()`: Fast AUC computation

## Output

The main script produces:
- **Results**: `results/crossfit_results.RData` containing:
  - `fit`: Complete cross-fitting results with OOF predictions
  - `bt_classical`: Classical BT model results
  - `lambda`, `lambda_sorted`: Coefficient estimates
  - All input data (X, Y, D, P, J, S, bt_df)

The analysis script produces:
- **Plots**: Saved to `plots/` directory:
  - `training_history.png`: Loss curves by fold and stage
  - `lambda_density.png`: Distribution of heterogeneous coefficients
  - `binsreg_claude-v1.png`: Binsreg visualization
  - `tau_density_claude-v1.png`: Density comparison

## Notes

- The code uses `torch` package for R, which provides a Python PyTorch backend
- Ensure CUDA is available if using GPU (set `device = "cuda"` in config)
- Cross-fitting ensures proper statistical inference by using out-of-fold predictions
- The Hessian network predicts conditional covariance structure for debiasing

## Citation

If you use this code in your research, please cite appropriately.

## License

MIT License

