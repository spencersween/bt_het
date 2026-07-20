# 11 --- Implementation Architecture and Estimation Workflow

> Canonical specification (File 11)

# Purpose

This document translates the econometric specification into a concrete
software architecture. It is intended to guide implementation while
preserving the structural interpretation of the model.

------------------------------------------------------------------------

# Recommended Repository Layout

``` text
project/
  data/
    raw/
    processed/
  configs/
  models/
    utilities.py
    nested_logit.py
    network.py
  losses/
    respondent_loss.py
  train/
    train.py
    crossfit.py
  inference/
    scores.py
    hessian.py
    influence.py
    bootstrap.py
  diagnostics/
  experiments/
  notebooks/
```

------------------------------------------------------------------------

# Data Pipeline

Each row of the processed dataset should correspond to a respondent-task
pair.

Minimum fields include:

-   respondent_id
-   task_id
-   survey_arm
-   Q
-   chosen_alternative
-   respondent covariates (X)
-   Product-3 prices for every displayed configuration

Training batches should always preserve respondent membership so
repeated tasks can be aggregated into respondent-level losses.

------------------------------------------------------------------------

# Model Components

## Feature Network

Input:

\[ X_i \]

Output:

\[ `\widehat{\theta}`{=tex}(X_i). \]

The network predicts only structural parameters.

------------------------------------------------------------------------

## Utility Layer

Construct deterministic utilities using the equations from Files 3--4.

The utility layer should be deterministic and differentiable.

------------------------------------------------------------------------

## Nested-Logit Layer

Compute

1.  lower-level probabilities;
2.  inclusive values;
3.  upper-level probabilities;
4.  overall choice probabilities.

This layer contains no trainable parameters beyond the structural
primitives supplied by the network.

------------------------------------------------------------------------

## Respondent Loss

Aggregate task log-likelihoods

\[ `\ell`{=tex}\_i = `\sum`{=tex}*t `\log `{=tex}P(D*{it}). \]

Optimize the negative respondent log-likelihood.

------------------------------------------------------------------------

# Training Workflow

1.  Load processed data.
2.  Split respondents into cross-fitting folds.
3.  Initialize network.
4.  Predict structural parameters.
5.  Build utilities.
6.  Evaluate nested-logit probabilities.
7.  Compute respondent losses.
8.  Backpropagate.
9.  Update parameters.
10. Monitor validation loss.
11. Save checkpoints.
12. Repeat until convergence.

------------------------------------------------------------------------

# Diagnostics

Monitor:

-   training loss;
-   validation loss;
-   gradient norms;
-   parameter distributions;
-   estimated price coefficients;
-   estimated nesting parameters;
-   respondent-level log-likelihood.

Investigate instability if:

-   (`\lambda`{=tex}) approaches boundaries;
-   price sensitivity approaches zero;
-   optimization stalls.

------------------------------------------------------------------------

# Identification Diagnostics

Recommended empirical checks include:

-   entitlement effect recovery;
-   stability across folds;
-   bootstrap distributions;
-   profile likelihoods for the nesting parameter;
-   sensitivity to network architecture;
-   sensitivity to regularization.

------------------------------------------------------------------------

# Outputs

Primary outputs:

-   respondent-level structural parameters;
-   respondent-level WTP;
-   average WTP;
-   confidence intervals;
-   fitted choice probabilities;
-   diagnostics and convergence summaries.

This implementation should separate the economic model from the
machine-learning architecture so that alternative estimators can reuse
the same structural likelihood.
