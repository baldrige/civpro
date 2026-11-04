# Draw the personal-jurisdiction case maps (maps/*.png) from Census state
# boundaries and, for the international cases, Natural Earth country
# boundaries. Needs sf, tigris, ggplot2, ggrepel, rnaturalearth and
# rnaturalearthdata, and a network connection the first time (tigris caches
# the shapes). Run from the repo root:
#   Rscript maps/make_maps.R
# Commit the PNGs; the GitHub build uses them and never runs this script.
# Every place on a map comes from the facts in the excerpted opinion; the
# figure captions in personal_jurisdiction.qmd carry the details.
suppressPackageStartupMessages({
  library(sf)
  library(ggplot2)
})
options(tigris_use_cache = TRUE)

# Optional arguments name the maps to redraw (e.g. `Rscript maps/make_maps.R asahi`).
only <- commandArgs(trailingOnly = TRUE)

crs <- 5070 # Albers equal-area, lower 48
all_states <- tigris::states(cb = TRUE, resolution = "20m", progress_bar = FALSE)
all_states <- st_transform(all_states[!all_states$STUSPS %in% c("PR", "VI", "GU", "MP", "AS"), ], 4326)
states <- st_transform(all_states[!all_states$STUSPS %in% c("AK", "HI"), ], crs)
countries <- rnaturalearth::ne_countries(scale = 50, returnclass = "sf")[, c("adm0_a3", "geometry")]

# Okabe-Ito, as in the chapter's timeline
forum_fill <- "#D55E00" # the forum State
other_fill <- "#56B4E9" # other States in the story
ink <- "grey15"

# Project lon/lat to map coordinates.
proj <- function(lon, lat, to = crs) {
  st_coordinates(st_transform(st_sfc(st_multipoint(cbind(lon, lat)), crs = 4326), to))[, 1:2, drop = FALSE]
}

# World base for the international cases: countries in `nations` (ISO3) and
# the US States in `forum`/`others` are filled; the rest of the world is grey.
# The map is cut at the meridian opposite lon_0 so nothing wraps.
world_base <- function(lon_0, forum, others, nations) {
  old <- sf_use_s2(FALSE); on.exit(sf_use_s2(old))
  wcrs <- sprintf("+proj=robin +lon_0=%s +datum=WGS84", lon_0)
  cut <- function(x) st_transform(suppressWarnings(st_break_antimeridian(x, lon_0 = lon_0)), wcrs)
  w <- cut(countries)
  w$role <- ifelse(w$adm0_a3 %in% nations, "other", "none")
  s <- all_states[all_states$STUSPS %in% c(forum, others), ]
  s <- cut(s)
  s$role <- ifelse(s$STUSPS %in% forum, "forum", "other")
  list(crs = wcrs, layers = list(w[, "role"], s[, "role"]))
}

# Text with a white halo, so it reads over any fill.
halo <- function(...) {
  ggrepel::geom_text_repel(..., colour = "black", bg.colour = "white", bg.r = 0.15,
                           lineheight = 0.95, seed = 1, max.overlaps = Inf)
}

# places: name, lon, lat, label, nudge_x, nudge_y (km; where the label starts)
# arrows: from, to (place names), curvature, dashed, label, lx, ly (label lon/lat)
draw_map <- function(file, forum, others, places, arrows = NULL,
                     xlim = NULL, ylim = NULL, height = 4.2, world = NULL,
                     notes = NULL) {
  if (length(only) && !sub("[.]png$", "", basename(file)) %in% only) return(invisible())
  if (is.null(world)) {
    mc <- crs
    st <- states
    st$role <- ifelse(st$STUSPS %in% forum, "forum",
                      ifelse(st$STUSPS %in% others, "other", "none"))
    layers <- list(st)
  } else {
    mc <- world$crs
    layers <- world$layers
  }
  xy <- proj(places$lon, places$lat, mc)
  places$x <- xy[, 1]; places$y <- xy[, 2]

  p <- ggplot()
  for (l in layers) {
    p <- p + geom_sf(data = l, aes(fill = role), colour = "white",
                     linewidth = if (is.null(world)) 0.3 else 0.2)
  }
  p <- p + scale_fill_manual(values = c(forum = forum_fill, other = other_fill, none = "grey88"),
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
      lxy <- proj(lab$lx, lab$ly, mc)
      lab$x <- lxy[, 1]; lab$y <- lxy[, 2]
      p <- p + halo(data = lab, aes(x = x, y = y, label = label), size = 2.9,
                    fontface = "italic", min.segment.length = Inf, force = 0)
    }
  }

  # notes: free-standing italic text (lon, lat, label), e.g. a count of people
  # whose homes the opinion doesn't give
  if (!is.null(notes)) {
    nxy <- proj(notes$lon, notes$lat, mc)
    notes$x <- nxy[, 1]; notes$y <- nxy[, 2]
    p <- p + halo(data = notes, aes(x = x, y = y, label = label), size = 2.9,
                  fontface = "italic", min.segment.length = Inf, force = 0)
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
    # Sample the box's edges, since a curved projection bulges between corners.
    s <- seq(0, 1, length.out = 25)
    lon <- xlim[1] + s * diff(xlim); lat <- ylim[1] + s * diff(ylim)
    g <- proj(c(lon, lon, rep(xlim, each = 25)), c(rep(ylim, each = 25), lat, lat), mc)
    lx <- range(g[, 1]); ly <- range(g[, 2])
  }
  lx <- lx + c(-1, 1) * 0.03 * diff(lx); ly <- ly + c(-1, 1) * 0.06 * diff(ly)
  want <- 6.5 / height
  if (diff(lx) / diff(ly) < want) {
    lx <- mean(lx) + c(-1, 1) * diff(ly) * want / 2
  } else {
    ly <- mean(ly) + c(-1, 1) * diff(lx) / want / 2
  }
  p <- p + coord_sf(xlim = lx, ylim = ly, expand = FALSE, crs = mc, datum = NA) +
    theme_void(base_size = 11) + theme(plot.margin = margin(0, 0, 0, 0))
  ggsave(file, p, width = 6.5, height = height, dpi = 200, bg = "white")
  message("wrote ", file)
}

P <- function(...) data.frame(..., stringsAsFactors = FALSE)
A <- function(...) data.frame(..., stringsAsFactors = FALSE)

# Pennoyer v. Neff --------------------------------------------------------------
# The excerpt says only that the land was in Oregon and Neff a non-resident, so
# this map, unlike the others, draws on sources outside the opinion: Deady's
# circuit-court opinion, Neff v. Pennoyer, 17 F. Cas. 1279 (C.C.D. Or. 1875)
# (claim 57 in Multnomah County; Mitchell's suit there; Neff a citizen of
# California in 1874), and Perdue, 62 Wash. L. Rev. 479 (1987) (Iowa, 1848;
# Mitchell's affidavit; "settled in San Joaquin"). The caption flags that
# Neff's whereabouts in 1865 are disputed.
draw_map("maps/pennoyer.png", forum = "OR", others = c("IA", "CA"),
  places = P(
    name    = c("ia", "pdx", "sj"),
    lon     = c(-93.5, -122.68, -121.27),
    lat     = c(42.0, 45.52, 37.93),
    label   = c("Iowa
Neff sets out, 1848",
                "Multnomah County, Ore.
Neff's land claim;
Mitchell's suit, 1865",
                "San Joaquin, Calif.
Neff's home by 1874"),
    nudge_x = c(0, 250, -150), nudge_y = c(-230, 230, -230)),
  arrows = A(from = c("ia", "pdx"), to = c("pdx", "sj"), curvature = c(0.2, -0.3),
             dashed = c(FALSE, TRUE),
             label = c("wagon train", "moves to California
(when is disputed)"),
             lx = c(-108, -114.5), ly = c(47.4, 41.0)),
  xlim = c(-126, -88), ylim = c(33, 49.5), height = 4.4)

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

# Bristol-Myers Squibb Co. v. Superior Court ----------------------------------
draw_map("maps/bristol_myers.png", forum = "CA", others = c("DE", "NY", "NJ"),
  places = P(
    name    = c("sac", "de", "ny", "nj"),
    lon     = c(-121.49, -75.53, -74.0, -74.6),
    lat     = c(38.58, 39.16, 40.71, 40.1),
    label   = c("California
the suit; labs, sales reps,
Sacramento office",
                "Delaware
incorporated", "New York
headquarters",
                "New Jersey
major operations"),
    nudge_x = c(-50, 250, 120, 250), nudge_y = c(330, -250, 230, -60)),
  notes = data.frame(lon = -99, lat = 38.5,
                     label = "86 California plaintiffs and
592 from 33 other States"))

# Asahi Metal Industry Co. v. Superior Court ---------------------------------
draw_map("maps/asahi.png", forum = "CA", others = character(0),
  world = world_base(-170, forum = "CA", others = character(0), nations = c("JPN", "TWN")),
  places = P(
    name    = c("jp", "tw", "solano"),
    lon     = c(138.0, 121.0, -121.9),
    lat     = c(36.2, 23.7, 38.3),
    label   = c("Japan
Asahi makes valve assemblies", "Taiwan
Cheng Shin makes tire tubes",
                "Solano County, Calif.
accident; suit"),
    nudge_x = c(300, 0, 0), nudge_y = c(700, -650, 650)),
  arrows = A(from = c("jp", "tw"), to = c("tw", "solano"), curvature = c(0.3, -0.25),
             dashed = c(FALSE, FALSE),
             label = c("valves sold
in Taiwan", "tubes sold around the world,
including California"),
             lx = c(140, 192), ly = c(25, 37)),
  xlim = c(110, 245), ylim = c(12, 52), height = 3.9)

# J. McIntyre Machinery, Ltd. v. Nicastro ------------------------------------
draw_map("maps/mcintyre.png", forum = "NJ", others = character(0),
  world = world_base(-50, forum = "NJ", others = character(0), nations = "GBR"),
  places = P(
    name    = c("nott", "sb", "lv", "no", "orl", "sa", "sf"),
    lon     = c(-1.15, -74.09, -115.14, -90.07, -81.38, -98.49, -122.42),
    lat     = c(52.95, 40.90, 36.17, 29.95, 28.54, 29.42, 37.77),
    label   = c("Nottingham, England
the manufacturer", "Saddle Brook, N.J.
injury; suit",
                "Las Vegas
the trade show where
the buyer saw the machine", "", "", "", ""),
    nudge_x = c(0, 300, 0, 0, 0, 0, 0), nudge_y = c(650, 600, 700, 0, 0, 0, 0)),
  arrows = A(from = "nott", to = "sb", curvature = 0.25, dashed = FALSE,
             label = "sold through an independent
U.S. distributor", lx = -36, ly = 42),
  notes = data.frame(lon = -97, lat = 25.5, label = "other trade shows"),
  xlim = c(-125, 5), ylim = c(24, 58), height = 3.9)

# Goodyear Dunlop Tires Operations, S.A. v. Brown ----------------------------
draw_map("maps/goodyear.png", forum = "NC", others = "OH",
  world = world_base(-30, forum = "NC", others = "OH", nations = c("TUR", "FRA", "LUX")),
  places = P(
    name    = c("oh", "onslow", "paris", "lux", "tr"),
    lon     = c(-82.8, -77.4, 2.35, 6.13, 33.0),
    lat     = c(40.3, 34.75, 48.86, 49.61, 39.3),
    label   = c("Ohio
Goodyear USA", "Onslow County, N.C.
the suit",
                "outside Paris
the bus accident;
French subsidiary", "Luxembourg
subsidiary",
                "Turkey
tire made by
Turkish subsidiary"),
    nudge_x = c(-300, -200, -800, 400, 0), nudge_y = c(650, -650, -550, 600, -700)),
  arrows = A(from = c("onslow", "tr"), to = c("paris", "paris"), curvature = c(-0.25, 0.2),
             dashed = c(TRUE, FALSE),
             label = c("the soccer team's trip", ""), lx = c(-40, NA), ly = c(43, NA)),
  xlim = c(-95, 45), ylim = c(28, 62), height = 3.9)

# Daimler AG v. Bauman --------------------------------------------------------
draw_map("maps/daimler.png", forum = "CA", others = c("NJ", "DE"),
  world = world_base(-40, forum = "CA", others = c("NJ", "DE"), nations = c("DEU", "ARG")),
  places = P(
    name    = c("stg", "gc", "nj", "cm", "sf"),
    lon     = c(9.18, -58.65, -74.4, -117.92, -122.42),
    lat     = c(48.78, -34.77, 40.2, 33.64, 37.77),
    label   = c("Stuttgart
Daimler headquarters",
                "González Catán, Argentina
MB Argentina plant",
                "New Jersey
MBUSA headquarters
(Delaware LLC)",
                "Costa Mesa, Carson, Irvine
MBUSA facilities", "N.D. Cal.
the suit"),
    nudge_x = c(300, 1200, 700, -100, -300), nudge_y = c(-700, 0, -800, -900, 700)),
  arrows = A(from = c("stg", "nj"), to = c("nj", "cm"), curvature = c(0.25, 0.15),
             dashed = c(FALSE, FALSE),
             label = c("cars imported by MBUSA", "distributed to
dealers"),
             lx = c(-30, -96), ly = c(58, 32)),
  xlim = c(-128, 25), ylim = c(-45, 64), height = 4.8)
