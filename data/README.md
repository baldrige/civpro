# Figure data

Each CSV here feeds an R chunk that draws a figure in the book. To update a
figure, add the new year's row to its CSV and push; the build redraws it.

| File | Figure | Chapter | Source |
|---|---|---|---|
| `c4_trial_rates.csv` | `fig-trial-rate` | Trial & Appeal | AO *Judicial Business* tbl. C-4 (total row, Sept. 30) |
| `aic_threshold.csv` | `fig-aic` | Subject Matter Jurisdiction | 28 U.S.C. § 1332 amendment notes; FJC history; Minneapolis Fed CPI |
| `mdl_share.csv` | `fig-mdl-share` | Aggregation | AO *Judicial Business* tbls. S-20 and C-1 (Sept. 30) |
| `prose_share.csv` | `fig-prose` | What Is Procedure? | AO *Judicial Business* tbl. C-13 (S-23/S-24 before 2011) |
| `reversal_by_circuit.csv` | `fig-reversal` | Trial & Appeal | AO *Judicial Business* tbl. B-5, other private civil, pooled |
| `mtd_fjc_2011.csv` | `fig-mtd` | Pleadings | Cecil et al., FJC (2011), tbl. 4 (one-time study) |

## Figure style

- `theme_classic(base_size = 11)`: no gridlines, black ink, 6.5 inches wide.
- Yearly values are points, not connected lines.
- With a LOESS curve, draw the points at `alpha = 0.5`; the curve is black,
  `linewidth = 0.8`, with no confidence band (`se = FALSE`).
- Use robust LOESS (`method.args = list(family = "symmetric")`) when an
  outlier is a recording artifact; use ordinary LOESS when extreme points
  reflect a real event.
- The caption names the fit, explains any anomaly, and cites the source.
