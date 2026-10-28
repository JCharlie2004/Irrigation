# simple_irrigation_model.R  --  the expo model: a daily soil-water "bucket"
#
# The idea in one breath: the soil is a bucket. Each day the crop drinks some water (crop coefficient x ET0),
# rain refills the bucket, and when the bucket is about half empty it is time to irrigate.
#
# Sources: FAO Irrigation and Drainage Paper 56 (Allen et al., 1998): crop coefficients Kc (Table 12), growth-stage
# lengths (Table 11), rooting depth and the depletion limit p (Table 22), soil water capacity (Table 19). Efficiencies and
# the "upper two-thirds of the roots" rule: Irrigation Scheduler user guide. Weather: Open-Meteo (rain and FAO-56 reference ET0, past and forecast).
#
# This is the same model as index.html (the web page); both give identical numbers.

# L = FAO-56 Table 11 stage lengths (initial, development, mid, late; scaled to the crop length you enter)
# kc = FAO-56 Table 12 (initial, mid, end); zmax = low end of the Table 22 rooting range (FAO: use the smaller values
# for irrigation scheduling); p = Table 22 depletion fraction; days = default crop length.
crops <- list(
  wheat       = list(label = "Wheat",              days = 130, L = c(15, 25, 50, 30),   kc = c(0.30, 1.15, 0.25), zmin = 0.3, zmax = 1.0, p = 0.55),
  maize       = list(label = "Maize",              days = 105, L = c(20, 35, 40, 30),   kc = c(0.30, 1.20, 0.35), zmin = 0.3, zmax = 1.0, p = 0.55),
  sugarcane   = list(label = "Sugarcane",          days = 405, L = c(35, 60, 190, 120), kc = c(0.40, 1.25, 0.75), zmin = 0.3, zmax = 1.2, p = 0.65),
  cotton      = list(label = "Cotton",             days = 195, L = c(30, 50, 60, 55),   kc = c(0.35, 1.15, 0.60), zmin = 0.3, zmax = 1.0, p = 0.65),
  groundnut   = list(label = "Groundnut",          days = 130, L = c(25, 35, 45, 25),   kc = c(0.40, 1.15, 0.60), zmin = 0.3, zmax = 0.5, p = 0.50),
  soybean     = list(label = "Soybean",            days = 85,  L = c(15, 15, 40, 15),   kc = c(0.40, 1.15, 0.50), zmin = 0.3, zmax = 0.6, p = 0.50),
  potato      = list(label = "Potato",             days = 115, L = c(25, 30, 30, 30),   kc = c(0.50, 1.15, 0.75), zmin = 0.3, zmax = 0.4, p = 0.35),
  pearlmillet = list(label = "Pearl millet",       days = 105, L = c(15, 25, 40, 25),   kc = c(0.30, 1.00, 0.30), zmin = 0.3, zmax = 1.0, p = 0.55),
  sorghum     = list(label = "Sorghum",            days = 130, L = c(20, 35, 40, 30),   kc = c(0.30, 1.05, 0.55), zmin = 0.3, zmax = 1.0, p = 0.55),
  mustard     = list(label = "Mustard / rapeseed", days = 120, L = c(35, 55, 60, 40),   kc = c(0.35, 1.15, 0.35), zmin = 0.3, zmax = 1.0, p = 0.60),
  chickpea    = list(label = "Chickpea",           days = 130, L = c(25, 35, 70, 40),   kc = c(0.40, 1.00, 0.35), zmin = 0.3, zmax = 0.6, p = 0.50),
  # --- crops common in south India (FAO-56 Tables 11, 12, 22; lengths from TNAU where noted on the web page) ---
  ragi        = list(label = "Finger millet (ragi)", days = 110, L = c(15, 25, 40, 25), kc = c(0.30, 1.00, 0.30), zmin = 0.3, zmax = 1.0, p = 0.55),   # FAO millet row as proxy
  greengram   = list(label = "Green gram (moong)", days = 65,  L = c(20, 30, 30, 20),   kc = c(0.40, 1.05, 0.35), zmin = 0.3, zmax = 0.6, p = 0.45),
  sunflower   = list(label = "Sunflower",          days = 90,  L = c(25, 35, 45, 25),   kc = c(0.35, 1.15, 0.35), zmin = 0.3, zmax = 0.8, p = 0.45),
  sesame      = list(label = "Sesame (gingelly)",  days = 100, L = c(20, 30, 40, 20),   kc = c(0.35, 1.10, 0.25), zmin = 0.3, zmax = 1.0, p = 0.60),
  castor      = list(label = "Castor",             days = 180, L = c(25, 40, 65, 50),   kc = c(0.35, 1.15, 0.55), zmin = 0.3, zmax = 1.0, p = 0.50),
  tomato      = list(label = "Tomato",             days = 135, L = c(30, 40, 40, 25),   kc = c(0.60, 1.15, 0.80), zmin = 0.3, zmax = 0.7, p = 0.40),
  chilli      = list(label = "Chilli (sweet-pepper proxy)", days = 125, L = c(30, 35, 40, 20), kc = c(0.60, 1.05, 0.90), zmin = 0.3, zmax = 0.5, p = 0.30),
  onion       = list(label = "Onion",              days = 150, L = c(15, 25, 70, 40),   kc = c(0.70, 1.05, 0.75), zmin = 0.3, zmax = 0.3, p = 0.30),
  brinjal     = list(label = "Brinjal (eggplant)", days = 130, L = c(30, 40, 40, 20),   kc = c(0.60, 1.05, 0.90), zmin = 0.3, zmax = 0.7, p = 0.45),
  banana      = list(label = "Banana (first year)", days = 390, L = c(120, 90, 120, 60), kc = c(0.50, 1.10, 1.00), zmin = 0.3, zmax = 0.5, p = 0.35),
  # mature coconut palms: a perennial, so no sowing date and no season end; constant Kc (FAO "palm trees") and root depth
  # rice is grown in standing water: it uses the paddy functions at the end of this file (simple_paddy_advice)
  rice        = list(label = "Rice (paddy)", paddy = TRUE, days = 110, L = c(30, 30, 60, 30), kc = c(1.05, 1.20, 0.75), zmin = 0.3, zmax = 0.3, p = 0),
  coconut     = list(label = "Coconut (mature palms)", perennial = TRUE, days = 365, L = c(1, 1, 1, 1), kc = c(1.00, 1.00, 1.00), zmin = 0.7, zmax = 0.7, p = 0.65))
# plant-available water, mm per metre of soil: loamy sand 90, silt 170 and silty clay 120 are from FAO-56 Example 36 (Table 19);
# sandy loam, loam, silt loam and clay come from an irrigation-textbook table (field capacity minus wilting point)
soils   <- c(sandy = 90, sandyloam = 120, loam = 150, siltloam = 180, clay = 120)
# seepage + percolation while water stands, mm/day: FAO Training Manuals 3 and 4 (heavy clay 2, average 5, sandy 8; sandy loam interpolated)
perc_rate <- c(sandy = 8, sandyloam = 6, loam = 5, siltloam = 5, clay = 2)
methods <- c(flood = 0.65, sprinkler = 0.80, drip = 0.90)           # irrigation efficiency
root_share <- 0.67      # the bucket is the upper two-thirds of the root zone

# the four growth stages in days, scaled to the crop's total length
stage_days <- function(crop, total) {
  L <- round(total * crop$L / sum(crop$L)); L[4] <- total - sum(L[1:3]); L
}
# crop coefficient: flat, rising, flat, falling
kc_at <- function(das, L, K) {
  if (das <= L[1]) K[1]
  else if (das <= L[1] + L[2]) K[1] + (K[2] - K[1]) * (das - L[1]) / L[2]
  else if (das <= sum(L[1:3])) K[2]
  else K[2] + (K[3] - K[2]) * (das - sum(L[1:3])) / L[4]
}
# roots deepen from 0.3 m to 1.0 m until the crop has grown fully
root_depth <- function(das, crop, L) crop$zmin + (crop$zmax - crop$zmin) * min(1, das / (L[1] + L[2]))

# wx: data frame with date, rain (mm), et0 (mm/day), from the last wetting to today + 7 days
simple_advice <- function(wx, crop = "wheat", sow, last_wet = sow, soil = "loam", method = "flood",
                          area_ha = 1, flow_m3h = 30, crop_days = NULL, today = Sys.Date()) {
  cr <- crops[[crop]]; sow <- as.Date(sow); last_wet <- as.Date(last_wet); today <- as.Date(today)
  if (isTRUE(cr$paddy)) return(simple_paddy_advice(wx, sow, last_wet, soil, mgmt = "flood", area_ha, flow_m3h, crop_days, today))
  total <- if (is.null(crop_days)) cr$days else crop_days
  L <- stage_days(cr, total); awc <- soils[[soil]]; eff <- methods[[method]]
  per <- isTRUE(cr$perennial)
  if (!per && today < sow) return(list(status = "notsown"))
  if (!per && today > sow + total - 1) return(list(status = "over"))
  start <- if (per) last_wet else max(sow, last_wet); wx <- wx[wx$date >= start, ]
  dep <- 0; rows <- vector("list", nrow(wx))
  for (i in seq_len(nrow(wx))) {
    das <- if (per) as.numeric(wx$date[i] - start) + 1 else as.numeric(wx$date[i] - sow) + 1
    if (das < 1) next
    zr  <- if (per) cr$zmax else root_depth(das, cr, L); taw <- awc * zr * root_share; raw <- cr$p * taw     # bucket size, 'irrigate' line
    kc  <- if (per) cr$kc[2] else kc_at(das, L, cr$kc); etc <- kc * wx$et0[i]                                 # what the crop drinks today
    dep <- dep + etc - wx$rain[i]                                                      # drinks more, rain refills
    drain <- max(0, -dep); dep <- min(max(dep, 0), taw)                                # a full bucket overflows
    rows[[i]] <- data.frame(date = wx$date[i], das, zr, taw, raw, kc, et0 = wx$et0[i], rain = wx$rain[i], etc, dep, drain)
  }
  rows <- do.call(rbind, rows); ti <- which(rows$date == today)
  if (!length(ti)) return(list(status = "noweather"))
  out <- list(status = "ok", rows = rows, L = L, today = rows[ti, ], answer = "none", k = NA)
  k <- which(seq_len(nrow(rows)) >= ti & rows$dep >= rows$raw)[1]
  if (!is.na(k)) {
    r <- rows[k, ]
    out$k <- k; out$in_days <- k - ti; out$date <- r$date
    out$net <- r$dep; out$gross <- r$dep / eff
    out$volume_m3 <- out$gross * 10 * area_ha                      # 1 mm over 1 ha = 10 m3
    out$pump_hours <- if (flow_m3h > 0) out$volume_m3 / flow_m3h else NA
    out$answer <- if (out$in_days == 0) "today" else "later"
    for (j in (k + 1):min(k + 2, nrow(rows))) {                    # rain in the next two days that refills it?
      if (j > k && j <= nrow(rows) && rows$rain[j] > 0 && rows$dep[j] < rows$raw[j]) { out$answer <- "hold"; out$hold_date <- rows$date[j]; break }
    }
  }
  out
}

# weather for one place: past days since `start` and the next 7 days, from Open-Meteo (needs internet)
get_weather_simple <- function(lat, lon, start, today = Sys.Date()) {
  past <- min(92, as.numeric(as.Date(today) - as.Date(start)))
  u <- sprintf(paste0("https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&daily=precipitation_sum,",
                      "et0_fao_evapotranspiration&past_days=%d&forecast_days=8&timezone=Asia%%2FKolkata"), lat, lon, past)
  d <- jsonlite::fromJSON(u)$daily
  data.frame(date = as.Date(d$time), rain = ifelse(is.na(d$precipitation_sum), 0, d$precipitation_sum),
             et0 = ifelse(is.na(d$et0_fao_evapotranspiration), mean(d$et0_fao_evapotranspiration, na.rm = TRUE),
                          d$et0_fao_evapotranspiration))
}

# a quick picture: depletion falls DOWN from 'full', the red line is the irrigate line
plot_simple <- function(res, main = "Soil water in the root zone") {
  r <- res$rows; r <- r[r$date >= res$today$date - 20, ]
  plot(r$date, r$dep, type = "n", ylim = rev(c(0, max(r$taw) * 1.05)), xlab = "", ylab = "Depletion (mm), full at the top", main = main)
  polygon(c(r$date, rev(r$date)), c(r$dep, rev(r$taw)), col = "#b8d4ee", border = NA)
  lines(r$date, r$raw, col = "#d62728", lty = 2, lwd = 2); lines(r$date, r$dep, lwd = 2, col = "#1f4e79")
  abline(v = res$today$date, lty = 3)
  if (!is.na(res$k)) points(res$date, res$net, pch = 21, bg = "#2ca02c", cex = 1.8)
}

# ---- example (needs internet): wheat near Ludhiana ---------------------------------------------------------
# wx <- get_weather_simple(30.90, 75.85, start = Sys.Date() - 40)
# res <- simple_advice(wx, "wheat", sow = Sys.Date() - 60, last_wet = Sys.Date() - 14, soil = "loam", method = "flood",
#                      area_ha = 1, flow_m3h = 30)
# res$answer; res$in_days; round(c(res$net, res$gross, res$volume_m3, res$pump_hours), 1); plot_simple(res)


# ======================================================================================================================
# PADDY RICE: the field is a tank of standing water (mm above the soil surface; negative = water level below the surface)
# Each day: + rain - crop use (Kc x ET0) - seepage and percolation (only while water stands); water above the bund overflows.
# Sources: FAO-56 (Kc); FAO Irrigation Water Management Training Manuals 3 and 4 (puddling 200 mm; seepage and percolation);
# TNAU rice irrigation (irrigate one day after the ponded water disappears, re-flood to 5 cm); IRRI 'safe AWD' and ICAR-CRRI
# Technology Bulletin 249 (irrigate when the water is 15 cm below the surface, re-flood to 5 cm; start 1 to 2 weeks after
# transplanting; keep flooded around flowering).
# OUR assumptions: bunds hold 100 mm; 15 cm below the surface is treated as 15 mm of water (about 10% drainable pore space);
# flowering is 55% to 75% of the crop length; no irrigation in the last 10 days before harvest (field drained).
# ======================================================================================================================
paddy <- list(target = 50, max_depth = 100, awd_allow = 15, flooded_start = 14, flower_from = 0.55, flower_to = 0.75,
              drain_days = 10, puddling_mm = 200)

# the water level at which to irrigate (end of day) for a management style: "flood" or "awd"
paddy_trigger <- function(mode, das, days) {
  if (mode == "flood") return(0)
  flowering <- das >= paddy$flower_from * days && das <= paddy$flower_to * days
  if (das <= paddy$flooded_start || flowering) return(0)
  -paddy$awd_allow
}

# wx: date, rain, et0. Starts at the later of transplanting and the last flooding. auto = irrigate whenever the trigger is hit.
simulate_paddy <- function(wx, sow, last_wet, soil, mode, days, auto = FALSE) {
  cr <- crops$rice; L <- stage_days(cr, days); perc <- perc_rate[[soil]]
  start <- max(sow, last_wet); wx <- wx[wx$date >= start, ]
  h <- paddy$target; pend <- FALSE; total <- 0; count <- 0; rows <- vector("list", nrow(wx))
  for (i in seq_len(nrow(wx))) {
    das <- as.numeric(wx$date[i] - sow) + 1
    if (das < 1) next
    irr <- 0
    if (pend) { irr <- paddy$target - h; h <- paddy$target; pend <- FALSE; total <- total + irr; count <- count + 1 }
    kc <- kc_at(das, L, cr$kc); etc <- kc * wx$et0[i]; h1 <- h + wx$rain[i]; seep <- min(perc, max(h1, 0))
    h2 <- h1 - seep - etc; spill <- max(0, h2 - paddy$max_depth); h2 <- min(h2, paddy$max_depth)
    trig <- paddy_trigger(mode, das, days)
    rows[[i]] <- data.frame(date = wx$date[i], das, kc, et0 = wx$et0[i], rain = wx$rain[i], etc, seep, h = h2, spill, irr, trig)
    h <- h2
    if (auto && h <= trig && das <= days - paddy$drain_days) pend <- TRUE
  }
  list(rows = do.call(rbind, rows), L = L, days = days, total = total, count = count)
}

simple_paddy_advice <- function(wx, sow, last_wet = sow, soil = "loam", mgmt = "flood", area_ha = 1, flow_m3h = 30,
                                crop_days = NULL, today = Sys.Date()) {
  sow <- as.Date(sow); last_wet <- as.Date(last_wet); today <- as.Date(today)
  days <- if (is.null(crop_days)) crops$rice$days else crop_days; eff <- methods[["flood"]]
  if (today < sow) return(list(status = "notplanted", puddle_mm = paddy$puddling_mm, puddle_m3 = paddy$puddling_mm * 10 * area_ha,
                               puddle_hours = if (flow_m3h > 0) paddy$puddling_mm * 10 * area_ha / flow_m3h else NA))
  if (today > sow + days - 1) return(list(status = "over"))
  sim <- simulate_paddy(wx, sow, last_wet, soil, mgmt, days); rows <- sim$rows; ti <- which(rows$date == today)
  if (!length(ti)) return(list(status = "noweather"))
  out <- list(status = "ok", rows = rows, today = rows[ti, ], answer = "none", k = NA)
  out$overdue_days <- sum(rows$h[seq_len(ti - 1)] <= rows$trig[seq_len(ti - 1)])
  k <- which(seq_len(nrow(rows)) >= ti & rows$h <= rows$trig & rows$das <= days - paddy$drain_days)[1]
  if (!is.na(k)) {
    r <- rows[k, ]; out$k <- k; out$in_days <- k - ti; out$date <- r$date
    out$net <- paddy$target - r$h; out$gross <- out$net / eff; out$volume_m3 <- out$gross * 10 * area_ha
    out$pump_hours <- if (flow_m3h > 0) out$volume_m3 / flow_m3h else NA
    out$answer <- if (out$in_days == 0) "today" else "later"
    for (j in (k + 1):min(k + 2, nrow(rows))) if (j > k && j <= nrow(rows) && rows$rain[j] > 0 && rows$h[j] > rows$trig[j]) { out$answer <- "hold"; out$hold_date <- rows$date[j]; break }
  }
  # what AWD would save: both styles irrigate automatically from transplanting to the end of the weather data
  wxp <- wx[wx$date >= sow, ]
  a <- simulate_paddy(wxp, sow, sow, soil, "flood", days, auto = TRUE); b <- simulate_paddy(wxp, sow, sow, soil, "awd", days, auto = TRUE)
  out$compare <- list(flood_mm = a$total, awd_mm = b$total, flood_n = a$count, awd_n = b$count,
                      saving_pct = if (a$total > 0) 100 * (a$total - b$total) / a$total else NA)
  out
}
