# 01 --- Overview and Experimental Design

> **Status:** Canonical specification (File 1 of the master project)

## Purpose

This project develops a structural demand model for a stated-choice
experiment designed to estimate heterogeneous willingness-to-pay (WTP)
for Product-3 entitlements. The econometric objective is to recover
respondent-specific structural preference parameters as functions of
observed covariates using the Farrell--Liang--Misra (FLM) structural
deep learning framework, then perform inference on economically
meaningful functionals such as heterogeneous and average WTP.

This document defines the scientific objective, the experimental
environment, the survey design, and the maintained assumptions. Later
files define the structural model, likelihood, identification,
estimation, inference, and implementation.

------------------------------------------------------------------------

# High-Level Research Questions

The experiment is designed to answer questions including:

1.  What is the average WTP for each Product-3 entitlement?
2.  How does WTP vary across observable respondent characteristics?
3.  How does Product-2 treatment alter the value of Product-3
    entitlements?
4.  How price-sensitive is demand for the Product-3 family?
5.  Can structural demand primitives be recovered using a flexible
    semiparametric estimator instead of a parametric utility
    specification?

The final estimands are structural---not reduced-form treatment effects.

------------------------------------------------------------------------

# Experimental Environment

Each respondent participates in a discrete-choice survey.

Each respondent observes one choice menu followed by several repeated
choice tasks.

The repeated tasks preserve the product menu while shifting Product-3
prices.

Respondents are independently sampled.

The respondent---not the individual task---is the sampling unit for
estimation and inference.

------------------------------------------------------------------------

# Randomization

The experiment contains two independent randomized components.

## Arm Assignment

Each respondent is randomly assigned to one of two survey arms:

-   Arm B
-   Arm C

Arm assignment changes which Product-3 configurations are available.

## Product-2 Treatment

Independently, respondents are randomized to

Q ∈ {0,1}.

Q modifies Product-2 directly and may also modify preferences for
Product-3 through interaction effects.

Randomization of Q is the identifying variation for Product-2 treatment
parameters and Product-3-by-Q interaction effects.

------------------------------------------------------------------------

# Observed Covariates

For each respondent observe

-   X (respondent characteristics)
-   survey arm
-   Q assignment
-   all stated choices across tasks.

The heterogeneous structural model will estimate parameter functions
θ(X).

------------------------------------------------------------------------

# Product Definitions

## Product 1

Reference product.

Its utility is normalized for identification.

## Product 2

Always available.

Displayed with a price range rather than a single deterministic price.

Utility contains

-   relative intercept
-   direct effect of Q.

## Product 3

The Product-3 family consists of multiple entitlement bundles.

Each bundle corresponds to a distinct alternative inside a common
Product-3 nest.

The entitlement indicators are

-   S
-   Y
-   F.  

------------------------------------------------------------------------

# Survey Arms

## Arm B

Respondents observe

-   Product 1
-   Product 2
-   Product-3 baseline
-   Product-3 + S
-   Product-3 + S + Y

Entitlement vectors:

  Alternative     S   Y   F
  ------------- --- --- ---
  Baseline        0   0   0
  S               1   0   0
  SY              1   1   0

------------------------------------------------------------------------

## Arm C

Respondents observe

-   Product 1
-   Product 2
-   Product-3 baseline
-   Product-3 + S + Y
-   Product-3 + S + Y + F

  Alternative     S   Y   F
  ------------- --- --- ---
  Baseline        0   0   0
  SY              1   1   0
  SYF             1   1   1

No respondent ever observes all four entitlement configurations
simultaneously.

Pooling respondents yields four unique Product-3 configurations:

-   baseline
-   S
-   SY
-   SYF.

Later identification arguments rely on this pooled support while
respecting respondent-specific menus in the likelihood.

------------------------------------------------------------------------

# Initial Choice Task

Respondents first answer one baseline choice.

Products 1 and 2 remain fixed.

Product-3 alternatives appear according to the assigned arm.

At this stage Product-3 prices are fixed across respondents.

Consequently, the initial menu alone cannot separately identify
Product-3 price sensitivity.

------------------------------------------------------------------------

# Repeated Price Tasks

After the initial task respondents complete multiple additional choice
tasks.

Across these tasks:

-   arm remains fixed;
-   Product-2 treatment remains fixed;
-   Product-3 entitlement bundles remain fixed;
-   Products 1 and 2 remain unchanged;
-   only Product-3 prices change.

Crucially, every Product-3 alternative receives the same additive price
shift.

Illustrative sequence:

-   baseline prices
-   baseline − \$50
-   baseline − \$25
-   baseline + \$25
-   baseline + \$50

Because all Product-3 prices move together, relative utilities within
the Product-3 nest remain unchanged across repeated tasks. Instead, the
attractiveness of the entire Product-3 family changes relative to
Products 1 and 2. This design is the key source of identification for
the Product-3 price coefficient.

------------------------------------------------------------------------

# Maintained Behavioral Assumptions

The baseline model assumes:

1.  Structural preferences are stable across repeated tasks.
2.  Respondents do not learn during the survey.
3.  There are no fatigue effects.
4.  There are no systematic task-order effects.
5.  Utility shocks are conditionally independent across repeated tasks
    given structural parameters and observed covariates.

These assumptions should later be evaluated through robustness analyses.

------------------------------------------------------------------------

# Roadmap

Subsequent files will develop:

1.  notation and parameterization;
2.  structural utility model;
3.  nested-logit likelihood;
4.  repeated-choice likelihood;
5.  identification;
6.  target WTP functionals;
7.  FLM estimation;
8.  FLM inference;
9.  implementation guidance.

This document intentionally contains no estimation equations; it
establishes the experimental environment that motivates the structural
model.
