# Canonical Model Definition Notes

## Goal

Estimate heterogeneous structural preferences for a new product lineup
using a structural nested-logit model estimated with the
Farrell--Liang--Misra (FLM) framework. The scientific targets are
heterogeneous and average willingness-to-pay (WTP), not reduced-form
choice probabilities.

## Experimental Environment

Each respondent is independently sampled.

Randomizations: 1. Survey arm (B or C). 2. Product-2 treatment Q.

Arm B: - Product 1 - Product 2 - Product 3 - Product 3 + S - Product 3 +
S + Y

Arm C: - Product 1 - Product 2 - Product 3 - Product 3 + S + Y - Product
3 + S + Y + F

Repeated follow-up tasks change only Product-3 prices.

## Price Homogeneity Assumption

Products 1 and 2 display price ranges rather than fixed prices.

Assume respondents map those ranges into latent perceived prices P1e(X)
and P2e(X), deterministic functions of observed covariates.

Because these perceived prices never vary experimentally, they cannot be
separated from baseline utility.

## Normalization

Normalize Product 1 utility to zero.

Primitive utilities:

V1 = δ1 − βP1e(X)

V2 = δ2 − βP2e(X)

Subtracting V1 from all utilities yields

δ̃2(X) = (δ2−δ1) − β(P2e(X)−P1e(X))

and similarly δ̃3(X).

Therefore the identified objects are the normalized intercepts δ̃2(X) and
δ̃3(X), not primitive intercepts or perceived prices individually.

## Structural Utility

Product 2:

V2 = δ̃2(X) + τQ(X)Q

Product 3:

V3 = δ̃3(X) + κQ(X)Q + βS(X)S + βY(X)Y + βF(X)F + γS(X)QS + γY(X)QY +
γF(X)QF − α(X)P3

All parameters are unknown functions of X.

## Nested Logit

Products 1 and 2 are singleton nests.

Product-3 alternatives form one nest with dissimilarity parameter λ(X).

Inclusive values are computed only over alternatives available in the
respondent's assigned arm.

## Repeated Price Design

Across repeated tasks

P3jt = P3j0 + ct

for every Product-3 alternative.

Thus

V3jt = V3j0 − α(X)ct.

Relative Product-3 utilities remain unchanged, so repeated prices
identify α(X) through substitution between the Product-3 family and
Products 1 and 2.

## Identification

Survey arm identifies βS, βY, βF.

Arm C supplies an overidentifying restriction because baseline→SY equals
βS+βY under additivity.

Randomized Q identifies τQ, κQ, γS, γY, γF.

Repeated common Product-3 price shifts identify α(X).

Cross-sectional within-nest substitution identifies λ(X).

## Target Parameters

WTP0 = β/α

WTP1 = (β+γ)/α

ΔWTP = γ/α

Population targets are expectations of respondent-level WTP functions.

## Estimation

The neural network estimates θ(X), not probabilities.

Utilities are constructed from θ(X), nested-logit probabilities are
computed, and respondent-level negative log likelihood is minimized.

Cross-fitting, bootstrap, scores, Hessians, and influence functions are
all respondent-level.

## Maintained Assumptions

-   Random utility maximization.
-   Stable preferences across repeated tasks.
-   Conditional independence of task shocks.
-   Nested-logit error structure.
-   Price homogeneity for Products 1 and 2.
-   Additive entitlement effects.
-   Covariate overlap for heterogeneous estimation.
