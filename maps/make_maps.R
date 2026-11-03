# Draw the personal-jurisdiction case maps (maps/*.png) from Census state
# boundaries. Needs sf, tigris, ggplot2 and ggrepel, and a network connection
# the first time (tigris caches the shapes). Run from the repo root:
#   Rscript maps/make_maps.R
# Commit the PNGs; the GitHub build uses them and never runs this script.
# Every place on a map comes from the facts in the excerpted opinion; the
# figure captions in personal_jurisdiction.qmd carry the details.
suppressPackageStartupMessages({
  library(sf)
  library(ggplot2)
})
options(tigris_use_cache = TRUE)

crs <- 5070 # Albers equal-area, lower 48
states <- tigris::states(cb = TRUE, resolution = "20m", progress_bar = FALSE)
states <- states[!states$STUSPS %in% c("AK", "HI", "PR", "VI", "GU", "MP", "AS"), ]
states <- st_transform(states, crs)

# Okabe-Ito, as in the chapter's timeline
forum_fill <- "#D55E00" # the forum State
other_fill <- "#56B4E9" # other States in the story
ink <- "grey15"

# Project lon/lat to map coordinates.
proj <- function(lon, lat) {
  st_coordinates(st_transform(st_sfc(st_multipoint(cbind(lon, lat)), crs = 4326), crs))[, 1:2, drop = FALSE]
}

# Text with a white halo, so it reads over any fill.
halo <- function(...) {
  ggrepel::geom_text_repel(..., colour = "black", bg.colour = "white", bg.r = 0.15,
                           lineheight = 0.95, seed = 1, max.overlaps = Inf)
}

# places: name, lon, lat, label, nudge_x, nudge_y (km; where the label starts)
# arrows: from, to (place names), curvature, dashed, label, lx, ly (label lon/lat)
draw_map <- function(file, forum, others, places, arrows = NULL,
                     xlim = NULL, ylim = NULL, height = 4.2) {
  st <- states
  st$role <- ifelse(st$STUSPS %in% forum, "forum",
                    ifelse(st$STUSPS %in% others, "other", "none"))
  xy <- proj(places$lon, places$lat)
  places$x <- xy[, 1]; places$y <- xy[, 2]

  p <- ggplot() +
    geom_sf(data = st, aes(fill = role), colour = "white", linewidth = 0.3) +
    scale_fill_manual(values = c(forum = forum_fill, other = other_fill, none = "grey88"),
                      guide = "none")

  if (!is.null(arrows)) {
    a <- merge(merge(arrows, setNames(places[, c("name", "x", "y")], c("from", "x", "y"))),
               setNames(places[, c("name", "x", "y")], c("to", "xend", "yend")))
    for (i in seq_len(nrow(a))) {
      p <- p + geom_curve(data = a[i, ], aes(x = x, y = y, xend = xend, yend = yend),
                          curvature = a$curvature[i], colour = ink, linewidth = 0.6,
                          linetype = if (a$dashed[i]) "22" else "solid",
                          arrow = arrow(length = unit(0.09, "inches"), type = "closed"))
    }
    lab <- a[!is.na(a$label) & a$label != "", ]
    if (nrow(lab)) {
      lxy <- proj(lab$lx, lab$ly)
      lab$x <- lxy[, 1]; lab$y <- lxy[, 2]
      p <- p + halo(data = lab, aes(x = x, y = y, label = label), size = 2.9,
                    fontface = "italic", min.segment.length = Inf, force = 0)
    }
  }

  p <- p + geom_point(data = places, aes(x = x, y = y), size = 2, colour = "black")
  pl <- places[places$label != "", ]
  p <- p + halo(data = pl, aes(x = x, y = y, label = label), size = 3.2,
                nudge_x = pl$nudge_x * 1e3, nudge_y = pl$nudge_y * 1e3,
                min.segment.length = 0.3, segment.colour = "grey40", segment.size = 0.3,
                box.padding = 0.2, point.padding = 0.25, force = 0.3)

  # Frame: the given lon/lat box (or the lower 48), padded and widened to the
  # page's shape.
  if (is.null(xlim)) {
    bb <- st_bbox(states)
    lx <- bb[c("xmin", "xmax")]; ly <- bb[c("ymin", "ymax")]
  } else {
    g <- proj(rep(xlim, 2), rep(ylim, each = 2))
    lx <- range(g[, 1]); ly <- range(g[, 2])
  }
  lx <- lx + c(-1, 1) * 0.03 * diff(lx); ly <- ly + c(-1, 1) * 0.06 * diff(ly)
  want <- 6.5 / height
  if (diff(lx) / diff(ly) < want) {
    lx <- mean(lx) + c(-1, 1) * diff(ly) * want / 2
  } else {
    ly <- mean(ly) + c(-1, 1) * diff(lx) / want / 2
  }
  p <- p + coord_sf(xlim = lx, ylim = ly, expand = FALSE, crs = crs, datum = NA) +
    theme_void(base_size = 11) + theme(plot.margin = margin(0, 0, 0, 0))
  ggsave(file, p, width = 6.5, height = height, dpi = 200, bg = "white")
  message("wrote ", file)
}

P <- function(...) data.frame(..., stringsAsFactors = FALSE)
A <- function(...) data.frame(..., stringsAsFactors = FALSE)

# International Shoe Co. v. Washington ---------------------------------------
draw_map("maps/international_shoe.png", forum = "WA", others = c("MO", "DE"),
  places = P(
    name    = c("wa", "stl", "de"),
    lon     = c(-120.5, -90.20, -75.53),
    lat     = c(47.4, 38.63, 39.16),
    label   = c("Washington\nsalesmen solicit orders", "St. Louis\nheadquarters",
                "Delaware\nincorporated"),
    nudge_x = c(150, 0, 200), nudge_y = c(-250, -220, -150)),
  arrows = A(from = "wa", to = "stl", curvature = -0.25, dashed = FALSE,
             label = "orders sent to St. Louis", lx = -103.5, ly = 43.2))

# Hanson v. Denckla -----------------------------------------------------------
draw_map("maps/hanson.png", forum = "FL", others = c("PA", "DE"),
  places = P(
    name    = c("pa", "de", "fl"),
    lon     = c(-77.6, -75.53, -81.6),
    lat     = c(40.9, 39.16, 28.4),
    label   = c("Pennsylvania\nDonner creates the trust", "Delaware\nthe trustee",
                "Florida\nDonner's later home;\nprobate suit"),
    nudge_x = c(-250, 250, -600), nudge_y = c(150, -80, -60)),
  arrows = A(from = c("pa", "pa"), to = c("de", "fl"), curvature = c(-0.4, 0.35),
             dashed = c(TRUE, FALSE), label = c("", "Donner moves"),
             lx = c(NA, -84.6), ly = c(NA, 34.6)),
  xlim = c(-90, -70), ylim = c(24.5, 43.5), height = 4.6)

# World-Wide Volkswagen Corp. v. Woodson -------------------------------------
draw_map("maps/world_wide_volkswagen.png", forum = "OK", others = c("NY", "NJ", "CT"),
  places = P(
    name    = c("massena", "creek", "az"),
    lon     = c(-74.89, -96.11, -111.7),
    lat     = c(44.93, 35.99, 34.3),
    label   = c("Massena, N.Y.\nAudi bought", "Creek County, Okla.\ncrash; suit",
                "Arizona\nnew home"),
    nudge_x = c(0, 0, 0), nudge_y = c(220, -220, -200)),
  arrows = A(from = c("massena", "creek"), to = c("creek", "az"), curvature = c(0.15, 0.1),
             dashed = c(FALSE, TRUE), label = "", lx = NA, ly = NA))

# Burger King Corp. v. Rudzewicz ---------------------------------------------
draw_map("maps/burger_king.png", forum = "FL", others = "MI",
  places = P(
    name    = c("dp", "bham", "miami"),
    lon     = c(-83.38, -83.21, -80.19),
    lat     = c(42.69, 42.55, 25.76),
    label   = c("Drayton Plains, Mich.\nthe franchise", "Birmingham, Mich.\ndistrict office",
                "Miami\nheadquarters"),
    nudge_x = c(-300, 300, -250), nudge_y = c(80, -60, 0)),
  arrows = A(from = "dp", to = "miami", curvature = -0.25, dashed = FALSE,
             label = "payments and\nnotices to Miami", lx = -77.6, ly = 34.2),
  xlim = c(-90, -72), ylim = c(24.5, 46), height = 4.6)

# Walden v. Fiore -------------------------------------------------------------
draw_map("maps/walden.png", forum = "NV", others = c("GA", "CA"),
  places = P(
    name    = c("atl", "lv"),
    lon     = c(-84.43, -115.14),
    lat     = c(33.64, 36.17),
    label   = c("Atlanta airport\nthe seizure", "Las Vegas\nthe destination"),
    nudge_x = c(0, 0), nudge_y = c(-220, 260)),
  arrows = A(from = c("atl", "lv"), to = c("lv", "atl"), curvature = c(-0.2, -0.2),
             dashed = c(FALSE, TRUE),
             label = c("flight on to Las Vegas", "Nevada attorney's calls\nand documents"),
             lx = c(-99.5, -100.5), ly = c(31.0, 40.0)))

# Ford Motor Co. v. Montana Eighth Judicial District Court -------------------
draw_map("maps/ford.png", forum = c("MT", "MN"), others = c("MI", "KY", "WA", "ND"),
  places = P(
    name    = c("mi", "ky", "wa", "mt", "can", "nd", "mn"),
    lon     = c(-84.7, -85.3, -120.5, -109.6, -81.6, -100.4, -94.3),
    lat     = c(43.6, 37.5, 47.4, 46.9, 43.4, 47.5, 45.6),
    label   = c("Michigan\ndesigned", "Kentucky\nExplorer built", "Washington\nExplorer sold",
                "Montana\nExplorer crash", "Canada\nCrown Victoria built",
                "North Dakota\nCrown Victoria sold", "Minnesota\nCrown Victoria crash"),
    nudge_x = c(-150, 0, 0, 0, 250, -50, 100), nudge_y = c(-150, -200, -220, -230, 120, 220, -220)),
  arrows = A(from = c("mi", "ky", "wa", "mi", "can", "nd"),
             to   = c("ky", "wa", "mt", "can", "nd", "mn"),
             curvature = c(0.2, 0.15, -0.3, -0.4, 0.25, -0.3),
             dashed = c(FALSE, FALSE, TRUE, FALSE, FALSE, TRUE),
             label = "", lx = NA, ly = NA))

# Mallory v. Norfolk Southern Railway Co. ------------------------------------
draw_map("maps/mallory.png", forum = "PA", others = c("OH", "VA"),
  places = P(
    name    = c("oh", "va", "pa", "norfolk"),
    lon     = c(-82.8, -79.2, -77.6, -76.29),
    lat     = c(40.3, 37.5, 40.9, 36.85),
    label   = c("Ohio\nMallory works here first", "Virginia\nworks here later; home when he sues",
                "Pennsylvania\nthe suit", "Norfolk Southern\nheadquarters"),
    nudge_x = c(-150, -120, 0, 180), nudge_y = c(90, -150, 130, -80)),
  arrows = A(from = "oh", to = "va", curvature = 0.3, dashed = FALSE,
             label = "", lx = NA, ly = NA),
  xlim = c(-87, -72), ylim = c(35.2, 43.3), height = 4.2)
