# 07 --- Identification

> Canonical specification (File 7)

# Purpose

This document explains how each structural parameter is identified by
the experimental design. Throughout, identification refers to the
population model under the maintained assumptions introduced in previous
files.

------------------------------------------------------------------------

# Identification Strategy

The experiment combines three independent sources of variation:

1.  Random assignment to survey arm (B vs. C).
2.  Random assignment of the Product-2 treatment (Q).
3.  Repeated common price shifts for the Product-3 family.

The identifying content of each source differs. Some parameters are
identified entirely from cross-sectional variation, while others require
the repeated-choice panel.

------------------------------------------------------------------------

# Utility Normalization

Because utilities are only identified up to an additive constant,
normalize

\[ V_1 = 0. \]

Consequently, only utilities relative to Product 1 are identified. The
intercepts (`\tilde`{=tex}`\delta`{=tex}\_2) and
(`\tilde`{=tex}`\delta`{=tex}\_3) are interpreted as relative utilities.

------------------------------------------------------------------------

# Relative Intercepts

The displayed prices for Products 1 and 2 are ranges rather than fixed
scalar prices. Under the maintained model, respondent-specific perceived
prices are absorbed into the relative intercepts.

Therefore the primitives

-   Product-1 intercept,
-   Product-2 intercept,
-   perceived Product-1 price,
-   perceived Product-2 price,

are not separately identified.

Instead, the identified objects are the normalized intercept functions

\[ `\tilde`{=tex}`\delta`{=tex}\_2(X),`\qquad`{=tex}
`\tilde`{=tex}`\delta`{=tex}\_3(X). \]

------------------------------------------------------------------------

# Entitlement Effects

## Effect of S

Arm B contains

-   baseline,
-   S.  

The contrast between these alternatives identifies

\[ `\beta`{=tex}\_S(X). \]

## Effect of Y

Arm B additionally contains

-   S,
-   SY.

Their contrast identifies

\[ `\beta`{=tex}\_Y(X). \]

## Effect of F

Arm C contains

-   SY,
-   SYF.

Their contrast identifies

\[ `\beta`{=tex}\_F(X). \]

------------------------------------------------------------------------

# Overidentifying Restriction

Arm C also compares

-   baseline,
-   SY.

Under the additive specification,

\[ V\_{SY}-V\_{0} = `\beta`{=tex}\_S+`\beta`{=tex}\_Y. \]

This comparison does not identify a new parameter. Instead, it provides
an overidentifying restriction that can be used to evaluate the
maintained additive utility specification.

------------------------------------------------------------------------

# Product-2 Treatment Effects

Randomization of (Q) identifies

\[ `\tau`{=tex}\_Q(X), \]

the direct Product-2 treatment effect.

Randomization also identifies the Product-3 context effect

\[ `\kappa`{=tex}\_Q(X), \]

as well as the interaction parameters

\[ `\gamma`{=tex}\_S(X),; `\gamma`{=tex}\_Y(X),; `\gamma`{=tex}\_F(X),
\]

because treatment status is orthogonal to respondent characteristics
under random assignment.

------------------------------------------------------------------------

# Price Sensitivity

The initial choice task alone does not identify

\[ `\alpha`{=tex}(X), \]

because the initial Product-3 prices do not vary across respondents.

Identification instead comes from the repeated common price shifts.

Since every Product-3 alternative moves by the same amount,

\[ V\_{3jt}-V\_{3kt} = V\_{3j0}-V\_{3k0}, \]

so within-nest substitution is unchanged.

However,

\[ W\_{3t} = W\_{30}-`\alpha`{=tex}(X)c_t, \]

which changes substitution between the Product-3 family and Products 1
and 2.

This movement identifies heterogeneous price sensitivity.

------------------------------------------------------------------------

# Nesting Parameter

The nesting parameter

\[ `\lambda`{=tex}(X) \]

is identified primarily from cross-sectional substitution patterns among
the Product-3 alternatives that are simultaneously observed within each
arm.

Because repeated price shifts preserve relative utilities inside the
Product-3 nest, they contribute comparatively little direct information
about (`\lambda`{=tex}(X)).

Empirically, weak identification of the nesting parameter should be
investigated through profile likelihoods, bootstrap distributions, or
sensitivity analyses.

------------------------------------------------------------------------

# Heterogeneity

Identification of heterogeneous parameter functions requires sufficient
overlap in respondent characteristics.

Conceptually, each conditional parameter function is identified from
local variation in respondents with similar values of (X).

The FLM estimator regularizes estimation while preserving the structural
interpretation of the parameter functions.

------------------------------------------------------------------------

# Summary

  ------------------------------------------------------------------------------------------------------------------------
  Parameter                                                           Primary identifying variation
  ------------------------------------------------------------------- ----------------------------------------------------
  (`\tilde`{=tex}`\delta`{=tex}\_2,`\tilde`{=tex}`\delta`{=tex}\_3)   Cross-sectional choice shares (relative to Product
                                                                      1)

  (`\beta`{=tex}\_S)                                                  Baseline vs. S (Arm B)

  (`\beta`{=tex}\_Y)                                                  S vs. SY (Arm B)

  (`\beta`{=tex}\_F)                                                  SY vs. SYF (Arm C)

  (`\tau`{=tex}\_Q)                                                   Randomized Product-2 treatment

  (`\kappa`{=tex}\_Q)                                                 Randomized Product-2 treatment

  (`\gamma`{=tex}\_S,`\gamma`{=tex}\_Y,`\gamma`{=tex}\_F)             Randomized Product-2 treatment

  (`\alpha`{=tex})                                                    Repeated common Product-3 price shifts

  (`\lambda`{=tex})                                                   Cross-sectional within-nest substitution
  ------------------------------------------------------------------------------------------------------------------------

The following files use these identified structural primitives to define
willingness-to-pay functionals and develop estimation and inference.
