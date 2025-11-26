# Heterogeneous Bradley-Terry Models with Torch and R

This package implements semi-parametric estimation of Bradley-Terry models with heterogeneity-enriched preference parameters using structural deep neural networks in R and torch. The econometric framework builds on Farrell, Liang, and Misra (2025) and is applied here to analyze Chatbot Arena rankings. The approach supports nonparametric heterogeneity analysis in pairwise AI model comparisons, enabling interpretable assessment of model performance across different predicted conversation tasks and offering a foundation for data driven routing and model selection policies.

## Methodology

### Classical Bradley Terry Model

The classical Bradley Terry (BT) model provides a probabilistic structure for paired comparisons among items $m \in \{1,\ldots,M\}$. Each item is associated with a latent strength parameter $\theta_m$. For a comparison between items $i$ and $j$, the probability that $i$ is preferred is

$$
\Pr(i \succ j)
=
\frac{\exp(\theta_i)}{\exp(\theta_i) + \exp(\theta_j)}
=
\Lambda(\theta_i - \theta_j),
$$

where $\Lambda(\cdot)$ is the logistic function.

Given observations $t = 1,\ldots,T$, let:

- $Y_t$: outcome (1 if $i_t$ is chosen over $j_t$, else 0)
- $i_t, j_t$: indices of compared models

The log likelihood is

$$
\ell(\theta)
=
\sum_{t=1}^T
\left[
Y_t \log \Lambda(\theta_{i_t} - \theta_{j_t})
+
(1 - Y_t) \log(1 - \Lambda(\theta_{i_t} - \theta_{j_t}))
\right],
$$

with an identification constraint such as $\sum_m \theta_m = 0$.

In the Chatbot Arena context, each model’s $\theta_m$ represents its global strength, assumed constant across question types. This homogeneity assumption motivates the heterogeneous extension below.

---

### Heterogeneity Enriched Bradley Terry Model

Performance of large language models varies systematically across question types. To capture this, the BT parameters are allowed to depend on question level covariates $X_t$, such as prompt embeddings or metadata.

For each model $m$, define a content dependent utility

$$
U_m(X_t) = \lambda_m(X_t),
$$

estimated via a neural network. For a comparison between models \(i\) and \(j\):

$$
\Pr(i \succ j \mid X_t)
=
\Lambda\big(\lambda_i(X_t) - \lambda_j(X_t)\big).
$$

Equivalently, with a design contrast vector $D_t$:

$$
\Pr(Y_t = 1 \mid X_t, D_t)
=
\Lambda\left( D_t^\top \lambda(X_t) \right),
$$

where $\lambda(X_t)$ contains all model specific heterogeneous coefficients.

This framework enables:

- conditional performance evaluation across semantic dimensions,
- nonparametric relationships between question characteristics and model strengths,
- richer comparisons than global BT rankings.

The embeddings serve as structured covariates that index where in semantic space each question lies, allowing the model to learn how relative strengths evolve across question types.

---

### Estimation via Structural Deep Learning and Orthogonal Influence Functions

The estimation framework follows the structural deep learning template of Farrell, Liang, and Misra. The goal is valid semiparametric inference on low dimensional functionals while using flexible neural networks for high dimensional nuisance components.

The pipeline consists of:

1. **BT Network**  
   Learns heterogeneous parameters $\lambda(X)$ using a neural network with a logistic link.

2. **Hessian Network**  
   Learns the conditional Hessian $H(X)$, which captures second derivative curvature of the BT log likelihood.

3. **Cross Fitting (Judge Aware)**  
   Ensures out of fold predictions for both networks, enabling valid orthogonal moment conditions.

---

### Cross Fitting

Data are partitioned into $K$ folds such that all comparisons judged by the same individual remain within a single fold.

For each fold $k$:

- train BT and Hessian networks on all data except fold $k$,
- generate out of fold predictions $\hat{\lambda}^{(-k)}(X_t)$ and $\hat{H}^{(-k)}(X_t)$ for all observations in fold $k$.

Stacking across folds yields entire sample out of fold nuisance estimates.

This procedure is essential because Neyman orthogonality requires that nuisance evaluations are computed on data not used for training the nuisance models.

---

### Orthogonal Influence Function Estimation

Suppose the target parameter $\theta$ is a functional of the heterogeneous coefficients, for example:

- average model strength:  
  $\theta_m = \mathbb{E}[\lambda_m(X)]$,

- average pairwise gap:  
  $\tau_{m,n} = \mathbb{E}[\lambda_m(X) - \lambda_n(X)]$.

An orthogonal score takes the form

$$
\psi(W_t; \theta, \eta)
=
\varphi(W_t; \eta) - \theta,
$$

with nuisance functions $\eta = \{\lambda(\cdot), H(\cdot)\}$.

For generalized linear models, a convenient choice is

$$
\varphi(W_t; \eta)
=
\Gamma(X_t)^\top
H(X_t)^{-1}
s(W_t; \lambda(X_t)),
$$

where:

- $s(W_t; \lambda(X_t))$ is the score of the logistic BT likelihood,
- $H(X_t)$ is the conditional negative Hessian,
- $\Gamma(X_t)$ selects the component of interest.

The debiased estimator is

$$
\hat{\theta}
=
\frac{1}{T}
\sum_t
\Gamma(X_t)^\top
\hat{H}(X_t)^{-1}
\hat{s}(W_t).
$$

This estimator is asymptotically linear with valid variance formulas even when neural networks are used for nuisance estimation.

---

### Heterogeneity Analysis

The influence function output enables nonparametric or semiparametric analysis of model performance across the question embedding space.

Analysts can compute:

- binscatter plots of $\lambda_m(X)$ against semantic features,
- conditional performance gaps across different regions of the embedding space,
- standard errors derived from influence functions.

This avoids imposing restrictive parametric structures on performance heterogeneity.

---

### Zero Shot Topic Classification and Task Level Analysis

Because $X$ includes embedding vectors, a source model can provide topic probabilities such as:

- math/reasoning,
- code generation,
- summarization/editing,
- open ended QA.

Let $p_{\text{topic}}(X)$ denote such topic probabilities. One can examine:

$$
\mathbb{E}[\lambda_m(X) \mid p_{\text{topic}}(X) = s],
\qquad
\mathbb{E}[\lambda_m(X) - \lambda_n(X) \mid p_{\text{topic}}(X) = s].
$$

This provides interpretable insights into how LLMs perform across semantic tasks and user needs.

---

### Routing and Policy Design

The heterogeneous BT coefficients define a mapping from question embeddings to predicted model utility. This enables routing strategies:

1. compute $\hat{\lambda}_m(X_{\text{new}})$ for a new query,
2. compute topic probabilities $p_{\text{topic}}(X_{\text{new}})$,
3. route to the model with the highest predicted context specific utility.

Influence function based uncertainty quantification allows:

- uncertainty aware routing,
- interpretable selection rules,
- improved efficiency over static global rankings,
- better deployments that align with user question types.

---

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

