# 09 --- FLM Estimation

> Canonical specification (File 9)

# Purpose

This document describes how the structural nested-logit model is
estimated using the Farrell--Liang--Misra (FLM) structural deep learning
framework. The objective is **not** to estimate conditional choice
probabilities directly. Instead, the estimator learns the conditional
structural parameter vector that minimizes the expected respondent-level
negative log-likelihood.

------------------------------------------------------------------------

# Estimation Target

Let

\[ `\theta`{=tex}(X) = ( `\tilde`{=tex}`\delta`{=tex}\_2,
`\tilde`{=tex}`\delta`{=tex}\_3, `\tau`{=tex}\_Q, `\kappa`{=tex}\_Q,
`\beta`{=tex}\_S, `\beta`{=tex}\_Y, `\beta`{=tex}\_F, `\gamma`{=tex}\_S,
`\gamma`{=tex}\_Y, `\gamma`{=tex}\_F, `\alpha`{=tex}, `\lambda`{=tex}
)(X). \]

The target parameter function is

\[ `\theta`{=tex}*0(x) = `\arg`{=tex}`\min`{=tex}*{`\theta`{=tex}}
E!`\left[
L_i(\theta)
\mid
X=x
\right]`{=tex}, \]

where (L_i) denotes the respondent-level negative log-likelihood.

------------------------------------------------------------------------

# Respondent-Level Loss

For respondent (i),

\[ `\ell`{=tex}*i(`\theta`{=tex}) = `\sum`{=tex}*{t=0}\^{T} `\log`{=tex}
P(D\_{it}`\mid `{=tex}X_i;`\theta`{=tex}), \]

and

\[ L_i(`\theta`{=tex}) = -`\ell`{=tex}\_i(`\theta`{=tex}). \]

All repeated choice tasks contribute to the same respondent-level loss.

The respondent---not the task---is the independent observation for
optimization and inference.

------------------------------------------------------------------------

# Structural Neural Network

A neural network receives respondent covariates (X_i) as input and
outputs

\[ `\widehat{\theta}`{=tex}(X_i). \]

The network therefore predicts structural utility primitives rather than
probabilities.

Choice probabilities are obtained only after passing these parameter
estimates through the nested-logit model.

This preserves economic interpretability while allowing flexible
nonlinear heterogeneity.

------------------------------------------------------------------------

# Optimization Objective

The empirical objective is

\[ `\widehat{\theta}`{=tex} = `\arg`{=tex}`\min`{=tex}*{`\theta`{=tex}}
`\frac`{=tex}1n `\sum`{=tex}*{i=1}\^{n} L_i(`\theta`{=tex}). \]

Training proceeds with stochastic gradient methods applied to
respondent-level mini-batches.

Automatic differentiation computes gradients through the nested-logit
likelihood.

------------------------------------------------------------------------

# Parameter Constraints

Certain parameters should satisfy structural constraints.

Examples include

-   (`\alpha`{=tex}(X) \> 0) (positive marginal disutility of price),
-   (0 \< `\lambda`{=tex}(X) `\le 1`{=tex}) (nested-logit dissimilarity
    parameter).

These constraints may be imposed using suitable output transformations
(for example, exponential or logistic mappings) so that optimization
occurs over an unconstrained parameterization while respecting the
model's admissible parameter space.

------------------------------------------------------------------------

# Cross-Fitting

Cross-fitting should occur at the respondent level.

Recommended workflow:

1.  Split respondents into folds.
2.  Train the structural network on all but one fold.
3.  Predict structural parameters on the held-out fold.
4.  Repeat until every respondent has out-of-fold predictions.

This reduces overfitting and supports valid semiparametric inference on
downstream functionals.

------------------------------------------------------------------------

# Regularization

The flexibility of the network should be controlled through standard
machine-learning regularization, such as

-   weight decay,
-   early stopping,
-   validation monitoring,
-   architectural constraints.

Regularization acts on the conditional parameter functions, not on the
economic structure of the utility model itself.

------------------------------------------------------------------------

# Output of Estimation

The primary outputs are respondent-specific estimates of

\[ `\widehat{\theta}`{=tex}(X_i). \]

These estimated structural primitives are subsequently transformed into

-   heterogeneous willingness-to-pay,
-   average WTP,
-   treatment-induced WTP changes,
-   other smooth policy functionals.

The following document develops inference for these quantities using
gradients, Hessians, and influence-function methods within the FLM
framework.
