# Codebase Structure

This document provides an overview of how the original monolithic R script has been organized into a modular codebase.

## Original Script Sections → New File Organization

### Section 1: Data Loading & Preprocessing
**Original**: Lines 1-95
**New Files**:
- `data/extract_conversation.R` - Extract conversations from raw data
- `data/build_clean_data.R` - Build cleaned dataset
- `data/prepare_bt_data.R` - Prepare BT-specific data

### Section 2: Classical Bradley-Terry
**Original**: Lines 97-159
**New Files**:
- `utils/bt_classical.R` - Fit classical BT model, compute probabilities

### Section 3: Torch Neural Network Setup
**Original**: Lines 161-303
**New Files**:
- `models/datasets.R` - Torch dataset classes (bt_dataset, hessian_dataset)
- `models/bt_net.R` - Bradley-Terry neural network module
- `utils/bt_helpers.R` - Helper functions (compute_eta_vec, evaluate_loader, etc.)

### Section 4: Cross-fitting & Hessian Networks
**Original**: Lines 305-638
**New Files**:
- `models/hessian_net.R` - Hessian network module
- `utils/hessian_helpers.R` - Lower-triangular matrix utilities
- `R/train_bt_single.R` - Single BT network training
- `R/train_hessian_single.R` - Single Hessian network training
- `R/train_crossfit.R` - Main cross-fitting orchestration

### Section 5: Execution
**Original**: Lines 640-714
**New Files**:
- `scripts/main.R` - Main execution script
- `utils/prepare_features.R` - Feature matrix preparation
- `config/config.R` - Configuration settings

### Section 6-7: Analysis & Visualization
**Original**: Lines 716-839
**New Files**:
- `analysis/analyze_results.R` - Results analysis and plotting
- `utils/metrics.R` - Evaluation metrics (AUC, log loss)

## Function Dependencies

```
main.R
├── Data Processing
│   ├── extract_conversation() → extract_conversation.R
│   ├── build_clean_data() → build_clean_data.R
│   └── prepare_bt_data() → prepare_bt_data.R
│
├── Classical BT
│   ├── fit_classical_bt() → bt_classical.R
│   └── bt_prob() → bt_classical.R
│
├── Feature Preparation
│   ├── prepare_features() → prepare_features.R
│   └── create_folds() → prepare_features.R
│
└── Cross-fitting
    ├── train_crossfit() → train_crossfit.R
    │   ├── train_bt_single() → train_bt_single.R
    │   │   ├── bt_net → bt_net.R
    │   │   ├── make_loader() → datasets.R
    │   │   ├── compute_eta_vec() → bt_helpers.R
    │   │   ├── bce_logits_vec() → bt_helpers.R
    │   │   └── evaluate_loader() → bt_helpers.R
    │   │
    │   ├── predict_bt_full() → train_bt_single.R
    │   │
    │   ├── train_hessian_lower_single() → train_hessian_single.R
    │   │   ├── hessian_net_lower → hessian_net.R
    │   │   ├── make_hessian_loader() → datasets.R
    │   │   ├── build_lower_targets() → hessian_helpers.R
    │   │   └── evaluate_hessian_loader() → hessian_helpers.R
    │   │
    │   ├── predict_hessian_lower() → hessian_helpers.R
    │   ├── lower_tri_indices() → hessian_helpers.R
    │   └── lower_to_full() → hessian_helpers.R

analyze_results.R
├── auc_fast() → metrics.R
├── compute_logloss() → metrics.R
└── (uses fit object from main.R)
```

## Key Improvements

1. **Modularity**: Each function has a single responsibility
2. **Reusability**: Functions can be called independently
3. **Testability**: Individual functions can be tested in isolation
4. **Documentation**: Each function is documented with roxygen2-style comments
5. **Maintainability**: Related functionality is grouped together
6. **Configuration**: Hyperparameters centralized in `config/config.R`

## Adding New Features

### Adding a New Model
1. Create model module in `models/`
2. Add training function in `R/`
3. Update `train_crossfit()` if needed

### Adding a New Metric
1. Add function to `utils/metrics.R`
2. Update `analyze_results.R` to use it

### Adding Data Processing Step
1. Add function to `data/`
2. Update `scripts/main.R` to call it

