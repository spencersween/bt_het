# Heterogeneous Bradley-Terry Models with Torch and R

This repository provides a general implementation of heterogeneity-enriched Bradley Terry models using structural deep neural networks in R and torch. The estimator’s form and statistical guarantees rely on the semi-parametric results of Farrell, Liang, and Misra (2025), and extend the classical paired comparison model to settings with high-dimensional, context-dependent covariates. The methodology integrates tools from causal inference, structural econometrics, and machine learning to recover preference parameters that vary smoothly with observed features.

The framework delivers three core capabilities. First, it enables heterogeneity-aware structural modeling of pairwise choice behavior, allowing latent preference differences to depend on high-dimensional descriptors such as conversation embeddings in AI evaluation problems. Second, it provides a disciplined procedure for statistical inference on pairwise comparisons after controlling for covariates, using orthogonal influence functions and judge-aware clustered cross-fitting. Third, it yields a basis for model interpretability: following Chernozhukov et al. (2025), the influence function construction can be used for nonparametric estimation and inference on how preference surfaces vary across lower-dimensional representations of the inputs (for example, topic probabilities derived from zero-shot classification on the same embedding model used for input features). This functionality will be implemented in this codebase soon.

As an applied exercise, the repository implements the estimator on LMSYS Chatbot Arena rankings. This application demonstrates how the method recovers context-dependent performance profiles for language models, quantifies uncertainty in pairwise preference gaps, and provides an econometrically grounded alternative to ad hoc leaderboard metrics. The implementation offers a causal bridge between structural modeling and modern machine learning to support interpretable, data-driven assessments of AI model performance.

## Methodology

### Classical (Pooled) Bradley–Terry Model

The classical Bradley–Terry (BT) model provides a probabilistic structure for paired comparisons among alternatives indexed by $k \in \{1,\ldots,K\}$. Each alternative is associated with a latent strength parameter $\theta_k$. For a comparison between alternatives $j$ and $k$, the probability that $j$ is preferred is

$$
\Pr(j \succ k) = \frac{\exp(\theta_j)}{\exp(\theta_j) + \exp(\theta_k)} 
= \Lambda(\theta_j - \theta_k),
$$

where $\Lambda(\cdot)$ is the logistic link.

We estimate this model in **pooled logistic form**. For each observation $i = 1,\ldots,n$, we observe:

- $Y_i \in \{0,1\}$: indicator for whether alternative $j_i$ is preferred to $k_i$,
- $(j_i, k_i)$: indices of the two alternatives involved in observation $i$.

Define the $K$-dimensional contrast vector

$$
D_i = e_{j_i} - e_{k_i},
$$

where $e_{j}$ is the $j$th standard basis vector. The pooled BT model can be rewritten as a single logistic regression:

$$
\Pr(Y_i = 1 \mid D_i) = \Lambda(\theta^\top D_i),
$$

with $\theta = (\theta_1,\ldots,\theta_K)^\top$. Identification requires either (i) dropping one model indicator or (ii) imposing $\sum_{k=1}^K \theta_k = 0$.

In the Chatbot Arena application, the $\theta_k$ represent **global, context-invariant** preference strengths of each LLM. This homogeneity assumption is restrictive, and motivates the heterogeneous extension.

---

### Heterogeneity-Enriched Bradley–Terry Model

To allow performance to vary with question characteristics, we enrich the BT model by allowing the strength parameters to depend on observed covariates $X_i$ (e.g., text embeddings or metadata). Motivated by the structural deep learning framework of Farrell, Liang, and Misra (2025), we treat the structural parameters as flexible functions of $X_i$ while preserving the BT form and its economic interpretation.

For each alternative $k$, define a content-dependent utility

$$
U_k(X_i) = \lambda_k(X_i).
$$

Collect these into the vector

$$
\lambda(X_i) = (\lambda_1(X_i),\ldots,\lambda_K(X_i))^\top.
$$

The heterogeneous BT specification becomes

$$
\Pr(Y_i = 1 \mid X_i, D_i) = \Lambda\big(D_i^\top \lambda(X_i)\big).
$$

Thus, we maintain the **pooled structural form** of the BT model while replacing the fixed parameter vector $\theta$ with a **learned function** $\lambda(\cdot)$ mapping features to model-specific utilities.

This preserves the structural meaning of the Bradley–Terry model while allowing:

- rich, nonparametric dependence of performance on prompt characteristics,
- context-conditional pairwise comparisons,
- heterogeneity-aware model ranking and evaluation.

---

### Estimation via Structural Deep Learning and Orthogonal Influence Functions

Our estimator uses the structural semi-parametric framework of Farrell, Liang, and Misra (2025) to justify the form of the enrichment, the use of deep networks for nuisance components, and the construction of orthogonal influence functions for inference.

Denote the Bradley–Terry loss (negative log-likelihood contribution) by

$$
\ell_i(\lambda(X_i)) 
= -\Big[
Y_i \log\Lambda(D_i^\top \lambda(X_i)) 
+ (1 - Y_i)\log\big(1 - \Lambda(D_i^\top \lambda(X_i))\big)
\Big].
$$

The structural loss minimized by the BT network is

$$
\frac{1}{n} \sum_{i=1}^n \ell_i(\lambda(X_i)),
$$

which preserves the economic model rather than a generic predictive objective.

We estimate two nuisance components:

1. **BT Network (parameter network)**
   - Inputs: $X_i$  
   - Outputs: $\lambda(X_i)$  
   - Passes through $D_i^\top \lambda(X_i)$ and the logistic link.

2. **Hessian Network (conditional curvature)**
   - Approximates the conditional second derivative of the structural loss:
     $$
     H(X_i) = \mathbb{E}[\ell_{\lambda\lambda,i}(\lambda(X_i)) \mid X_i].
     $$
   - Required for the orthogonal influence function.

Both networks are trained via **judge-aware cross-fitting**: partitioning data so that all observations evaluated by the same judge remain in one fold, training on $K-1$ folds, and predicting on the held-out fold.

This ensures the orthogonality condition necessary for valid inference.

---

### Orthogonal Influence Function Estimation

Let the low-dimensional target parameter be a functional of $\lambda(\cdot)$, for example:

- mean heterogeneous utility for model $k$:
  $$
  \theta_k = \mathbb{E}[\lambda_k(X)],
  $$
- mean pairwise performance gap:
  $$
  \tau_{k,j} = \mathbb{E}[\lambda_k(X) - \lambda_j(X)].
  $$

Following Farrell–Liang–Misra, the orthogonal score takes the form:

$$
\psi(W_i; \theta, \eta) 
= \varphi(W_i; \eta) - \theta,
\qquad \eta = \{\lambda(\cdot), H(\cdot)\}.
$$

For the heterogeneous BT model, the orthogonal signal is

$$
\varphi(W_i; \eta) 
= \Gamma(X_i)^\top H(X_i)^{-1}s_i,
$$

where:

- $s_i$ is the score of the BT likelihood with respect to $\lambda(X_i)$,
- $H(X_i)$ is the conditional negative Hessian,
- $\Gamma(X_i)$ selects the target component (e.g. a unit vector for $\theta_k$).

The resulting estimator is

$$
\hat{\theta}
= \frac{1}{n} \sum_{i=1}^n 
\Gamma(X_i)^\top \hat{H}(X_i)^{-1} \hat{s}_i,
$$

which is asymptotically linear and supports standard confidence intervals even though the nuisance components are learned by deep neural networks.

---

### Nonparametric Heterogeneity Analysis

Following Chernozhukov et al. (2025), the orthogonal signal enables nonparametric analysis of how preference surfaces vary across **lower-dimensional representations** of $X_i$.

For example:

- embed each prompt using an LLM,
- obtain zero-shot topic probabilities $p_{\text{topic}}(X_i)$ from the same embedding model,
- estimate relationships such as
  $$
  \mathbb{E}[\lambda_k(X) \mid p_{\text{topic}}(X)=s],
  \quad
  \mathbb{E}[\lambda_k(X) - \lambda_j(X) \mid p_{\text{topic}}(X)=s],
  $$
  using nonparametric smoothing with influence-function-adjusted confidence bands.

This yields interpretable, statistically disciplined descriptions of how model performance varies across task domains (e.g., coding, math, reasoning, summarization).

---

### Routing and Policy Design

The estimated $\lambda_k(X)$ forms a structural utility index mapping from prompt features $X$ to model performance. This supports context-aware routing:

1. compute $\hat{\lambda}(X_{\text{new}})$,
2. optionally compute task probabilities $p_{\text{task}}(X_{\text{new}})$,
3. route to the alternative $k$ with highest predicted utility.

Because the entire inference pipeline is orthogonalized and cross-fitted, uncertainty-aware routing and robust comparison policies are feasible, offering a principled replacement for ad hoc leaderboard rankings.


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

