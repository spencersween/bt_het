# 02 --- Notation and Data Generating Process

> Canonical specification (File 2)

# Purpose

This document establishes the mathematical notation used throughout the
project. The goal is to define the sampling framework, observed
variables, latent utility objects, respondent indexing, and
parameterization before introducing the structural model.

------------------------------------------------------------------------

# Sampling Framework

Let

-   (i=1,`\ldots`{=tex},n) index respondents.
-   (t=0,`\ldots`{=tex},T) index repeated choice tasks.

The respondent is the independent sampling unit.

Repeated observations for a respondent form a short panel.

------------------------------------------------------------------------

# Observed Variables

For respondent (i):

-   (X_i): observed respondent characteristics.
-   (A_i`\in`{=tex}{B,C}): randomized survey arm.
-   (Q_i`\in`{=tex}{0,1}): randomized Product-2 treatment.
-   (D\_{it}): observed chosen alternative in task (t).

Task-specific Product-3 prices are observed and denoted

\[ P\^{(3)}\_{jt}, \]

where (j) indexes the Product-3 alternatives available in the
respondent's assigned arm.

Products 1 and 2 are displayed with price ranges. Under the maintained
model, respondents form latent perceived prices

\[ P\^{e}*{1}(X_i),`\qquad`{=tex} P\^{e}*{2}(X_i), \]

which are absorbed into normalized intercepts.

------------------------------------------------------------------------

# Choice Sets

Respondents never face the pooled menu.

Instead, the available alternatives depend on the assigned arm.

## Arm B

\[ `\mathcal `{=tex}C_B= { 1, 2, 3_0, 3_S, 3\_{SY} }. \]

## Arm C

\[ `\mathcal `{=tex}C_C= { 1, 2, 3_0, 3\_{SY}, 3\_{SYF} }. \]

The likelihood is always evaluated using the respondent-specific choice
set.

------------------------------------------------------------------------

# Structural Parameters

The heterogeneous structural parameter vector is

\[ `\theta`{=tex}(X)= ( `\tilde`{=tex}`\delta`{=tex}\_2,
`\tilde`{=tex}`\delta`{=tex}\_3, `\tau`{=tex}\_Q, `\kappa`{=tex}\_Q,
`\beta`{=tex}\_S, `\beta`{=tex}\_Y, `\beta`{=tex}\_F, `\gamma`{=tex}\_S,
`\gamma`{=tex}\_Y, `\gamma`{=tex}\_F, `\alpha`{=tex}, `\lambda`{=tex}
)(X). \]

Each component is allowed to be an unknown smooth function of (X).

A homogeneous specification is obtained by restricting every component
to be constant.

------------------------------------------------------------------------

# Utility Shocks

Let

\[ `\varepsilon`{=tex}\_{ijt} \]

denote the idiosyncratic utility shock for respondent (i), alternative
(j), and task (t).

The baseline nested-logit model assumes generalized extreme value (GEV)
errors consistent with a single Product-3 nest.

Across repeated tasks, shocks are assumed conditionally independent
given ((X_i,A_i,Q_i)) and the structural parameters.

------------------------------------------------------------------------

# Stable Preference Assumption

The deterministic component of utility does not change across repeated
tasks except through experimentally manipulated Product-3 prices.

Consequently,

-   structural tastes remain fixed,
-   only observed Product-3 prices vary over (t).

This assumption is central for identification of the Product-3 price
coefficient.

------------------------------------------------------------------------

# Target of Estimation

The object estimated by the FLM framework is the conditional structural
parameter function

\[ `\theta`{=tex}*0(x) = `\arg`{=tex}`\min`{=tex}*`\theta`{=tex}
`\mathbb `{=tex}E!`\left[
L(\theta;Z)
\mid X=x
\right]`{=tex}, \]

where (L) is the respondent-level negative log-likelihood derived in
later files.

The estimated parameter function is subsequently transformed into
economically meaningful functionals such as heterogeneous
willingness-to-pay.

------------------------------------------------------------------------

# Relationship to Later Files

This notation is used throughout the remaining specification:

-   File 3 introduces deterministic utility.
-   File 4 develops the heterogeneous model.
-   File 5 derives the nested-logit probabilities.
-   File 6 derives the repeated-choice likelihood.
-   File 7 establishes identification.
-   Files 8--10 develop FLM estimation and inference.
