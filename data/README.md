# Figure data

Each CSV here feeds an R chunk that draws a figure in the book. To update a
figure, add the new year's row to its CSV and push; the build redraws it.

| File | Figure | Chapter | Source |
|---|---|---|---|
| `c4_trial_rates.csv` | `fig-trial-rate` | Trial & Appeal | AO *Judicial Business* tbl. C-4 (total row, Sept. 30) |
| `c4_trial_rates_1962_1996.csv` | `fig-trial-rate` | Trial & Appeal | AO *Annual Report of the Director* tbl. C-4 (total row; June 30 through 1991, Sept. 30 from 1992; 1993 not located). Each row gives the scan it came from (HathiTrust or Internet Archive) and any OCR corrections |
| `aic_threshold.csv` | `fig-aic` | Subject Matter Jurisdiction | 28 U.S.C. § 1332 amendment notes; FJC history; Minneapolis Fed CPI |
| `removal_share.csv` | `fig-removal` | Subject Matter Jurisdiction | AO *Judicial Business* tbl. S-7 (1997–2010) and C-8 (2011–2025), "Civil Cases Filed, by Origin" (Sept. 30), each year from the latest edition reporting it |
| `cafa_fjc_2008.csv` | `fig-cafa` | Aggregation | Lee & Willging, FJC, *CAFA Fourth Interim Report* (Apr. 2008), at 6 (monthly averages stated in the text; the report gives its series only as charts) (one-time study) |
| `mdl_share.csv` | `fig-mdl-share` | Aggregation | AO *Judicial Business* tbls. S-20 and C-1 (Sept. 30) |
| `jpml_pending_mdls.csv`, `jpml_districts.csv` | `fig-mdl-map` (drawn by `maps/make_mdl_map.R`; commit the PNG) | Aggregation | JPML *MDL Statistics Report*, pending dockets by district, by actions pending, and by MDL number (Nov. 2, 2026), <https://www.jpml.uscourts.gov/node/375>; district plotting cities from the Census 2024 Gazetteer (internal points), noted per row |
| `prose_share.csv` | `fig-prose` | What Is Procedure? | AO *Judicial Business* tbl. C-13 (S-23/S-24 before 2011) |
| `reversal_by_circuit.csv` | `fig-reversal` | Trial & Appeal | AO *Judicial Business* tbl. B-5, other private civil, pooled |
| `mtd_fjc_2011.csv` | `fig-mtd` | Pleadings | Cecil et al., FJC (2011), tbl. 4 (one-time study) |
| `sj_fjc_2007.csv` | `fig-sj-trends` | Avoiding Trial | Cecil, Eyre, Miletich & Rindskopf, FJC (2007), fig. 1 at 8; values measured from the vector chart, matching the figures stated in the text (one-time study) |
| `discovery_costs_fjc_2009.csv` | `fig-discovery-costs` | Discovery | Lee & Willging, FJC Civil Rules Survey (2009), tbls. 4, 5, 10 (one-time study) |
| `scott_harris_kahan.csv` | `fig-scott-harris` | Avoiding Trial | Kahan, Hoffman & Braman, 122 Harv. L. Rev. 837, 868 tbl.1 (one-time study) |
| `pj_cases.csv` | `fig-pj-timeline` | Personal Jurisdiction | The cases reproduced in the chapter |
| `arbitration_colvin_2017.csv` | `fig-arbitration` | Avoiding Trial | Colvin, EPI (2018), at 2, 11 (one-time study) |

## Figure style

- `theme_classic(base_size = 11)`: no gridlines, black ink, 6.5 inches wide.
- Yearly values are points, not connected lines.
- With a LOESS curve, draw the points at `alpha = 0.5`; the curve is black,
  `linewidth = 0.8`, with no confidence band (`se = FALSE`).
- Use robust LOESS (`method.args = list(family = "symmetric")`) when an
  outlier is a recording artifact; use ordinary LOESS when extreme points
  reflect a real event.
- The caption names the fit, explains any anomaly, and cites the source.
