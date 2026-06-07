# Pricing experiment sizing and revenue-risk analysis prompt

You are helping me run a pricing-experiment design analysis from a Google Sheet.

Google Sheet link:
[PASTE GOOGLE SHEET LINK HERE]

Use the tab named `stats` as the input source unless I specify another tab.

The `stats` tab should contain, or should be mapped to, the following fields:

- cohort identifier
- cohort size \(N_c\)
- complexity shares for Basic, Deluxe, and Premium
- cohort type, for example `returning` or `defector`
- average revenue by cohort and complexity, for example \(R_{c,B}\), \(R_{c,D}\), \(R_{c,P}\)

Do not write results back to the workbook until I explicitly ask. First, print concise review tables and ask how I want to proceed.

---

## 0. First thing to ask me

Before doing the calculation, list the default choice parameters below and ask which defaults I want to change.

Default parameters:

| Parameter | Default |
|---|---:|
| Test size \(\alpha\) | 0.05 |
| Power \(1-\beta\) | 0.80 |
| Base number of hypothesis tests \(m_0\) | 120 |
| Hypothesis multiplier \(\lambda\) | 1 |
| Total hypothesis tests \(m=\lambda m_0\) | 120 |
| Default-pricing split \(\rho_c\) | 0.90 for every cohort |
| Randomized-pricing split \(1-\rho_c\) | 0.10 for every cohort |
| Minimum allowed \(\rho_c\) | 0.50 |
| Desired MDE target \(\delta\) | 0.01, meaning 1 percentage point |
| MDE target mode | scalar, same target for all cohorts and both tests |
| Split grid for \(\rho\) | 0.50 to 0.99 by 0.01 |
| Price-wing allocation rule | compare equal 20% allocation and precision-best allocation |
| Defector revenue baseline | no-file baseline by default |
| Returning-customer worst-case model | active |
| Revenue-risk report | active if revenue inputs exist |

Ask me:

1. Which defaults should be changed?
2. Should the MDE target be scalar or vector-valued by test, cohort, or cohort type?
3. Should the split \(\rho_c\) be common across cohorts or cohort-specific?
4. Should the randomized-pricing wing use equal 20% allocation or precision-best allocation for feasibility reporting?
5. Which cohorts are returning cohorts and which are defector cohorts?
6. Are the revenue columns in the sheet default-complexity revenues, actual historical average revenues, or modeled price-arm revenues?

After I answer, proceed. If I do not answer, proceed with the defaults.

---

# 1. Setting

There are five cohorts:

\[
c=1,\dots,5.
\]

There are three prior-year complexity groups:

\[
h\in\{B,D,P\}
\]

where:

- \(B\) means Basic
- \(D\) means Deluxe
- \(P\) means Premium

For each cohort \(c\), we know:

\[
N_c = \text{cohort size}
\]

and complexity shares:

\[
\pi_{c,B}, \pi_{c,D}, \pi_{c,P}
\]

with:

\[
\pi_{c,B}+\pi_{c,D}+\pi_{c,P}=1.
\]

The cohort-complexity cell size is:

\[
N_{c,h}=N_c\pi_{c,h}.
\]

The smallest cohort-complexity cell inside cohort \(c\) is:

\[
N_c^{min}=\min_h N_{c,h}.
\]

This is the binding sample size when we want each cohort's smallest complexity group to be powered.

---

# 2. Two test wings

Each cohort is split between two separate experiments.

## 2.1 Default-pricing test

Let:

\[
\rho_c
\]

be the share of cohort \(c\) assigned to the default-pricing test.

Default:

\[
\rho_c=0.90.
\]

Inside the default-pricing test, each complexity group has three arms:

\[
G_h = \text{default price for complexity }h
\]

\[
H = \text{holdout}
\]

\[
M = \text{message-only}
\]

Impose equal holdout and message-only shares:

\[
e_H^D=e_M^D=s_D.
\]

Then:

\[
e_G^D=1-2s_D.
\]

Here \(s_D\) is a share within the default-pricing test wing, not a share of the full cohort.

The planned default-pricing comparisons are:

\[
G_h \text{ vs } H
\]

and:

\[
G_h \text{ vs } M.
\]

## 2.2 Randomized-pricing test

The randomized-pricing test gets:

\[
1-\rho_c
\]

of cohort \(c\).

Inside the randomized-pricing test, each complexity group has five arms:

\[
H = \text{holdout}
\]

\[
M = \text{message-only}
\]

\[
B = \text{Basic price}
\]

\[
D = \text{Deluxe price}
\]

\[
P = \text{Premium price}
\]

Impose equal holdout and message-only shares:

\[
e_H^P=e_M^P=s_P.
\]

Impose equal price-arm shares:

\[
e_B^P=e_D^P=e_P^P=p.
\]

Then:

\[
2s_P+3p=1.
\]

The planned randomized-pricing comparisons are each price arm against holdout and message-only:

\[
B \text{ vs } H,\quad B \text{ vs } M
\]

\[
D \text{ vs } H,\quad D \text{ vs } M
\]

\[
P \text{ vs } H,\quad P \text{ vs } M.
\]

---

# 3. Hypothesis-test count and power multiplier

Base hypothesis count:

\[
m_0=120.
\]

Hypothesis multiplier:

\[
\lambda.
\]

Default:

\[
\lambda=1.
\]

Total tests:

\[
m=\lambda m_0.
\]

With test size:

\[
\alpha
\]

and power:

\[
1-\beta,
\]

the multiplier is:

\[
z^* = z_{1-\alpha/(2m)} + z_{1-\beta}.
\]

Use two-sided Bonferroni correction.

Default:

\[
\alpha=0.05,\quad 1-\beta=0.80.
\]

---

# 4. Default-pricing MDE

For cohort \(c\), complexity \(h\), split \(\rho_c\), and default-wing holdout/message share \(s_D\), the sample size is:

\[
\rho_c N_{c,h}.
\]

The MDE for \(G_h\) vs \(H\), or \(G_h\) vs \(M\), under worst-case binary variance \(0.25\), is:

\[
MDE^D_{c,h}(s_D,\rho_c)
=
z^*
\sqrt{
\frac{0.25}{\rho_c N_{c,h}}
\left(
\frac{1}{1-2s_D}+\frac{1}{s_D}
\right)
}.
\]

To size for the smallest complexity group inside cohort \(c\), use:

\[
N_c^{min}.
\]

Then:

\[
MDE^{D,binding}_{c}(s_D,\rho_c)
=
z^*
\sqrt{
\frac{0.25}{\rho_c N_c^{min}}
\left(
\frac{1}{1-2s_D}+\frac{1}{s_D}
\right)
}.
\]

The best possible default-pricing MDE for cohort \(c\) and split \(\rho_c\) occurs at:

\[
s_D^*=\frac{1}{2+\sqrt{2}}\approx 0.2929.
\]

The minimum feasible default-pricing MDE is:

\[
MDE^{D,min}_{c}(\rho_c)
=
z^*
\sqrt{
\frac{0.25(3+2\sqrt{2})}{\rho_c N_c^{min}}
}.
\]

This is a feasibility lower bound, not a recommended business allocation.

Given a target \(\delta_D\), solve for the smallest \(s_D\) such that:

\[
MDE^{D,binding}_{c}(s_D,\rho_c)\leq \delta_D.
\]

If \(\delta_D < MDE^{D,min}_{c}(\rho_c)\), then the target is infeasible for cohort \(c\) under split \(\rho_c\).

---

# 5. Randomized-pricing MDE

For cohort \(c\), complexity \(h\), split \(\rho_c\), holdout/message share \(s_P\), and price-arm share \(p\), the sample size is:

\[
(1-\rho_c)N_{c,h}.
\]

The MDE for any price arm versus holdout or message-only is:

\[
MDE^P_{c,h}(s_P,p,\rho_c)
=
z^*
\sqrt{
\frac{0.25}{(1-\rho_c)N_{c,h}}
\left(
\frac{1}{p}+\frac{1}{s_P}
\right)
}.
\]

To size for the smallest complexity group inside cohort \(c\), use:

\[
N_c^{min}.
\]

Then:

\[
MDE^{P,binding}_{c}(s_P,p,\rho_c)
=
z^*
\sqrt{
\frac{0.25}{(1-\rho_c)N_c^{min}}
\left(
\frac{1}{p}+\frac{1}{s_P}
\right)
}.
\]

The precision-best randomized-pricing allocation is:

\[
s_P^*=\frac{1}{2+\sqrt{6}}\approx 0.2247.
\]

Then:

\[
p^*=\frac{1-2s_P^*}{3}\approx 0.1835.
\]

The minimum feasible randomized-pricing MDE is:

\[
MDE^{P,min}_{c}(\rho_c)
=
z^*
\sqrt{
\frac{0.25(5+2\sqrt{6})}{(1-\rho_c)N_c^{min}}
}.
\]

This is also a feasibility lower bound.

Equal 20% allocation is also useful:

\[
s_P=p=0.20.
\]

Compute its implied MDE:

\[
MDE^{P,equal}_{c}(\rho_c)
=
z^*
\sqrt{
\frac{0.25}{(1-\rho_c)N_c^{min}}
\left(
\frac{1}{0.20}+\frac{1}{0.20}
\right)
}.
\]

The equal allocation is usually very close to precision-best and is easier to explain.

---

# 6. MDE targets

Allow the MDE target to be one of:

## Scalar target

Same MDE for all cohorts and both test wings:

\[
\delta_D=\delta_P=\delta.
\]

Default:

\[
\delta=0.01
\]

meaning one percentage point.

## Vector target by test

\[
\delta_D,\quad \delta_P.
\]

## Vector target by cohort

\[
\delta_{D,c},\quad \delta_{P,c}.
\]

Start with scalar target by default.

---

# 7. Default 90/10 scenario

First run the default split:

\[
\rho_c=0.90
\]

for every cohort.

For each cohort \(c\), compute:

\[
N_c^{min}
\]

\[
MDE^{D,min}_{c}(0.90)
\]

\[
MDE^{P,min}_{c}(0.90)
\]

\[
MDE^{P,equal}_{c}(0.90)
\]

The binding minimum feasible MDE for cohort \(c\) is:

\[
MDE^{bind}_{c}(0.90)
=
\max\left[
MDE^{D,min}_{c}(0.90),
MDE^{P,min}_{c}(0.90)
\right].
\]

The global binding MDE under 90/10 is:

\[
MDE^{bind}_{global}(0.90)
=
\max_c MDE^{bind}_{c}(0.90).
\]

Report whether:

\[
MDE^{bind}_{global}(0.90)\leq \delta.
\]

If yes, the default 90/10 split can hit the target MDE in every cohort and smallest complexity group under the best feasible within-wing allocations.

If no, report the binding cohort and binding wing.

---

# 8. Split grid

Store a grid of split values:

\[
\rho \in \{0.50,0.51,\dots,0.99\}.
\]

Allow cohort-specific splits:

\[
\rho_c.
\]

For each cohort \(c\) and each split \(\rho\), compute:

\[
MDE^{D,min}_{c}(\rho)
\]

\[
MDE^{P,min}_{c}(\rho)
\]

\[
MDE^{P,equal}_{c}(\rho)
\]

\[
MDE^{bind}_{c}(\rho)
=
\max\left[
MDE^{D,min}_{c}(\rho),
MDE^{P,min}_{c}(\rho)
\right].
\]

Store this grid in memory as a dataframe, not in the workbook, unless I explicitly ask.

Also compute the split closest to 0.90 that satisfies the target:

\[
\rho_c^{closest}
=
\arg\min_{\rho\in\mathcal{R}}
|\rho-0.90|
\]

subject to:

\[
MDE^{D,min}_{c}(\rho)\leq \delta_D
\]

and:

\[
MDE^{P,min}_{c}(\rho)\leq \delta_P.
\]

If no split works for a cohort, flag infeasible.

Also compute the split that minimizes the binding MDE:

\[
\rho_c^{best}
=
\arg\min_{\rho\in\mathcal{R}}
MDE^{bind}_{c}(\rho).
\]

---

# 9. Feasible interval for target MDE

For each cohort \(c\), a target pair \((\delta_D,\delta_P)\) implies:

\[
\rho_c
\geq
\frac{
0.25(z^*)^2(3+2\sqrt{2})
}{
N_c^{min}\delta_D^2
}
\]

and:

\[
\rho_c
\leq
1-
\frac{
0.25(z^*)^2(5+2\sqrt{6})
}{
N_c^{min}\delta_P^2
}.
\]

Also:

\[
\rho_c\geq 0.50.
\]

So:

\[
\rho^{min}_c=
\max\left[
0.50,\,
\frac{
0.25(z^*)^2(3+2\sqrt{2})
}{
N_c^{min}\delta_D^2
}
\right]
\]

and:

\[
\rho^{max}_c=
1-
\frac{
0.25(z^*)^2(5+2\sqrt{6})
}{
N_c^{min}\delta_P^2
}.
\]

The target is feasible for cohort \(c\) if:

\[
\rho^{min}_c\leq \rho^{max}_c.
\]

For a common split across all cohorts, the target is feasible if:

\[
\max_c \rho^{min}_c
\leq
\min_c \rho^{max}_c.
\]

For cohort-specific splits, the target is feasible if the condition holds cohort by cohort.

---

# 10. Actual allocation after selecting a split

Once a split \(\rho_c\) is selected and targets \((\delta_D,\delta_P)\) are selected, compute actual shares.

## 10.1 Default-pricing wing shares

For each cohort \(c\), solve for the smallest \(s_D\) satisfying:

\[
MDE^{D,binding}_{c}(s_D,\rho_c)\leq \delta_D.
\]

Then:

\[
H=s_D
\]

\[
M=s_D
\]

\[
G=1-2s_D.
\]

Default-pricing wing stakeholder table for cohort \(c\):

| Row | Share within default-pricing wing | Share of total cohort | Count |
|---|---:|---:|---:|
| Holdout | \(s_D\) | \(\rho_c s_D\) | \(N_c\rho_c s_D\) |
| Message-only | \(s_D\) | \(\rho_c s_D\) | \(N_c\rho_c s_D\) |
| Default Basic if Basic complexity | \(\pi_{c,B}(1-2s_D)\) | \(\rho_c\pi_{c,B}(1-2s_D)\) | \(N_c\rho_c\pi_{c,B}(1-2s_D)\) |
| Default Deluxe if Deluxe complexity | \(\pi_{c,D}(1-2s_D)\) | \(\rho_c\pi_{c,D}(1-2s_D)\) | \(N_c\rho_c\pi_{c,D}(1-2s_D)\) |
| Default Premium if Premium complexity | \(\pi_{c,P}(1-2s_D)\) | \(\rho_c\pi_{c,P}(1-2s_D)\) | \(N_c\rho_c\pi_{c,P}(1-2s_D)\) |

The shares within the default-pricing wing should sum to 1.

## 10.2 Randomized-pricing wing shares

For the randomized-pricing wing, produce two options unless I choose one:

### Option A: Equal allocation

\[
H=M=B=D=P=0.20.
\]

### Option B: Precision-best allocation

\[
H=M=s_P^*=0.2247
\]

\[
B=D=P=p^*=0.1835.
\]

Randomized-pricing wing stakeholder table for cohort \(c\):

| Row | Share within randomized-pricing wing | Share of total cohort | Count |
|---|---:|---:|---:|
| Holdout | \(s_P\) | \((1-\rho_c)s_P\) | \(N_c(1-\rho_c)s_P\) |
| Message-only | \(s_P\) | \((1-\rho_c)s_P\) | \(N_c(1-\rho_c)s_P\) |
| Basic price | \(p\) | \((1-\rho_c)p\) | \(N_c(1-\rho_c)p\) |
| Deluxe price | \(p\) | \((1-\rho_c)p\) | \(N_c(1-\rho_c)p\) |
| Premium price | \(p\) | \((1-\rho_c)p\) | \(N_c(1-\rho_c)p\) |

The shares within the randomized-pricing wing should sum to 1.

---

# 11. Revenue-risk accounting layer

Keep the revenue-risk calculation separate from power. Power determines precision. Revenue accounting determines business risk.

## 11.1 Inputs

For each cohort and complexity, use average revenue:

\[
R_{c,h}
\]

where:

\[
h\in\{B,D,P\}.
\]

Interpretation:

\[
R_{c,h} = \text{average revenue under default complexity price }h.
\]

For assigned price \(k\), use:

\[
R_{c,k}
\]

as the revenue from that assigned price level unless the sheet supplies a separate revenue matrix \(R_{c,h,k}\).

Complexity order:

\[
B < D < P.
\]

## 11.2 Returning cohorts

For returning cohorts, assume:

- Holdout: no incremental revenue impact relative to modeled baseline.
- Message-only: no incremental revenue impact.
- Default price: no incremental impact relative to modeled baseline.
- Randomized price below true complexity: customer converts at lower price, causing cannibalization.
- Randomized price above true complexity: customer does not convert, causing lost default revenue.

For true complexity \(h\) and assigned price \(k\):

\[
Loss^{returning}_{c,h,k}
=
\begin{cases}
0, & k=h \\
R_{c,h}-R_{c,k}, & k<h \\
R_{c,h}, & k>h
\end{cases}
\]

Use nonnegative loss:

\[
\max(Loss,0).
\]

Expected randomized-pricing revenue loss for cohort \(c\):

\[
Cost^P_c
=
(1-\rho_c)N_c
\sum_h \pi_{c,h}
\sum_{k\in\{B,D,P\}} p_k
Loss^{returning}_{c,h,k}.
\]

Where \(p_k\) is the within-randomized-pricing-wing share assigned to price \(k\). Under equal allocation, \(p_k=0.20\). Under precision-best allocation, \(p_k=0.1835\).

Holdout and message-only have zero incremental revenue impact under the stated returning-customer assumption.

## 11.3 Defector cohorts

Default defector assumption:

- Counterfactual no-file revenue is zero.
- Giving an offer has no downside unless a positive baseline revenue is specified.
- Under default, set revenue downside to zero.

Allow an optional defector baseline revenue:

\[
R^{base}_{c,h}.
\]

If the user chooses a "would-have-filed" worst-case defector scenario, use:

\[
Loss^{defector}_{c,h,k}
=
\begin{cases}
R^{base}_{c,h}-R_{c,k}, & R_{c,k}<R^{base}_{c,h} \\
R^{base}_{c,h}, & R_{c,k}\geq R^{base}_{c,h} \text{ and we assume no conversion above baseline}
\end{cases}
\]

Use nonnegative loss.

Report both scenarios if data are available:

1. Defector no-file baseline: cost equals zero by default.
2. Defector would-have-filed baseline: cost computed using \(R^{base}_{c,h}\).

## 11.4 Revenue output

For each cohort and split, report:

- default-pricing test expected revenue impact
- randomized-pricing test expected worst-case revenue loss
- total expected worst-case revenue loss
- loss per assigned customer
- loss by complexity
- loss by price arm

Store revenue-risk results by:

\[
(c,\rho,\delta,\text{allocation rule})
\]

so I can ask follow-up questions without rerunning all logic.

---

# 12. Python implementation guidance

Implement the functions below. Use them directly rather than inventing new formulas.

```python
from math import sqrt
from statistics import NormalDist
import pandas as pd
import numpy as np

COMPLEXITIES = ["Basic", "Deluxe", "Premium"]
ORDER = {"Basic": 0, "Deluxe": 1, "Premium": 2}

def z_multiplier(alpha=0.05, power=0.80, num_tests=120):
    nd = NormalDist()
    return nd.inv_cdf(1 - alpha / (2 * num_tests)) + nd.inv_cdf(power)

def default_s_opt():
    return 1 / (2 + sqrt(2))

def price_s_opt():
    return 1 / (2 + sqrt(6))

def price_p_from_s(s):
    return (1 - 2 * s) / 3

def default_mde(N_min, rho, s, z):
    if rho <= 0 or s <= 0 or s >= 0.5:
        return float("inf")
    g = 1 - 2 * s
    if g <= 0:
        return float("inf")
    return z * sqrt(0.25 / (rho * N_min) * (1 / g + 1 / s))

def default_mde_min(N_min, rho, z):
    s = default_s_opt()
    return default_mde(N_min, rho, s, z)

def solve_default_s(N_min, rho, target_mde, z):
    min_mde = default_mde_min(N_min, rho, z)
    if target_mde < min_mde:
        return None
    K = rho * N_min * target_mde**2 / (0.25 * z**2)
    disc = (K + 1)**2 - 8 * K
    if disc < 0:
        return None
    return ((K + 1) - sqrt(disc)) / (4 * K)

def price_mde(N_min, rho, s, z):
    if rho >= 1 or rho < 0 or s <= 0 or s >= 0.5:
        return float("inf")
    p = price_p_from_s(s)
    if p <= 0:
        return float("inf")
    return z * sqrt(0.25 / ((1 - rho) * N_min) * (1 / p + 1 / s))

def price_mde_min(N_min, rho, z):
    s = price_s_opt()
    return price_mde(N_min, rho, s, z)

def price_mde_equal(N_min, rho, z):
    return price_mde(N_min, rho, 0.20, z)

def build_feasibility_grid(cohort_df, alpha=0.05, power=0.80,
                           base_tests=120, hyp_multiplier=1,
                           rho_grid=None, target_mde=0.01):
    if rho_grid is None:
        rho_grid = np.round(np.arange(0.50, 1.00, 0.01), 2)
    num_tests = base_tests * hyp_multiplier
    z = z_multiplier(alpha, power, num_tests)

    rows = []
    for _, row in cohort_df.iterrows():
        cohort = row["cohort"]
        N = row["cohort_size"]
        shares = [row["share_basic"], row["share_deluxe"], row["share_premium"]]
        N_min = N * min(shares)

        for rho in rho_grid:
            mde_d_min = default_mde_min(N_min, rho, z)
            mde_p_min = price_mde_min(N_min, rho, z)
            mde_p_equal = price_mde_equal(N_min, rho, z)
            bind = max(mde_d_min, mde_p_min)

            rows.append({
                "cohort": cohort,
                "cohort_size": N,
                "N_min_complexity": N_min,
                "rho": rho,
                "mde_default_min": mde_d_min,
                "mde_price_min": mde_p_min,
                "mde_price_equal": mde_p_equal,
                "mde_binding_min": bind,
                "target_mde": target_mde,
                "target_feasible_best_alloc": bind <= target_mde,
                "target_feasible_equal_price": max(mde_d_min, mde_p_equal) <= target_mde
            })

    return pd.DataFrame(rows), z

def closest_feasible_to_90(grid_df, target_mde=0.01, use_equal_price=False):
    mde_col = "mde_price_equal" if use_equal_price else "mde_price_min"
    out = []
    for cohort, g in grid_df.groupby("cohort"):
        feasible = g[(g["mde_default_min"] <= target_mde) & (g[mde_col] <= target_mde)].copy()
        if feasible.empty:
            best = g.loc[g["mde_binding_min"].idxmin()]
            out.append({
                "cohort": cohort,
                "feasible": False,
                "rho_selected": None,
                "closest_distance_to_90": None,
                "best_rho": best["rho"],
                "best_binding_mde": best["mde_binding_min"],
                "binding_reason": "No rho satisfies target"
            })
        else:
            feasible["dist_to_90"] = (feasible["rho"] - 0.90).abs()
            sel = feasible.sort_values(["dist_to_90", "rho"]).iloc[0]
            out.append({
                "cohort": cohort,
                "feasible": True,
                "rho_selected": sel["rho"],
                "closest_distance_to_90": sel["dist_to_90"],
                "best_rho": None,
                "best_binding_mde": sel["mde_binding_min"],
                "binding_reason": ""
            })
    return pd.DataFrame(out)

def default_allocation_for_target(N_min, rho, target_mde, z):
    s = solve_default_s(N_min, rho, target_mde, z)
    if s is None:
        return None
    return {
        "holdout_share_within_default_wing": s,
        "message_share_within_default_wing": s,
        "default_share_within_default_wing": 1 - 2 * s,
        "implied_mde": default_mde(N_min, rho, s, z)
    }

def price_allocation(rule="equal"):
    if rule == "equal":
        return {"s_price_controls": 0.20, "p_price_arms": 0.20}
    if rule == "precision_best":
        s = price_s_opt()
        return {"s_price_controls": s, "p_price_arms": price_p_from_s(s)}
    raise ValueError("Unknown rule")

def returning_loss(avg_rev_by_complexity, true_complexity, assigned_price):
    R_true = avg_rev_by_complexity[true_complexity]
    R_assigned = avg_rev_by_complexity[assigned_price]
    if ORDER[assigned_price] == ORDER[true_complexity]:
        return 0.0
    if ORDER[assigned_price] < ORDER[true_complexity]:
        return max(R_true - R_assigned, 0.0)
    if ORDER[assigned_price] > ORDER[true_complexity]:
        return max(R_true, 0.0)

def randomized_price_revenue_loss(cohort_row, rho, price_arm_share, revenue_cols):
    # revenue_cols maps complexity name to a column name in cohort_row
    avg_rev = {h: cohort_row[revenue_cols[h]] for h in COMPLEXITIES}
    shares = {
        "Basic": cohort_row["share_basic"],
        "Deluxe": cohort_row["share_deluxe"],
        "Premium": cohort_row["share_premium"],
    }
    N = cohort_row["cohort_size"]
    total_loss = 0.0
    for h in COMPLEXITIES:
        for k in COMPLEXITIES:
            loss = returning_loss(avg_rev, h, k)
            total_loss += (1 - rho) * N * shares[h] * price_arm_share * loss
    return total_loss
```

The functions above have been tested for the core formulas. For example, with \(m=600\), \(z^*\approx 4.776\). With \(N_{\min}=260{,}000\) and \(\rho=0.90\), the default-pricing minimum MDE is approximately 1.19 pp, and the randomized-pricing minimum MDE is approximately 4.66 pp.

---

# 13. Review report to print

After running the default settings, print these concise tables.

## Table 1: Parameter settings

Show:

- \(\alpha\)
- power
- base tests \(m_0\)
- hypothesis multiplier \(\lambda\)
- total tests \(m\)
- \(z^*\)
- default \(\rho\)
- target MDE
- price-wing allocation rule
- split grid

## Table 2: Default 90/10 feasibility by cohort

One row per cohort:

- cohort
- cohort size
- smallest complexity share
- \(N_c^{min}\)
- default-pricing minimum feasible MDE at \(\rho=0.90\)
- randomized-pricing minimum feasible MDE at \(\rho=0.90\)
- randomized-pricing equal-allocation MDE at \(\rho=0.90\)
- binding MDE
- target feasible under best allocation?
- target feasible under equal price allocation?
- binding wing

## Table 3: Split grid summary by cohort

One row per cohort:

- cohort
- closest feasible \(\rho\) to 0.90 for target MDE
- feasible?
- best statistical \(\rho\)
- best binding MDE
- distance from 0.90
- binding reason if infeasible

## Table 4: Final allocation tables by cohort

For each cohort, print two separate tables.

### A. Default-pricing test table

Rows:

- Holdout
- Message-only
- Default Basic if Basic complexity
- Default Deluxe if Deluxe complexity
- Default Premium if Premium complexity

Columns:

- share within default-pricing wing
- share of total cohort
- number of observations

### B. Randomized-pricing test table

Rows:

- Holdout
- Message-only
- Basic price
- Deluxe price
- Premium price

Columns:

- share within randomized-pricing wing
- share of total cohort
- number of observations

The final deliverable should be cohort by cohort, with these two separate tables for each cohort.

## Table 5: Revenue-risk summary

One row per cohort and selected \(\rho\):

- cohort
- cohort type
- selected \(\rho\)
- randomized-pricing wing count
- price-arm allocation rule
- expected worst-case revenue loss
- loss per cohort member
- loss per randomized-pricing-wing member
- largest loss complexity
- largest loss assigned price arm

---

# 14. Final questions to ask after printing

After printing the review report, ask:

1. Should I keep the default 90/10 split or use the closest feasible split to the target MDE?
2. Should the randomized-pricing wing use equal 20% allocation or precision-best allocation?
3. Should I write these results to the workbook?
4. Should I run a different MDE target, alpha, power, or hypothesis multiplier?
5. Should I turn on the defector would-have-filed revenue scenario?
6. Should I produce a revenue-risk frontier over the \(\rho\) grid?
