# Live Plotting Guide

## Overview

The codebase now supports **live plotting** during training, which displays loss curves in real-time as your models train. This is similar to TensorBoard but works directly in R.

## Features

- ✅ **Live plot window** - Real-time loss curves that update during training
- ✅ **Automatic PNG saves** - Optionally saves plot snapshots to `plots/` directory
- ✅ **Works in RStudio/VS Code** - Plot window appears like `plot.png`
- ✅ **Both stages supported** - Works for BT network (Stage 1) and Hessian network (Stage 2)

## Usage

### Option 1: Enable in `train_crossfit()`

```r
# Enable live plotting for all training
fit = train_crossfit(
  X = X, D = D, Y = Y, S = S,
  # ... other parameters ...
  live_plot = TRUE  # ← Enable live plotting
)
```

This will:
- Show a plot window for each fold's Stage 1 training
- Show a plot window for each fold's Stage 2 training
- Save PNG files to `plots/training_live_stage1_fold*.png` and `plots/training_live_stage2_fold*.png`

### Option 2: Enable in individual training functions

```r
# For BT network only
bt_result = train_bt_single(
  X = X, D = D, Y = Y,
  train_idx = train_idx,
  val_idx = val_idx,
  # ... other parameters ...
  live_plot = TRUE,
  plot_file = "plots/my_training.png"  # Optional: custom file name
)

# For Hessian network only
h_result = train_hessian_lower_single(
  X = X, D = D,
  train_idx = train_idx,
  val_idx = val_idx,
  idx_lower = idx_lower,
  # ... other parameters ...
  live_plot = TRUE,
  plot_file = "plots/my_hessian_training.png"
)
```

### Option 3: Manual live plotting

```r
# Initialize plot
plot_env = init_live_plot(
  title = "My Training",
  device = "both",  # "window", "png", or "both"
  plot_file = "plots/my_plot.png"
)

# Update during training loop
for (epoch in 1:max_epochs) {
  # ... training code ...
  train_loss = # ... compute loss ...
  val_loss = # ... compute loss ...
  
  # Update plot
  update_live_plot(plot_env, epoch, train_loss, val_loss, max_epochs)
}

# Close when done
close_live_plot(plot_env)
```

## How It Works

1. **Plot Window**: When `interactive() == TRUE` (RStudio, VS Code R extension), opens a graphics window
2. **PNG Files**: Continuously saves/updates PNG file in `plots/` directory
3. **Updates**: Plot refreshes after each epoch with latest train/val loss

## Plot Display

The live plot shows:
- **Blue line**: Training loss over epochs
- **Red line**: Validation loss over epochs
- **X-axis**: Epoch number
- **Y-axis**: Loss value
- **Legend**: Shows which line is which

## File Outputs

When enabled, creates files like:
```
plots/
├── training_live_stage1_fold1.png    # Stage 1, fold 1
├── training_live_stage1_fold2.png    # Stage 1, fold 2
├── training_live_stage2_fold1.png    # Stage 2, fold 1
└── training_live_stage2_fold2.png    # Stage 2, fold 2
```

These are continuously updated during training, so you can watch progress even if the plot window isn't visible.

## Integration with RStudio/VS Code

- **RStudio**: Plot appears in "Plots" pane (bottom right)
- **VS Code**: Plot appears in viewer (similar to `plot.png`)
- **Non-interactive**: Only PNG files are saved (no window)

## Tips

1. **For long training**: Enable `live_plot = TRUE` to monitor progress
2. **For debugging**: Use live plots to catch training issues early
3. **PNG files**: Are saved even if window isn't visible - check `plots/` directory
4. **Multiple folds**: Each fold gets its own plot window/file

## Example: Full Pipeline with Live Plotting

```r
source("R/zzz.R")
load_all()

# Prepare data
# ... (data preparation code) ...

# Run with live plotting enabled
fit = train_crossfit(
  X = X, D = D, Y = Y, S = S,
  hidden_bt = c(256, 128),
  hidden_h = c(128, 64),
  # ... other hyperparameters ...
  live_plot = TRUE  # ← Watch training progress!
)

# After training, check plots/
list.files("plots/", pattern = "training_live")
```

## Troubleshooting

**Plot window doesn't appear:**
- Ensure you're in interactive R session (`interactive()` should return `TRUE`)
- Check if graphics device is available: `capabilities("png")`

**PNG files not updating:**
- Check write permissions for `plots/` directory
- Ensure `plots/` directory exists: `dir.create("plots", showWarnings = FALSE)`

**Too many plot windows:**
- Close old windows before starting new training
- Or disable live plotting for some stages: set `live_plot = FALSE` in specific calls

