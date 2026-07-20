# 05 --- Nested-Logit Choice Probabilities and Likelihood

> Canonical specification (File 5)

# Purpose

This file derives the nested-logit probability system implied by the
heterogeneous utility specification. Respondents choose among
alternatives organized into three nests:

-   Product 1 (singleton)
-   Product 2 (singleton)
-   Product-3 family (multiple alternatives)

Only the Product-3 family contains multiple alternatives.

------------------------------------------------------------------------

# Error Structure

Let total utility be

\[ U\_{ijt}=V\_{ijt}+`\varepsilon`{=tex}\_{ijt}, \]

where (V\_{ijt}) is the deterministic utility from File 4 and the
disturbances follow a generalized extreme value (GEV) distribution
consistent with a nested-logit model.

The Product-3 nest has dissimilarity parameter

\[ `\lambda`{=tex}(X)`\in`{=tex}(0,1\]. \]

When (`\lambda=1`{=tex}), the model collapses to the multinomial logit.

------------------------------------------------------------------------

# Lower-Level Product-3 Probabilities

Conditional on entering the Product-3 nest, the probability of choosing
Product-3 alternative (j) is

\[ P(j`\mid 3`{=tex},X) =
`\frac{\exp\!\left(V_j(X)/\lambda(X)\right)}`{=tex}
{`\sum`{=tex}\_{k`\in`{=tex}`\mathcal `{=tex}C_3(A)}
`\exp`{=tex}!`\left`{=tex}(V_k(X)/`\lambda`{=tex}(X)`\right`{=tex})}, \]

where the denominator is evaluated only over Product-3 configurations
available in the respondent's assigned survey arm.

------------------------------------------------------------------------

# Inclusive Value

The inclusive value summarizes the expected value of entering the
Product-3 nest.

For Arm B,

\[ IV_B(X) = `\log`{=tex}`\left`{=tex}( e\^{V\_{0}/`\lambda`{=tex}} +
e\^{V\_{S}/`\lambda`{=tex}} + e\^{V\_{SY}/`\lambda`{=tex}}
`\right`{=tex}). \]

For Arm C,

\[ IV_C(X) = `\log`{=tex}`\left`{=tex}( e\^{V\_{0}/`\lambda`{=tex}} +
e\^{V\_{SY}/`\lambda`{=tex}} + e\^{V\_{SYF}/`\lambda`{=tex}}
`\right`{=tex}). \]

The pooled four-configuration menu is never used in an individual's
likelihood.

------------------------------------------------------------------------

# Upper-Level Utilities

The singleton nests have utilities

\[ W_1(X)=V_1(X), \]

\[ W_2(X)=V_2(X), \]

while the Product-3 nest has utility

\[ W_3(X) = `\lambda`{=tex}(X),IV(X). \]

------------------------------------------------------------------------

# Upper-Level Nest Probabilities

The probability of selecting the Product-3 family is

\[ P(3`\mid `{=tex}X) = `\frac{\exp(W_3)}`{=tex}
{`\exp`{=tex}(W_1)+`\exp`{=tex}(W_2)+`\exp`{=tex}(W_3)}. \]

Analogous expressions hold for Products 1 and 2.

------------------------------------------------------------------------

# Overall Choice Probabilities

For Product-3 alternative (j),

\[ P(j`\mid `{=tex}X) = P(3`\mid `{=tex}X), P(j`\mid3`{=tex},X). \]

For Products 1 and 2, the upper-level probability is the full choice
probability because those nests contain a single alternative.

------------------------------------------------------------------------

# Respondent-Level Likelihood

Let respondent (i) complete tasks (t=0,`\ldots`{=tex},T).

For observed choices (D\_{it}),

\[ L_i(`\theta`{=tex}) = `\prod`{=tex}*{t=0}\^{T}
P(D*{it}`\mid `{=tex}X_i;`\theta`{=tex}). \]

The respondent log-likelihood is

\[ `\ell`{=tex}*i(`\theta`{=tex}) = `\sum`{=tex}*{t=0}\^{T} `\log`{=tex}
P(D\_{it}`\mid `{=tex}X_i;`\theta`{=tex}). \]

This respondent-level log-likelihood is the basic loss function used
throughout estimation.

------------------------------------------------------------------------

# Role in FLM

The FLM framework treats the respondent-level negative log-likelihood as
the target loss,

\[ L_i(`\theta`{=tex}) = -`\ell`{=tex}\_i(`\theta`{=tex}). \]

The conditional parameter function

\[ `\theta`{=tex}*0(x) = `\arg`{=tex}`\min`{=tex}*`\theta`{=tex}
E\[L_i(`\theta`{=tex})`\mid `{=tex}X=x\] \]

is estimated nonparametrically.

Later files derive identification, gradients, Hessians, influence
functions, and inference from this loss.
