# 06 --- Repeated-Choice Panel Structure and Identification from Price Variation

> Canonical specification (File 6)

# Purpose

This document formalizes the repeated-choice component of the
experiment. It explains how repeated price tasks enter the likelihood,
why the respondent is the sampling unit, and why common Product-3 price
shifts identify the Product-3 price coefficient even though relative
Product-3 prices remain fixed.

------------------------------------------------------------------------

# Panel Structure

Each respondent completes one initial choice task followed by repeated
price tasks.

Let

-   (i=1,`\ldots`{=tex},n) index respondents.
-   (t=0,`\ldots`{=tex},T) index tasks.

The observed panel for respondent (i) is

\[ {D\_{i0},D\_{i1},`\ldots`{=tex},D\_{iT}}. \]

Tasks are not treated as independent respondents.

------------------------------------------------------------------------

# Experimental Manipulation

Across repeated tasks:

-   survey arm is fixed;
-   Product-2 treatment (Q_i) is fixed;
-   entitlement bundles are fixed;
-   Products 1 and 2 are unchanged;
-   only Product-3 prices change.

For Product-3 alternative (j),

\[ P\_{3jt}=P\_{3j0}+c_t, \]

where (c_t) is a common additive price shift.

------------------------------------------------------------------------

# Consequence for Utilities

The Product-3 utility becomes

\[ V\_{3jt}(X) = V\_{3j0}(X)-`\alpha`{=tex}(X)c_t. \]

Therefore

\[ V\_{3jt}-V\_{3kt} = V\_{3j0}-V\_{3k0} \]

for any two Product-3 alternatives (j,k).

Relative utilities inside the Product-3 nest never change across
repeated tasks.

------------------------------------------------------------------------

# Within-Nest Choice Shares

Conditional probabilities inside the Product-3 nest therefore remain
unchanged under common price shifts:

\[ P(j`\mid 3`{=tex},X,t)=P(j`\mid 3`{=tex},X,0). \]

Repeated price tasks do **not** identify substitution among Product-3
alternatives.

Those substitution patterns are identified from the cross-sectional
entitlement variation across survey arms.

------------------------------------------------------------------------

# Between-Nest Substitution

Although within-nest shares remain fixed, the attractiveness of the
entire Product-3 family changes.

The upper-level Product-3 utility satisfies

\[ W\_{3t}(X) = W\_{30}(X)-`\alpha`{=tex}(X)c_t. \]

Consequently,

common price shifts induce substitution between

-   Product 1,
-   Product 2,
-   the Product-3 family.

This is the principal source of identifying variation for the Product-3
price coefficient.

------------------------------------------------------------------------

# Respondent-Level Likelihood

The contribution of respondent (i) is

\[ L_i(`\theta`{=tex}) = `\prod`{=tex}*{t=0}\^{T}
P(D*{it}`\mid `{=tex}X_i;`\theta`{=tex}). \]

Equivalently,

\[ `\ell`{=tex}*i(`\theta`{=tex}) = `\sum`{=tex}*{t=0}\^{T}
`\log `{=tex}P(D\_{it}`\mid `{=tex}X_i;`\theta`{=tex}). \]

Inference is based on respondent-level scores rather than treating tasks
as independent observations.

------------------------------------------------------------------------

# Maintained Assumptions

Identification requires:

1.  Structural preferences are stable across tasks.
2.  Respondents do not systematically learn.
3.  No fatigue effects materially alter preferences.
4.  No task-order effects are confounded with the deterministic price
    sequence.
5.  Conditional independence of task-level utility shocks given
    structural parameters.

If these assumptions fail, the estimated price coefficient may be
biased.

Future robustness analyses may include task fixed effects, randomized
task order, or order-specific sensitivity analyses if such data are
available.

------------------------------------------------------------------------

# Connection to Identification

The repeated panel design contributes information about:

-   the Product-3 price coefficient;
-   heterogeneous price sensitivity (`\alpha`{=tex}(X));
-   average willingness-to-pay functionals.

It contributes comparatively little direct information about the nesting
parameter because within-nest substitution probabilities remain
essentially unchanged across common price shifts.

The next file formalizes identification of every structural parameter
and maps each parameter to its corresponding experimental source of
variation.
