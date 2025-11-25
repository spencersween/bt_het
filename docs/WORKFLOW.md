# Complete Workflow Guide

## 🔄 Daily Workflow: Making Changes and Updating GitHub

### Part 1: Editing Functions/Scripts

#### Step 1: Make Your Changes
Edit any file you want:
- Functions in `R/`, `utils/`, `data/`, `models/`
- Scripts in `scripts/` or `analysis/`
- Configuration in `config/config.R`
- Documentation files

#### Step 2: Test Your Changes (Recommended)
```r
# In R console, test your changes
source("R/zzz.R")
load_all()  # Reload all functions

# Test your modified function
# ... run test code ...
```

#### Step 3: Stage Your Changes
```bash
cd /Users/spencersween/bt_het

# See what changed
git status

# Add specific files
git add path/to/file.R

# OR add all changes
git add .
```

#### Step 4: Commit Changes
```bash
# Commit with descriptive message
git commit -m "Description of what you changed

- Specific change 1
- Specific change 2
- Fixes bug X or adds feature Y"
```

#### Step 5: Push to GitHub
```bash
git push
```

**That's it!** Your changes are now on GitHub.

---

## 🖼️ Running Scripts and Organizing Outputs

### Part 2: Running Analysis Scripts

#### Before Running: Ensure Output Directories Exist

The `.gitignore` is set up to ignore output directories, but you need to create them if they don't exist:

```r
# Run this once in R
dir.create("results", showWarnings = FALSE)
dir.create("plots", showWarnings = FALSE)
dir.create("tables", showWarnings = FALSE)  # For tables if you add them
```

#### Running the Main Analysis Pipeline

```r
# 1. Set working directory
setwd("/Users/spencersween/bt_het")

# 2. Load all functions
source("R/zzz.R")
load_all()

# 3. Run main pipeline (this saves to results/)
source("scripts/main.R")
```

**Output:** `results/crossfit_results.RData`

#### Running the Analysis/Visualization Script

```r
# Make sure results exist first
if (!file.exists("results/crossfit_results.RData")) {
  stop("Run scripts/main.R first!")
}

# Run analysis script (this creates plots in plots/)
source("analysis/analyze_results.R")
```

**Outputs:**
- `plots/training_history.png`
- `plots/lambda_density.png`
- `plots/binsreg_claude-v1.png`
- `plots/tau_density_claude-v1.png`

#### Creating Custom Tables/Summaries

Add this to `analysis/analyze_results.R` or create a new script:

```r
# Example: Save coefficient comparison table
library(knitr)
library(kableExtra)

# Create comparison table
coef_table = coef_compare %>%
  kable(format = "latex", booktabs = TRUE) %>%
  kable_styling()

# Save to file
writeLines(coef_table, "tables/coefficient_comparison.tex")

# Or save as CSV
write.csv(coef_table, "tables/coefficient_comparison.csv", row.names = FALSE)

# Or save as markdown table
writeLines(knitr::kable(coef_compare, format = "markdown"), 
           "tables/coefficient_comparison.md")
```

---

## 📁 Organizing Results Properly

### Directory Structure for Outputs

```
bt_het/
├── results/              # Raw data outputs
│   ├── crossfit_results.RData
│   ├── classical_bt_results.RData
│   └── feature_matrices.RData
│
├── plots/                # All visualizations
│   ├── training_history.png
│   ├── lambda_density.png
│   ├── binsreg_*.png
│   └── comparisons/
│       └── model_comparison.png
│
└── tables/               # Formatted tables (create this)
    ├── coefficient_comparison.csv
    ├── coefficient_comparison.tex
    ├── metrics_summary.csv
    └── model_performance.tex
```

### Updating Scripts to Save to Proper Locations

#### Update `scripts/main.R` to save more outputs:

```r
# At the end of scripts/main.R, add:

# Save additional summaries
save(
  fit, bt_classical, lambda, lambda_sorted,
  X, Y, D, P, J, S, bt_df,
  # Add any additional objects you want
  file = "results/crossfit_results.RData"
)

# Optional: Save feature matrices separately
save(X, Y, D, P, file = "results/feature_matrices.RData")

cat("Results saved to results/crossfit_results.RData\n")
```

#### Update `analysis/analyze_results.R` to save tables:

Add this section at the end:

```r
############################################################
# 8. Save tables and summaries
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

# Save lambda means
lambda_summary = lambda_nn_df %>%
  left_join(lambda_uncond_df, by = "model") %>%
  arrange(desc(lambda_uncond))

write.csv(lambda_summary, 
          "tables/lambda_summary.csv", 
          row.names = FALSE)

cat("Tables saved to tables/ directory\n")
```

---

## 🔀 Complete Git Workflow Examples

### Example 1: Updating a Function

```bash
# 1. Make your changes in RStudio or editor
# Edit: utils/metrics.R

# 2. Check what changed
git status
git diff utils/metrics.R

# 3. Stage the change
git add utils/metrics.R

# 4. Commit
git commit -m "Add new metric function to utils/metrics.R

- Added compute_accuracy() function
- Improved auc_fast() documentation"

# 5. Push
git push
```

### Example 2: Fixing a Bug

```bash
# 1. Fix the bug in models/bt_net.R

# 2. Test it works
# (Run tests in R)

# 3. Commit
git add models/bt_net.R
git commit -m "Fix dropout bug in bt_net forward pass

- Changed h$dropout() to self$drop1(h)
- Fixes issue #X"

git push
```

### Example 3: Adding New Features

```bash
# 1. Add new file
# Created: utils/new_feature.R

# 2. Update main script to use it
# Modified: scripts/main.R

# 3. Add all changes
git add utils/new_feature.R scripts/main.R

# 4. Commit
git commit -m "Add new feature: XYZ functionality

- New utility function in utils/new_feature.R
- Integrated into main pipeline
- Updated documentation"

# 5. Push
git push
```

### Example 4: Multiple Changes at Once

```bash
# Made changes to several files

# See all changes
git status

# Add all changes
git add .

# Commit with detailed message
git commit -m "Major refactor: improve cross-fitting pipeline

- Refactored train_crossfit() for better error handling
- Added progress bars to training functions
- Updated documentation in README.md
- Fixed minor bugs in hessian_helpers.R"

git push
```

---

## 📊 Recommended Workflow for Running Analyses

### Standard Analysis Workflow

```r
# ============================================================
# STEP 1: Setup and Configuration
# ============================================================

# Set working directory
setwd("/Users/spencersween/bt_het")

# Load all functions
source("R/zzz.R")
load_all()

# Load required libraries
library(dplyr)
library(torch)
# ... etc

# Update configuration if needed
# (edit config/config.R or set variables directly)

# ============================================================
# STEP 2: Run Main Pipeline
# ============================================================

# This creates: results/crossfit_results.RData
source("scripts/main.R")

# ============================================================
# STEP 3: Run Analysis & Create Visualizations
# ============================================================

# This creates plots in plots/ directory
source("analysis/analyze_results.R")

# ============================================================
# STEP 4: Create Custom Tables (if needed)
# ============================================================

# Load results
load("results/crossfit_results.RData")

# Create custom analysis
# ... your custom code ...

# Save tables
dir.create("tables", showWarnings = FALSE)
write.csv(your_table, "tables/your_table.csv")
```

---

## 🚫 What NOT to Commit to GitHub

The `.gitignore` already handles this, but remember:

**DO NOT commit:**
- ✅ `results/*.RData` (already ignored)
- ✅ `plots/*.png` (already ignored)
- ✅ `tables/*.csv` (if you create tables/, add to .gitignore)
- ✅ Data files (`*.parquet`, `*.csv` in data/)
- ✅ `.RData`, `.Rhistory` files

**DO commit:**
- ✅ All `.R` source files
- ✅ `README.md` and documentation
- ✅ `config/config.R` (but consider if it has sensitive paths)
- ✅ `.gitignore`, `.Rbuildignore`

### To Add New Ignored Patterns

Edit `.gitignore`:

```bash
# Add to .gitignore
echo "tables/" >> .gitignore
echo "*.pdf" >> .gitignore  # If you create PDFs
```

---

## 🔄 Updating GitHub After Making Changes

### Quick Reference

```bash
cd /Users/spencersween/bt_het

# 1. See what changed
git status

# 2. See actual changes
git diff

# 3. Add changes
git add <file>          # Specific file
git add .               # All changes

# 4. Commit
git commit -m "Your message"

# 5. Push
git push

# 6. Verify on GitHub
# Go to: https://github.com/spencersween/bt_het
```

### Using Git Status Effectively

```bash
# See what files changed
git status

# See what changed in a file
git diff path/to/file.R

# See summary of changes
git diff --stat

# See commits
git log --oneline -5
```

---

## 📝 Best Practices

### 1. Commit Messages
- **Good:** "Fix dropout bug in hessian_net forward pass"
- **Bad:** "fix bug" or "update"

### 2. Frequent Commits
- Commit small, logical changes
- Don't wait until everything is perfect
- Each commit should be a complete, working state

### 3. Testing Before Committing
```r
# Quick test before committing
source("R/zzz.R")
load_all()
# Test your function
```

### 4. Branching (Optional, for larger changes)

```bash
# Create a branch for major changes
git checkout -b feature/new-feature

# Make changes, commit
git add .
git commit -m "Add new feature"

# Push branch
git push -u origin feature/new-feature

# Later, merge to main
git checkout main
git merge feature/new-feature
git push
```

---

## 🎯 Quick Command Cheat Sheet

```bash
# Daily workflow
git status              # What changed?
git add .               # Stage all changes
git commit -m "msg"     # Commit
git push                # Push to GitHub

# See changes
git diff                # See all changes
git diff file.R         # See changes in file
git log --oneline -10   # Recent commits

# Undo changes (if needed)
git checkout -- file.R  # Discard changes to file
git reset HEAD file.R   # Unstage file
```

---

## 🆘 Troubleshooting

### "Error: Your branch is behind 'origin/main'"

```bash
git pull                # Pull latest changes first
# Resolve any conflicts
git push
```

### "Error: Changes not staged for commit"

```bash
git add .               # Stage all changes first
git commit -m "msg"
git push
```

### "I committed the wrong thing"

```bash
# Undo last commit (keep changes)
git reset --soft HEAD~1

# Fix and recommit
git add .
git commit -m "Corrected commit message"
git push
```

---

## ✅ Checklist for Each Analysis Run

- [ ] Updated config if needed
- [ ] Ran `scripts/main.R` → saved to `results/`
- [ ] Ran `analysis/analyze_results.R` → created `plots/`
- [ ] Created tables if needed → saved to `tables/`
- [ ] Verified outputs in respective folders
- [ ] Committed code changes (not outputs) to GitHub
- [ ] Pushed to GitHub

---

**That's your complete workflow!** 🚀

