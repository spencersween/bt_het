# Heterogeneous Bradley-Terry Models with Torch and R

This package implements semi-parametric estimation of Bradley-Terry models with heterogeneity-enriched preference parameters using structural deep neural networks in R and torch. The econometric framework builds on Farrell, Liang, and Misra (2025) and is applied here to analyze Chatbot Arena rankings. The approach supports nonparametric heterogeneity analysis in pairwise AI model comparisons, enabling interpretable assessment of model performance across different predicted conversation tasks and offering a foundation for data driven routing and model selection policies.

## Methodology

### Classical Bradley Terry Model

The classical Bradley Terry (BT) model provides a probabilistic structure for paired comparisons among items $m \in \{1,\dots,M\}$. Each item is associated with a latent strength parameter $\theta_m$. For a comparison between items $i$ and $j$, the probability that $i$ is preferred is:

$$
\Pr(i \succ j)
=
\frac{\exp(\theta_i)}{\exp(\theta_i) + \exp(\theta_j)}
=
\Lambda(\theta_i - \theta_j).
$$

Given observations $t = 1,\dots,T$:

- $Y_t$: outcome (1 if $i_t$ is chosen over $j_t$, else 0)  
- $i_t, j_t$: indices of compared models  

The log likelihood is:

$$
\ell(\theta)
=
\sum_{t=1}^T
\Big[
Y_t \log \Lambda(\theta_{i_t} - \theta_{j_t})
+
(1 - Y_t)\log(1 - \Lambda(\theta_{i_t} - \theta_{j_t}))
\Big].
$$

An identification constraint such as $\sum_m \theta_m = 0$ is typically imposed.

---

### Heterogeneity Enriched Bradley Terry Model

Model performance varies systematically across question types. To allow for this, BT parameters depend on question-level covariates $X_t$, such as embeddings or metadata.

Define a content dependent utility for model $m$:

$$
U_m(X_t) = \lambda_m(X_t).
$$

Then conditional BT probabilities are:

$$
\Pr(i \succ j \mid X_t)
=
\Lambda(\lambda_i(X_t) - \lambda_j(X_t)).
$$

With a contrast vector $D_t$:

$$
\Pr(Y_t = 1 \mid X_t, D_t)
=
\Lambda(D_t^\top \lambda(X_t)).
$$

This framework allows:

- conditional performance analysis across semantic dimensions  
- nonparametric links between question content and relative strength  
- granular evaluation beyond global BT rankings  

---

### Estimation via Structural Deep Learning and Orthogonal Influence Functions

The estimation strategy follows Farrell, Liang, and Misra (2025) to allow high-dimensional neural nets for nuisance components while preserving valid semiparametric inference on target parameters.

The pipeline includes:

1. **BT Network**  
   Learns heterogeneous parameters $\lambda(X)$.

2. **Hessian Network**  
   Learns the conditional Hessian $H(X)$ of the BT likelihood.

3. **Judge-Aware Cross Fitting**  
   Ensures out-of-fold predictions for all nuisance components.

---

### Cross Fitting

Data are partitioned into $K$ folds so that all observations from a given judge remain in a single fold.

For fold $k$:

- Train BT and Hessian networks on all data except fold $k$  
- Produce out-of-fold predictions $\hat{\lambda}^{(-k)}(X_t)$ and $\hat{H}^{(-k)}(X_t)$  

Stacking these yields full-sample out-of-fold nuisance predictions, required for Neyman orthogonality.

---

### Orthogonal Influence Function Estimation

Target parameters may include:

- average model strength:  
  $\theta_m = \mathbb{E}[\lambda_m(X)]$

- average pairwise performance gap:  
  $\tau_{m,n} = \mathbb{E}[\lambda_m(X) - \lambda_n(X)]$

An orthogonal score takes the form:

$$
\psi(W_t; \theta, \eta)
=
\varphi(W_t; \eta) - \theta,
$$

with $\eta = \{\lambda(\cdot), H(\cdot)\}$.

A suitable choice for generalized linear models is:

$$
\varphi(W_t; \eta)
=
\Gamma(X_t)^\top
H(X_t)^{-1}
s(W_t; \lambda(X_t)),
$$

where:

- $s(W_t; \lambda(X_t))$ is the logistic BT score  
- $H(X_t)$ is the conditional negative Hessian  
- $\Gamma(X_t)$ selects the target functional  

The debiased estimator is:

$$
\hat{\theta}
=
\frac{1}{T}
\sum_t
\Gamma(X_t)^\top
\hat{H}(X_t)^{-1}
\hat{s}(W_t).
$$

This estimator is asymptotically linear and supports classical inference.

---

### Heterogeneity Analysis

Using influence functions and out-of-fold $\hat{\lambda}(X)$, one can compute:

- binscatter plots of $\lambda_m(X)$  
- conditional pairwise gaps  
- valid standard errors for nonparametric regressions  

This avoids restrictive parametric assumptions.

---

### Zero Shot Topic Classification and Task Level Analysis

Given embeddings $X$, a model can compute topic probabilities, such as:

- math reasoning  
- coding  
- summarization  
- open ended QA  

Let $p_{\text{topic}}(X)$ denote such probabilities. Then analysts can examine:

$$
\mathbb{E}[\lambda_m(X) \mid p_{\text{topic}}(X) = s],
\quad
\mathbb{E}[\lambda_m(X) - \lambda_n(X) \mid p_{\text{topic}}(X) = s].
$$

This reveals how model performance varies across semantic task types.

---

### Routing and Policy Design

The estimated $\lambda_m(X)$ defines a mapping from question embeddings to predicted model performance. This enables routing strategies:

1. compute $\hat{\lambda}_m(X_{\text{new}})$  
2. compute topic probabilities $p_{\text{topic}}(X_{\text{new}})$  
3. route to the model with highest context specific predicted utility  

Influence function variance estimates allow uncertainty-aware routing.

---

## Overview

This codebase implements a two-stage approach:

1. **Stage 1**: Neural network predicts heterogeneous coefficients $\lambda(X)$  
2. **Stage 2**: Hessian network predicts conditional covariance for debiasing  

Cross-fitting ensures out-of-fold predictions for inference.

## Structure

