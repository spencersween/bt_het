# 10 --- FLM Inference

> Canonical specification (File 10)

# Purpose

This document describes the inferential framework for the heterogeneous
structural parameter functions and the downstream willingness-to-pay
(WTP) functionals estimated using the Farrell--Liang--Misra (FLM)
framework.

------------------------------------------------------------------------

# Inferential Philosophy

The neural network estimates the conditional structural parameter
function

\[ `\theta`{=tex}\_0(X). \]

Scientific inference is not performed directly on network weights.
Instead, inference targets smooth functionals of the estimated
structural parameter functions.

Examples include

-   average WTP,
-   treatment-specific WTP,
-   heterogeneous WTP,
-   subgroup averages,
-   policy counterfactuals.

------------------------------------------------------------------------

# Respondent-Level Estimating Objects

Inference is based on respondent-level losses.

For respondent (i),

\[ L_i(`\theta`{=tex}) = -`\ell`{=tex}\_i(`\theta`{=tex}), \]

where (`\ell`{=tex}\_i) is the respondent log-likelihood constructed by
summing over repeated tasks.

Repeated observations are not treated as independent sampling units.

------------------------------------------------------------------------

# Score Function

Let

\[ s_i(`\theta`{=tex}) =
`\nabla`{=tex}\_`\theta `{=tex}L_i(`\theta`{=tex}) \]

denote the respondent-level score vector.

The first-order condition defining the population target is

\[ E\[s_i(`\theta`{=tex}\_0)`\mid `{=tex}X=x\]=0. \]

Automatic differentiation can be used to evaluate the score during
estimation.

------------------------------------------------------------------------

# Hessian

Define the respondent-level Hessian

\[ H_i(`\theta`{=tex}) = `\nabla`{=tex}\_`\theta`{=tex}\^2
L_i(`\theta`{=tex}). \]

The conditional expected Hessian,

\[ H(x) = E\[H_i(`\theta`{=tex}\_0)`\mid `{=tex}X=x\], \]

governs the local curvature of the optimization problem and plays a
central role in influence-function calculations.

------------------------------------------------------------------------

# Smooth Functionals

Let

\[ `\Psi`{=tex}=T(`\theta`{=tex}\_0) \]

denote a differentiable functional of the structural parameter function.

Examples include

\[ E!`\left[\frac{\beta_S(X)}{\alpha(X)}\right]`{=tex}, \]

\[ E!`\left[\frac{\beta_S(X)+\gamma_S(X)}{\alpha(X)}\right]`{=tex}, \]

and analogous quantities for other entitlements.

The functional map (T(`\cdot`{=tex})) may represent averages, subgroup
means, quantiles (where appropriate), or other policy summaries.

------------------------------------------------------------------------

# Influence Functions

Under the regularity conditions of the FLM framework, smooth functionals
admit linear influence-function representations of the form

\[
`\sqrt{n}`{=tex}`\left`{=tex}(`\widehat{\Psi}`{=tex}-`\Psi`{=tex}*0`\right`{=tex})
= `\frac1{\sqrt n}`{=tex} `\sum`{=tex}*{i=1}\^n `\varphi`{=tex}\_i +
o_p(1), \]

where (`\varphi`{=tex}\_i) is the respondent-level influence function.

Influence functions are evaluated at the respondent level because
respondents---not repeated tasks---are independently sampled.

------------------------------------------------------------------------

# Variance Estimation

Estimated asymptotic variances may be obtained from the empirical
variance of the estimated respondent-level influence functions,

\[ `\widehat{\mathrm{Var}}`{=tex}(`\widehat{\Psi}`{=tex}) =
`\frac`{=tex}1n `\sum`{=tex}\_{i=1}\^n `\widehat{\varphi}`{=tex}\_i\^2.
\]

This yields asymptotically valid standard errors for smooth WTP
functionals under the maintained assumptions.

------------------------------------------------------------------------

# Bootstrap

A respondent-level bootstrap provides an alternative finite-sample
inference procedure.

Bootstrap samples should resample respondents, carrying along all
repeated tasks for each sampled respondent.

Repeated tasks should never be resampled independently.

------------------------------------------------------------------------

# Confidence Intervals

Once standard errors are obtained, confidence intervals may be
constructed using either

-   asymptotic normal approximations based on the influence function, or
-   respondent-level bootstrap percentiles or bootstrap-t procedures.

The appropriate choice depends on finite-sample performance and
computational considerations.

------------------------------------------------------------------------

# Outputs

The inferential outputs include

-   point estimates,
-   standard errors,
-   confidence intervals,
-   hypothesis tests,
-   subgroup comparisons,
-   uncertainty bands for heterogeneous WTP functions,
-   uncertainty for any smooth policy functional derived from the
    estimated structural parameter functions.

The next document will focus on practical implementation guidance,
software architecture, estimation workflow, diagnostics, and robustness
analyses.
