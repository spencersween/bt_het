# Heterogeneous Bradley-Terry Models with Torch and R

This repository provides a general implementation of heterogeneity-enriched Bradley–Terry models using structural deep neural networks in R and torch. The estimator’s form and statistical guarantees rely on the semiparametric results of Farrell, Liang, and Misra (2025), and extend the classical paired comparison model to settings with high-dimensional, context-dependent covariates. The methodology integrates tools from causal inference, structural econometrics, and machine learning to recover preference parameters that vary with observed features.

The framework delivers three core capabilities. First, it enables heterogeneity-aware structural modeling of pairwise choice behavior, allowing latent preference differences to depend on high-dimensional descriptors such as conversation embeddings in AI evaluation problems. Second, it provides a disciplined procedure for statistical inference on pairwise comparisons after controlling for covariates, using orthogonal influence functions and judge-aware *clustered* cross-fitting following Chiang et al. (2021). Third, it yields a basis for nonparametric interpretation: following Chernozhukov et al. (2022, 2025), orthogonal signals can be used for valid estimation of how preference surfaces vary across lower-dimensional representations of the inputs (e.g., topic probabilities derived from zero-shot classification). This functionality will be added to the codebase soon.

As an applied exercise, the repository implements the estimator on LMSYS Chatbot Arena rankings. This application demonstrates how the method recovers context-dependent performance profiles for language models, quantifies uncertainty in pairwise preference gaps, and provides a principled alternative to leaderboard metrics.

# Semiparametric Heterogeneous Bradley–Terry Estimator

---

## 1. Classical (Pooled) Bradley–Terry Model

Consider alternatives indexed by $k \in \{1,\ldots,K\}$, each with latent strength $\theta_k$. For a comparison between alternatives $j$ and $k$, the Bradley–Terry choice probability is

$$
\Pr(j \succ k)
= \frac{\exp(\theta_j)}{\exp(\theta_j) + \exp(\theta_k)}
= \Lambda(\theta_j - \theta_k),
\quad
\Lambda(u) = \frac{1}{1 + e^{-u}}.
$$

For each observation $i$, we observe:

- $Y_i \in \{0,1\}$: indicator for whether $j_i$ is preferred to $k_i$,
- the ordered pair $(j_i, k_i)$.

Define the contrast vector

$$
D_i = e_{j_i} - e_{k_i},
$$

so the pooled BT model is equivalent to

$$
\Pr(Y_i = 1 \mid D_i) = \Lambda(\theta^\top D_i).
$$

Identification is obtained by fixing one alternative’s strength or imposing $\sum_{k=1}^K \theta_k = 0$.

---

## 2. Heterogeneity-Enriched Bradley–Terry Model

To allow strengths to vary with prompt characteristics, we generalize the BT utilities to functions of covariates $X_i$:

$$
\lambda(X_i)
=
\big(\lambda_1(X_i),\ldots,\lambda_K(X_i)\big)^\top.
$$

The heterogeneous BT likelihood is then

$$
\Pr(Y_i = 1 \mid X_i, D_i)
=
\Lambda\big(D_i^\top \lambda(X_i)\big).
$$

This preserves the Bradley–Terry structure while allowing nonparametric dependence on $X_i$.

---

## 3. Structural Loss and Parameter Network

Define the negative log-likelihood contribution

$$
\ell_i(\lambda(X_i))
=
-
\Big[
Y_i \log \Lambda(D_i^\top \lambda(X_i))
+
(1 - Y_i)\log\big(1 - \Lambda(D_i^\top \lambda(X_i))\big)
\Big].
$$

We estimate $\lambda(\cdot)$ via a structural deep neural network:

$$
\hat{\lambda}
=
\arg\min_{\lambda \in \mathcal{F}}
\frac{1}{n}
\sum_{i=1}^n
\ell_i(\lambda(X_i)),
$$

where $\mathcal{F}$ is a class of neural networks that output $\lambda(X_i)$ and pass it through the BT index $D_i^\top \lambda(X_i)$.

We also estimate the conditional Hessian

$$
H(X_i)
=
\mathbb{E}\!\left[
\ell_{\lambda\lambda, i}(\lambda(X_i)) \mid X_i
\right],
$$

using a separate neural network. Both networks are trained with *clustered* cross-fitting to respect judge-level dependence (Chiang et al. 2021).

---

## 4. Target Parameter and Correct Orthogonal Signal

For alternative $k$, our estimand is the heterogeneous mean utility:

$$
\theta_k = \mathbb{E}[\lambda_k(X)].
$$

Let

- $s_i = \ell_{\lambda, i}(\lambda(X_i)) \in \mathbb{R}^K$ be the score,
- $H(X_i) \in \mathbb{R}^{K \times K}$ the conditional Hessian,
- $e_k$ the $k$-th standard basis vector.

The **Neyman-orthogonal signal** for $\theta_k$ is

$$
\psi_k(W_i; \eta)
=
\lambda_k(X_i)
+
e_k^\top H(X_i)^{-1} s_i,
\qquad
\eta = \{\lambda(\cdot), H(\cdot)\}.
$$

This matches the enriched influence-function structure of Farrell, Liang, and Misra (2025) and ensures robustness to first-stage estimation.

The correction term $e_k^\top H^{-1}s$ removes first-stage error and is the semiparametric analogue of the familiar parametric influence adjustment.

---

## 5. Cross-Fitted Estimator

With cross-fitted nuisance estimates $\hat{\lambda}$ and $\hat{H}$, the estimator is

$$
\hat{\theta}_k
=
\frac{1}{n}
\sum_{i=1}^n
\left[
\hat{\lambda}_k(X_i)
+
e_k^\top \hat{H}(X_i)^{-1} \hat{s}_i
\right],
$$

where $\hat{s}_i = \ell_{\lambda,i}(\hat{\lambda}(X_i))$.

This estimator is asymptotically linear and supports uniform confidence bands even under high-dimensional nuisance estimation.

---

## 6. Heterogeneity Analysis

Given $\hat{\lambda}(X)$ and orthogonal signals, we can recover heterogeneous performance across:

- embedding dimensions,
- topics,
- metadata/features,
- prompt characteristics.

For any low-dimensional representation $Z = g(X)$, we can estimate:

$$
\mathbb{E}[\lambda_k(X) \mid Z = s],
\quad
\mathbb{E}[\lambda_k(X) - \lambda_j(X) \mid Z = s],
$$

using nonparametric regression and the orthogonal-signal construction of Chernozhukov et al. (2022, 2025).

This enables interpretable preference surfaces and uncertainty-aware routing.

---

## 7. References

**Farrell, M., Liang, T., Misra, S. (2025).**  
*Deep Learning for Individual Heterogeneity.* arXiv:2010.14694.

**Chernozhukov, V., Newey, W., Singh, R. (2022).**  
*Automatic Debiased Machine Learning via Influence Functions.* arXiv:2112.13398.

**Chernozhukov, V., et al. (2025).**  
*Conditional and Functional Estimation via Neyman Orthogonal Scores.* Working paper.

**Chiang, H. D., Kato, K., Sasaki, Y. (2021).**  
*Cross-Fitting and Orthogonal Inference with Clustered Dependence.* arXiv:2104.06575.

## Codebase Overview

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

