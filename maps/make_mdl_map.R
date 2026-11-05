# Draw the map of pending MDL dockets by transferee district
# (maps/mdl_districts.png) from data/jpml_pending_mdls.csv and
# data/jpml_districts.csv, which come from the JPML's monthly "Distribution of
# Pending MDL Dockets by District" report (see data/README.md). Needs sf,
# tigris, ggplot2 and ggrepel. Run from the repo root:
#   Rscript maps/make_mdl_map.R
# Commit the PNG; the GitHub build uses it and never runs this script.
suppressPackageStartupMessages({
  library(sf)
  library(ggplot2)
})
options(tigris_use_cache = TRUE)

crs <- 5070 # Albers equal-area, lower 48
states <- tigris::states(cb = TRUE, resolution = "20m", progress_bar = FALSE)
states <- st_transform(states[!states$STUSPS %in% c("AK", "HI", "PR", "VI", "GU", "MP", "AS"), ], crs)

mdls <- read.csv("data/jpml_pending_mdls.csv")
districts <- read.csv("data/jpml_districts.csv")
districts <- districts[districts$pending_actions > 0, ]
xy <- st_coordinates(st_transform(st_as_sf(districts, coords = c("lon", "lat"), crs = 4326), crs))
districts$x <- xy[, 1]
districts$y <- xy[, 2]

# Short names for the largest MDLs, used to label their districts.
short <- c(
  "2738" = "talc", "2789" = "heartburn drugs", "2846" = "hernia mesh",
  "2873" = "firefighting foam", "3060" = "hair relaxers", "2666" = "Bair Hugger",
  "3004" = "paraquat", "2570" = "IVC filters", "3140" = "Depo-Provera",
  "3084" = "Uber", "3047" = "social media"
)
mdls <- mdls[order(-mdls$pending_actions), ]
proj <- function(lon, lat) {
  st_coordinates(st_transform(st_sfc(st_multipoint(cbind(lon, lat)), crs = 4326), crs))[, 1:2, drop = FALSE]
}

# The nine districts with the most pending actions, each labeled with its
# largest MDLs; lx, ly (lon/lat) place each label in open space on the map.
top <- head(districts[order(-districts$pending_actions), ], 9)
spots <- data.frame(
  district = c("D.N.J.", "S.D. Ohio", "D.S.C.", "N.D. Ill.", "N.D. Cal.", "D. Minn.",
               "S.D. Ill.", "S.D. Ind.", "N.D. Fla."),
  lx = c(-73.6, -81.5, -76.6, -96.5, -118.5, -100.5, -98.5, -85.6, -91.0),
  ly = c(36.9, 45.6, 30.4, 42.8, 41.6, 47.4, 38.4, 35.9, 28.4),
  hj = 0.5
)
stopifnot(setequal(spots$district, top$district))
top <- merge(top, spots)
top$label <- vapply(seq_len(nrow(top)), function(i) {
  d <- mdls[mdls$district == top$district[i] & as.character(mdls$mdl_number) %in% names(short), ]
  d <- head(d[d$pending_actions >= 1000, ], 2)
  sprintf("%s: %s\n%s pending", top$district[i],
          paste(short[as.character(d$mdl_number)], collapse = ", "),
          format(top$pending_actions[i], big.mark = ","))
}, "")
lxy <- proj(top$lx, top$ly)
top$lxp <- lxy[, 1]
top$lyp <- lxy[, 2]
districts <- districts[order(-districts$pending_actions), ] # small bubbles on top

p <- ggplot() +
  geom_sf(data = states, fill = "grey95", colour = "grey60", linewidth = 0.25) +
  geom_segment(data = top, aes(x = lxp, y = lyp, xend = x, yend = y),
               colour = "grey35", linewidth = 0.3) +
  geom_point(data = districts, aes(x, y, size = pending_actions),
             shape = 21, fill = "#D55E00", colour = "grey15", alpha = 0.75, stroke = 0.3) +
  geom_label(data = top, aes(lxp, lyp, label = label), size = 2.5,
             lineheight = 0.95, fill = "white", label.size = 0,
             label.padding = unit(0.12, "lines")) +
  scale_size_area(max_size = 15, breaks = c(1000, 10000, 50000),
                  labels = c("1,000", "10,000", "50,000"),
                  name = "Pending actions") +
  coord_sf(crs = crs, datum = NA) +
  theme_void(base_size = 10) +
  theme(legend.position = "bottom", legend.title = element_text(size = 9))

ggsave("maps/mdl_districts.png", p, width = 6.5, height = 4.4, dpi = 200, bg = "white")
cat("Wrote maps/mdl_districts.png:", nrow(districts), "districts,",
    sum(districts$pending_actions), "pending actions\n")
