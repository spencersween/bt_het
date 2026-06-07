# Reproducible prompt for cohort-complexity pricing experiment sizing

You are helping me run a pricing-experiment sizing analysis from a Google Sheet.

Google Sheet link:
[PASTE GOOGLE SHEET LINK HERE]

Use the tab named `stats` as the input source. It contains:

- cohort names or IDs
- cohort sizes
- prior-year complexity shares by cohort
- complexities: Basic, Deluxe, Premium

Do not write results back to the workbook unless I explicitly ask. For now, compute the results and print concise tables for review.

## Core objective

We need to size experimental allocation shares for binary outcomes under worst-case variance. The design is implemented with a 90% and 10% stakeholder-facing routing structure, but power is calculated using collapsed analysis arms within each cohort by prior-year-complexity cell.

The output should help us understand, for a grid of target minimum detectable effects, the implied allocation shares and counts after aggregating back to stakeholder-facing cohort-level tables.

## Ask the user first

Before running the analysis, ask:

1. What grid of target MDEs should we show in the printed review tables?
2. Should MDEs be interpreted as absolute percentage-point effects?
3. Should we use the default internal fine grid from 0 percentage points to 50 percentage points in 0.5 percentage-point increments?

If the user does not specify a grid, use:

- visible review grid: 1 pp, 2 pp, 3 pp, 4 pp, 5 pp, 6 pp, 7 pp, 8 pp, 9 pp, 10 pp
- internal fine grid: 0 pp to 50 pp in increments of 0.5 pp

Keep the full fine-grid results available in the active session so that if I ask for a specific MDE later, you can retrieve the corresponding allocation and MDE summary. Do not write those full results into the workbook unless I explicitly ask.

Note: the 0 pp row in the internal fine grid is a reference boundary only. A zero-MDE target is not feasible with finite sample size, so mark it infeasible and do not use it to compute reciprocal share formulas.


## Design cells

Let:

\[
c = \text{cohort}
\]

\[
h \in \{Basic, Deluxe, Premium\} = \text{prior-year complexity}
\]

The cohort-complexity cell size is:

\[
N_{c,h}=N_c \pi_{c,h}
\]

where:

- \(N_c\) is the total cohort size.
- \(\pi_{c,h}\) is the complexity share for complexity \(h\) in cohort \(c\).

The power calculation is done at the cohort-complexity level.

## Top-level routing design

The stakeholder-facing routing is:

\[
\rho=0.90
\]

\[
1-\rho=0.10
\]

Interpretation:

- 90% rules-based wing
- 10% price-randomization wing

This 90/10 split is a routing description. It is not the final analysis-arm structure.

## Collapsed final analysis arms

After the experiment is run, collapse the data within each cohort-complexity cell into five analysis arms:

1. \(G\): aggregated default rules-based price
2. \(H\): aggregated holdout
3. \(M\): aggregated message-only
4. \(R_1\): randomized off-default price 1
5. \(R_2\): randomized off-default price 2

The default price depends on prior-year complexity:

\[
g(Basic)=Basic
\]

\[
g(Deluxe)=Deluxe
\]

\[
g(Premium)=Premium
\]

The default arm \(G\) includes both:

1. traffic from the 90% rules-based wing assigned to the complexity-matched default price, and
2. traffic from the 10% price-randomization wing that happens to be randomized to the complexity-matched default price.

The holdout arm \(H\) includes holdout traffic from both the 90% and 10% wings.

The message-only arm \(M\) includes message-only traffic from both the 90% and 10% wings.

The two off-default randomized price arms \(R_1\) and \(R_2\) come only from the 10% price-randomization wing.

## Planned tests after aggregation

Within each cohort-complexity cell, run exactly these 8 pairwise tests:

1. \(G\) vs \(H\)
2. \(G\) vs \(M\)
3. \(R_1\) vs \(H\)
4. \(R_1\) vs \(M\)
5. \(R_1\) vs \(G\)
6. \(R_2\) vs \(H\)
7. \(R_2\) vs \(M\)
8. \(R_2\) vs \(G\)

Do not include \(R_1\) vs \(R_2\). We are not interested in that comparison for this sizing exercise.

There are 5 cohorts, 3 complexities, and 8 tests per cell:

\[
5 \times 3 \times 8 = 120
\]

We also want to bake in additional conservativeness for 2-by-2 heterogeneity checks and average-effect tests. Therefore multiply the base test count by 5:

\[
m = 120 \times 5 = 600
\]

Use \(m=600\) as the default Bonferroni family size per binary outcome unless I explicitly override it.

For two-sided 5% family-wise size and 80% power:

\[
z^* = z_{1-\alpha/(2m)} + z_{0.80}
\]

where:

\[
\alpha=0.05
\]

\[
power=0.80
\]

In Excel notation:

```excel
=NORM.S.INV(1 - Alpha/(2*NumTests)) + NORM.S.INV(Power)
```

## Equal-size simplification for final collapsed arms

Use the following default equal-size simplification unless I explicitly ask for unequal optimal allocation:

\[
e_H=e_M=h
\]

\[
e_{R_1}=e_{R_2}=r
\]

\[
e_G=d
\]

The five final analysis shares satisfy:

\[
d+2h+2r=1
\]

so:

\[
d=1-2h-2r
\]

Equal sizing is a default because the four smaller analysis arms are symmetrically important for the planned comparisons. It gives a simple minimax-style allocation where holdout, message-only, randomized price 1, and randomized price 2 have comparable precision. If any comparison or arm is later judged more important, we can revisit unequal sizing.

## Worst-case binary-outcome MDE formulas

Use worst-case binary variance:

\[
q(1-q)\leq 0.25
\]

For any comparison between arms \(a\) and \(b\) in a cell of size \(N_{c,h}\):

\[
MDE_{c,h,a,b}
=
z^*
\sqrt{
\frac{0.25}{N_{c,h}}
\left(
\frac{1}{e_a}+\frac{1}{e_b}
\right)
}
\]

Given the equal-size simplification, there are only three unique MDE values.

### Default vs holdout or message-only

\[
MDE_{G,H}=MDE_{G,M}
=
z^*
\sqrt{
\frac{0.25}{N_{c,h}}
\left(
\frac{1}{d}+\frac{1}{h}
\right)
}
\]

### Randomized off-default price vs holdout or message-only

\[
MDE_{R,H}=MDE_{R,M}
=
z^*
\sqrt{
\frac{0.25}{N_{c,h}}
\left(
\frac{1}{r}+\frac{1}{h}
\right)
}
\]

### Randomized off-default price vs default

\[
MDE_{R,G}
=
z^*
\sqrt{
\frac{0.25}{N_{c,h}}
\left(
\frac{1}{r}+\frac{1}{d}
\right)
}
\]

These three MDE values cover all 8 planned tests because \(H\) and \(M\) are equally sized, and \(R_1\) and \(R_2\) are equally sized.

## Share-sizing threshold

For a target absolute MDE \(\delta\), define a share-sizing threshold:

\[
T_{c,h}(\delta)
=
\frac{N_{c,h}\delta^2}{0.25(z^*)^2}
\]

This threshold comes from rearranging the MDE equation. For a comparison between two arms \(a,b\), hitting the target MDE requires:

\[
\frac{1}{e_a}+\frac{1}{e_b}\leq T_{c,h}(\delta)
\]

The left side is the inverse-share penalty. It is large when either arm is small. The threshold \(T_{c,h}(\delta)\) is larger when the cell size is larger or the MDE target is looser, and smaller when the Bonferroni multiplier is larger.

Under the equal-size simplification, the binding small-arm comparison is usually \(R\) vs \(H\) or \(R\) vs \(M\):

\[
\frac{1}{r}+\frac{1}{h}\leq T_{c,h}(\delta)
\]

With \(h=r\), this implies:

\[
h=r=\frac{2}{T_{c,h}(\delta)}
\]

and:

\[
d=1-\frac{8}{T_{c,h}(\delta)}
\]

Use these as the default final collapsed shares for each cohort-complexity cell and target MDE.

## Feasibility checks

For each cohort-complexity cell and MDE target, check:

1. \(h>0\)
2. \(r>0\)
3. \(d>0\)
4. \(r\leq 0.05\), because both off-default randomized prices must fit inside the 10% price-randomization wing:
   \[
   2r\leq 0.10
   \]
5. All derived branch shares must be between 0 and 1.
6. Recomputed MDEs must be less than or equal to the target MDE.

If any condition fails, mark the MDE target as infeasible for that cohort-complexity cell.

A target MDE is feasible for a cohort only if it is feasible for all three complexity cells in that cohort. Also report whether it is globally feasible across all cohorts and complexities.

## Mapping final analysis shares back to 90/10 routing

We need to report stakeholder-facing 90% and 10% routing tables aggregated across complexity.

### 90% rules-based wing

Within the 90% rules-based wing, define:

\[
a = \text{share of the 90% wing assigned to default price}
\]

\[
b = \text{share of the 90% wing assigned to holdout}
\]

\[
b = \text{share of the 90% wing assigned to message-only}
\]

So:

\[
a+2b=1
\]

### 10% price-randomization wing

Within the 10% price-randomization wing, define:

\[
q_0 = \text{share of the 10% wing assigned to the complexity-matched default price}
\]

\[
u = \text{share of the 10% wing assigned to holdout}
\]

\[
u = \text{share of the 10% wing assigned to message-only}
\]

\[
q = \text{share of the 10% wing assigned to off-default randomized price 1}
\]

\[
q = \text{share of the 10% wing assigned to off-default randomized price 2}
\]

So:

\[
q_0+2u+2q=1
\]

The collapsed final analysis shares are:

\[
d=0.90a+0.10q_0
\]

\[
h=0.90b+0.10u
\]

\[
r=0.10q
\]

Therefore:

\[
q=10r
\]

and:

\[
q_0+2u=1-20r
\]

There is one remaining degree of freedom in how the 10% branch's leftover share \(1-20r\) is split between default, holdout, and message-only.

Use this default decomposition rule unless I override it:

\[
u=q_0=\frac{1-20r}{3}
\]

Then:

\[
b=\frac{h-0.10u}{0.90}
\]

\[
a=1-2b
\]

Check that:

\[
a+2b=1
\]

\[
q_0+2u+2q=1
\]

\[
0\leq a,b,q_0,u,q\leq 1
\]

## Cohort-level aggregated MDEs

Although sizing is done at the cohort-complexity level, the stakeholder summary should also show cohort-level aggregate precision after collapsing across complexity.

For each cohort \(c\), define known complexity weights:

\[
\pi_{c,h}
\]

For an average effect comparing arm \(A\) to arm \(B\) across complexities:

\[
\Delta_{c,A,B}
=
\sum_h \pi_{c,h}\left(q_{c,h,A}-q_{c,h,B}\right)
\]

The worst-case variance is:

\[
Var(\hat{\Delta}_{c,A,B})
\leq
0.25
\sum_h
\pi_{c,h}^2
\left(
\frac{1}{n_{c,h,A}}+
\frac{1}{n_{c,h,B}}
\right)
\]

where:

\[
n_{c,h,A}=N_{c,h}e_{c,h,A}
\]

The cohort-level aggregate MDE is:

\[
MDE_{c,A,B}^{agg}
=
z^*
\sqrt{
0.25
\sum_h
\pi_{c,h}^2
\left(
\frac{1}{n_{c,h,A}}+
\frac{1}{n_{c,h,B}}
\right)
}
\]

Compute these cohort-level aggregate MDEs:

1. Aggregated \(G\) vs \(H\)
2. Aggregated \(G\) vs \(M\)
3. Aggregated \(R\) vs \(H\)
4. Aggregated \(R\) vs \(M\)
5. Aggregated \(R\) vs \(G\)

Because \(R_1\) and \(R_2\) are equally sized, report a generic \(R\) result unless there are differences induced by price-tier mapping. Do not report \(R_1\) vs \(R_2\).

These cohort-level aggregate MDEs are the main stakeholder-facing precision summaries.

## Stakeholder-facing aggregation across complexity

The final share-out should not be reported by complexity. It should be reported by cohort.

For each cohort and selected MDE, produce two concise tables:

1. 90% rules-based wing allocation table.
2. 10% price-randomization wing allocation table.

### 90% rules-based wing report

This table is within the 90% wing. Its denominator is:

\[
0.90N_c
\]

Rows:

1. Holdout
2. Message-only
3. Default Basic if Basic complexity
4. Default Deluxe if Deluxe complexity
5. Default Premium if Premium complexity

If branch shares \(a,b\) vary by complexity, use:

\[
Share^{90}_{c,H}=\sum_h \pi_{c,h}b_{c,h}
\]

\[
Share^{90}_{c,M}=\sum_h \pi_{c,h}b_{c,h}
\]

\[
Share^{90}_{c,BasicDefault}=\pi_{c,Basic}a_{c,Basic}
\]

\[
Share^{90}_{c,DeluxeDefault}=\pi_{c,Deluxe}a_{c,Deluxe}
\]

\[
Share^{90}_{c,PremiumDefault}=\pi_{c,Premium}a_{c,Premium}
\]

These rows should sum to 1 within the 90% wing.

Counts are:

\[
Count^{90}_{c,row}=0.90N_c \times Share^{90}_{c,row}
\]

Total-cohort share is:

\[
TotalShare^{90}_{c,row}=0.90 \times Share^{90}_{c,row}
\]

### 10% price-randomization wing report

This table is within the 10% wing. Its denominator is:

\[
0.10N_c
\]

Rows:

1. Holdout
2. Message-only
3. Basic price
4. Deluxe price
5. Premium price

The price rows are aggregated across complexity using the actual price tier assigned in the 10% branch.

If \(q_0,u,q\) vary by complexity, use:

\[
Share^{10}_{c,H}=\sum_h \pi_{c,h}u_{c,h}
\]

\[
Share^{10}_{c,M}=\sum_h \pi_{c,h}u_{c,h}
\]

\[
Share^{10}_{c,BasicPrice}
=
\pi_{c,Basic}q_{0,c,Basic}
+
\pi_{c,Deluxe}q_{c,Deluxe}
+
\pi_{c,Premium}q_{c,Premium}
\]

\[
Share^{10}_{c,DeluxePrice}
=
\pi_{c,Basic}q_{c,Basic}
+
\pi_{c,Deluxe}q_{0,c,Deluxe}
+
\pi_{c,Premium}q_{c,Premium}
\]

\[
Share^{10}_{c,PremiumPrice}
=
\pi_{c,Basic}q_{c,Basic}
+
\pi_{c,Deluxe}q_{c,Deluxe}
+
\pi_{c,Premium}q_{0,c,Premium}
\]

These rows should sum to 1 within the 10% wing.

Counts are:

\[
Count^{10}_{c,row}=0.10N_c \times Share^{10}_{c,row}
\]

Total-cohort share is:

\[
TotalShare^{10}_{c,row}=0.10 \times Share^{10}_{c,row}
\]

## Output behavior

For now, do not create or update workbook result tabs.

Instead:

1. Print a concise result table for the visible MDE grid.
2. Summarize results at the cohort level, aggregated across complexities.
3. Do not print long cohort-by-complexity detail tables unless I ask.
4. Keep the detailed cohort-complexity grid and fine-grid calculations available in the active session for follow-up questions.
5. After printing the review tables, ask how I want to use the results:
   - export to Excel,
   - write result tabs into the workbook,
   - adjust the MDE grid,
   - change the test multiplier,
   - change the 90/10 routing rule,
   - or inspect a particular cohort or MDE target.

## Printed review tables

Print these tables.

### Table 1: Global setup

- Alpha
- Power
- Base tests = 120
- Test multiplier = 5
- Bonferroni tests used = 600
- Bonferroni \(z^*\)
- Visible MDE grid
- Internal fine grid
- Smallest cohort-complexity cell size

### Table 2: Feasibility by visible MDE

One row per visible MDE.

Columns:

- Target MDE
- Feasible globally?
- Number of feasible cohort-complexity cells
- Smallest default share \(d\)
- Largest holdout/message share \(h\)
- Largest randomized price share \(r\)
- Binding feasibility reason, if any

### Table 3: Cohort-level stakeholder summary by MDE

One row per cohort and visible MDE.

Columns:

- Cohort
- Target MDE
- Feasible for all complexities in cohort?
- Aggregated MDE \(G\) vs \(H\)
- Aggregated MDE \(G\) vs \(M\)
- Aggregated MDE \(R\) vs \(H\)
- Aggregated MDE \(R\) vs \(M\)
- Aggregated MDE \(R\) vs \(G\)
- Total holdout share of cohort
- Total message-only share of cohort
- Total default price share of cohort
- Total randomized off-default price share of cohort

### Table 4: Recommended stakeholder routing tables

For a selected MDE target, or for the smallest visible feasible MDE if no selected target is provided, print for each cohort:

A. 90% rules-based wing table

Rows:

- Holdout
- Message-only
- Default Basic if Basic complexity
- Default Deluxe if Deluxe complexity
- Default Premium if Premium complexity

Columns:

- Share within 90% wing
- Share of total cohort
- Count

B. 10% price-randomization wing table

Rows:

- Holdout
- Message-only
- Basic price
- Deluxe price
- Premium price

Columns:

- Share within 10% wing
- Share of total cohort
- Count

Keep this concise. Do not print every cohort-complexity row.

## Important interpretation notes

Include these notes in the printed summary:

1. Power is sized at the cohort-complexity level.
2. Stakeholder tables are aggregated across complexity and are routing summaries.
3. The default analysis arm includes both 90% wing default traffic and 10% wing traffic randomized to the complexity-matched default price.
4. Holdout and message-only analysis arms include traffic from both wings.
5. Off-default randomized price arms come only from the 10% wing.
6. The reported cohort-level MDEs are aggregated average-effect MDEs across complexities using known complexity shares.
7. MDEs are absolute percentage-point effects unless the user provides baseline rates for index or lift conversion.
8. Do not include \(R_1\) vs \(R_2\) comparisons.

## Do not do these things

- Do not write results into the workbook unless explicitly asked.
- Do not print a long table for every cohort-complexity cell.
- Do not include \(R_1\) vs \(R_2\) in the test count or output.
- Do not silently change the 90/10 routing rule.
- Do not treat stakeholder routing rows as the same thing as collapsed analysis arms.
