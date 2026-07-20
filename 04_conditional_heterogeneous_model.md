# 04 --- Heterogeneous Structural Model

> Canonical specification (File 4)

# Purpose

This file extends the unconditional structural model by allowing every
structural utility parameter to vary flexibly with respondent
characteristics. Rather than imposing linear interactions or a
parametric specification, each primitive is modeled as an unknown
function of observed covariates. These conditional parameter functions
are the objects estimated by the Farrell--Liang--Misra (FLM) framework.

------------------------------------------------------------------------

# Motivation

Economic theory suggests that respondents differ in:

-   baseline preferences,
-   price sensitivity,
-   valuation of Product-3 entitlements,
-   responsiveness to Product-2 treatment.

Instead of manually specifying interactions, the model lets the data
determine how these structural primitives vary over the covariate space.

------------------------------------------------------------------------

# Covariates

Let

\[ X_i`\in`{=tex}`\mathcal `{=tex}X \]

denote the observed respondent characteristics.

Examples include demographics, product usage, prior experience,
behavioral measures, or any survey features believed to predict
structural preferences.

No restriction is imposed on the dimension of (X).

------------------------------------------------------------------------

# Conditional Structural Parameter Functions

Every scalar parameter from the homogeneous model becomes a conditional
function:

\[ `\theta`{=tex}(X)= `\Big`{=tex}( `\tilde`{=tex}`\delta`{=tex}\_2(X),
`\tilde`{=tex}`\delta`{=tex}\_3(X), `\tau`{=tex}\_Q(X),
`\kappa`{=tex}\_Q(X), `\beta`{=tex}\_S(X), `\beta`{=tex}\_Y(X),
`\beta`{=tex}\_F(X), `\gamma`{=tex}\_S(X), `\gamma`{=tex}\_Y(X),
`\gamma`{=tex}\_F(X), `\alpha`{=tex}(X), `\lambda`{=tex}(X)
`\Big`{=tex}). \]

These functions are treated as unknown smooth objects.

No parametric functional form is imposed.

------------------------------------------------------------------------

# Product 2

The deterministic utility becomes

\[ V_2(X) = `\tilde`{=tex}`\delta`{=tex}\_2(X) + `\tau`{=tex}\_Q(X)Q. \]

The treatment effect is therefore heterogeneous across respondents.

------------------------------------------------------------------------

# Product 3

For Product-3 alternative (j),

\[
```{=tex}
\begin{aligned}
V_{3j}(X)
&=
\tilde\delta_3(X)
+
\kappa_Q(X)Q
+
\beta_S(X)S_j
+
\beta_Y(X)Y_j
+
\beta_F(X)F_j \\
&\quad+
\gamma_S(X)Q S_j
+
\gamma_Y(X)Q Y_j
+
\gamma_F(X)Q F_j
-
\alpha(X)P_{3j}.
\end{aligned}
```
\]

Every respondent therefore has their own latent utility system.

------------------------------------------------------------------------

# Interpretation

The conditional functions admit economically meaningful interpretations:

-   (`\alpha`{=tex}(X)): respondent-specific marginal disutility of
    price.
-   (`\beta`{=tex}\_k(X)): respondent-specific value of entitlement (k)
    absent Product-2 treatment.
-   (`\gamma`{=tex}\_k(X)): incremental value of entitlement (k) induced
    by Product-2 treatment.
-   (`\lambda`{=tex}(X)): respondent-specific correlation structure
    within the Product-3 nest.

These objects are primitives. Choice probabilities are derived from them
rather than estimated directly.

------------------------------------------------------------------------

# Conditional Choice Probabilities

Conditional on (X), the nested-logit model produces respondent-specific
choice probabilities,

\[
P(D=j`\mid `{=tex}X)=P_j!`\left`{=tex}(`\theta`{=tex}(X)`\right`{=tex}),
\]

where (P_j(`\cdot`{=tex})) denotes the structural mapping implied by the
nested-logit model.

The mapping itself is developed in the next file.

------------------------------------------------------------------------

# Advantages

Compared with manually interacting covariates and utilities, this
formulation:

-   avoids high-dimensional parametric specifications;
-   allows nonlinear heterogeneity;
-   preserves interpretable structural parameters;
-   enables estimation of heterogeneous willingness-to-pay.

The flexibility is concentrated in the parameter functions rather than
in the utility specification itself.

------------------------------------------------------------------------

# Transition

The next document derives the nested-logit probability system implied by
these heterogeneous utilities, including the arm-specific inclusive
values and respondent-level likelihood contributions.
