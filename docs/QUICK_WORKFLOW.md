# Quick Workflow Reference

## 🔄 Making Changes & Updating GitHub

```bash
cd /Users/spencersween/bt_het

# 1. Make your changes (edit files)

# 2. Check what changed
git status

# 3. Stage changes
git add .              # Or: git add path/to/file.R

# 4. Commit
git commit -m "Description of changes"

# 5. Push
git push
```

## 📊 Running Analysis

```r
# In R:
setwd("/Users/spencersween/bt_het")
source("R/zzz.R")
load_all()

# Run main pipeline (saves to results/)
source("scripts/main.R")

# Run analysis (creates plots/ and tables/)
source("analysis/analyze_results.R")
```

## 📁 Output Locations

- **Results:** `results/crossfit_results.RData`
- **Plots:** `plots/*.png`
- **Tables:** `tables/*.csv`

**Note:** These are ignored by git (won't be committed)

## ⚡ Common Commands

```bash
git status              # What changed?
git diff                # See changes
git add .               # Stage all
git commit -m "msg"     # Commit
git push                # Push to GitHub
git log --oneline -5    # Recent commits
```

See WORKFLOW.md for complete guide!
