# 12 --- Validation, Robustness, and Research Roadmap

> Canonical specification (File 12)

# Purpose

This document describes how the structural model should be validated,
what robustness exercises should accompany the empirical analysis, and
how the project should be organized into a research paper and
implementation roadmap.

------------------------------------------------------------------------

# Model Validation

Validation should occur at multiple levels.

## Predictive Validation

Evaluate:

-   held-out respondent log-likelihood;
-   held-out choice prediction accuracy;
-   calibration of predicted choice probabilities;
-   stability across cross-fitting folds.

The primary objective is not classification accuracy but faithful
recovery of structural preferences.

------------------------------------------------------------------------

# Structural Validation

Assess whether estimated structural parameters satisfy economically
reasonable patterns.

Examples include:

-   positive price sensitivity;
-   plausible willingness-to-pay magnitudes;
-   stable entitlement rankings;
-   interpretable heterogeneity across respondent characteristics.

Large deviations should trigger diagnostic investigation rather than
automatic model modification.

------------------------------------------------------------------------

# Identification Checks

The following empirical checks are recommended.

## Additive Entitlement Structure

Compare the direct baseline-to-SY contrast in Arm C with the sum of the
separately estimated S and Y effects.

Substantial discrepancies suggest the additive specification may be
inadequate.

## Nesting Parameter

Evaluate whether estimates of the nesting parameter are stable across:

-   folds;
-   bootstrap samples;
-   network architectures;
-   regularization choices.

Profile likelihoods may help diagnose weak identification.

------------------------------------------------------------------------

# Robustness Analyses

Recommended sensitivity analyses include:

-   alternative neural network architectures;
-   alternative regularization strengths;
-   different numbers of hidden layers;
-   different cross-fitting folds;
-   exclusion of selected respondent subgroups;
-   alternative optimization algorithms;
-   alternative initialization seeds.

If feasible, also examine sensitivity to assumptions regarding
repeated-task stability.

------------------------------------------------------------------------

# Reporting

The empirical paper should report:

-   parameter estimates;
-   heterogeneous WTP distributions;
-   average WTP with confidence intervals;
-   subgroup analyses;
-   treatment-specific WTP;
-   model diagnostics;
-   validation metrics;
-   robustness summaries.

------------------------------------------------------------------------

# Suggested Paper Organization

1.  Introduction
2.  Experimental Design
3.  Structural Model
4.  Identification
5.  Estimation
6.  Inference
7.  Empirical Results
8.  Robustness
9.  Conclusion

Appendices should contain:

-   full likelihood;
-   implementation details;
-   additional robustness exercises;
-   supplemental tables and figures.

------------------------------------------------------------------------

# Software Deliverables

Recommended outputs include:

-   reproducible estimation scripts;
-   configuration files;
-   trained model checkpoints;
-   respondent-level parameter estimates;
-   WTP summaries;
-   reproducible figures and tables.

------------------------------------------------------------------------

# Future Extensions

Potential extensions include:

-   richer nesting structures;
-   random-coefficient specifications;
-   dynamic survey designs;
-   alternative discrete-choice models;
-   additional treatment interactions;
-   counterfactual product-line optimization using estimated
    heterogeneous preferences.

------------------------------------------------------------------------

# Closing Remarks

The documents in this specification are intended to serve as the
canonical technical reference for future implementation, writing, and
replication work. Future revisions should preserve notation whenever
possible, clearly document any departures from the maintained
assumptions, and keep the structural interpretation of the estimated
parameters central throughout the project.
