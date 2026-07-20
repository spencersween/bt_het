# 08 --- Target Functionals and Willingness-to-Pay

> Canonical specification (File 8)

# Purpose

The structural model estimates conditional utility primitives. Most
scientific questions, however, concern economically meaningful
transformations of those primitives. This document defines the principal
target functionals used for estimation, reporting, and inference.

------------------------------------------------------------------------

# Structural Primitives

For respondent characteristics (X), the heterogeneous model estimates

-   entitlement utilities: \[
    `\beta`{=tex}\_S(X),;`\beta`{=tex}\_Y(X),;`\beta`{=tex}\_F(X), \]

-   Product-2 interaction effects: \[
    `\gamma`{=tex}\_S(X),;`\gamma`{=tex}\_Y(X),;`\gamma`{=tex}\_F(X), \]

-   Product-3 price sensitivity: \[ `\alpha`{=tex}(X)\>0. \]

These are latent utility parameters rather than directly interpretable
monetary values.

------------------------------------------------------------------------

# Willingness-to-Pay

Under quasi-linear utility, willingness-to-pay is obtained by dividing
utility increments by the marginal utility of money (the price
coefficient).

For entitlement (k`\in`{=tex}{S,Y,F}),

## Without Product-2 treatment

\[ WTP_k\^{(0)}(X) = `\frac{\beta_k(X)}{\alpha(X)}`{=tex}. \]

## With Product-2 treatment

\[ WTP_k\^{(1)}(X) = `\frac{\beta_k(X)+\gamma_k(X)}`{=tex}
{`\alpha`{=tex}(X)}. \]

------------------------------------------------------------------------

# Incremental Value of Treatment

The treatment-induced change in willingness-to-pay is

\[ `\Delta `{=tex}WTP_k(X) = WTP_k^{(1)}(X)-WTP_k^{(0)}(X) =
`\frac{\gamma_k(X)}`{=tex} {`\alpha`{=tex}(X)}. \]

These functions describe how Product-2 treatment changes the value
respondents place on Product-3 entitlements.

------------------------------------------------------------------------

# Population Targets

The primary population estimands are

\[ `\Psi`{=tex}\_k\^{(0)} = E!`\left[
\frac{\beta_k(X)}
{\alpha(X)}
\right]`{=tex}, \]

\[ `\Psi`{=tex}\_k\^{(1)} = E!`\left[
\frac{\beta_k(X)+\gamma_k(X)}
{\alpha(X)}
\right]`{=tex}, \]

and

\[ `\Delta`{=tex}`\Psi`{=tex}\_k = E!`\left[
\frac{\gamma_k(X)}
{\alpha(X)}
\right]`{=tex}. \]

These expectations are taken with respect to the respondent covariate
distribution.

------------------------------------------------------------------------

# Ratio-of-Expectations vs Expectation-of-Ratios

A key distinction is

\[ E!`\left[\frac{\beta(X)}{\alpha(X)}\right]`{=tex}`\neq`{=tex}
`\frac{E[\beta(X)]}{E[\alpha(X)]}`{=tex} \]

in general.

The scientific target is the expectation of respondent-level
willingness-to-pay, not the ratio of average coefficients.

This distinction motivates estimating heterogeneous structural
parameters before averaging.

------------------------------------------------------------------------

# Distributional Functionals

Beyond averages, the estimated parameter functions permit estimation of

-   empirical WTP distributions;
-   quantiles of WTP;
-   subgroup averages;
-   conditional average WTP given selected covariates;
-   partial dependence plots;
-   policy-relevant summaries under alternative respondent populations.

All of these are smooth functionals of the estimated structural
parameter functions.

------------------------------------------------------------------------

# Policy Interpretation

The heterogeneous WTP functions can be used to answer questions such as:

-   Which respondents value entitlement S the most?
-   How much additional value does Product-2 treatment generate?
-   How heterogeneous is price sensitivity?
-   Which entitlement bundles maximize consumer surplus for different
    respondent types?

These policy questions are downstream transformations of the estimated
structural primitives rather than additional model parameters.

------------------------------------------------------------------------

# Connection to FLM

The FLM framework estimates the conditional parameter function

\[ `\theta`{=tex}\_0(X). \]

Inference is then performed on smooth mappings

\[ `\Psi `{=tex}= T(`\theta`{=tex}\_0), \]

where (T(`\cdot`{=tex})) may denote average WTP, subgroup WTP, treatment
contrasts, or other differentiable functionals.

The following files derive estimation and asymptotic inference for these
targets using respondent-level losses, gradients, Hessians, and
influence functions.
