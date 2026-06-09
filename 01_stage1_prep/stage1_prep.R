################################################################################
### STAGE 1 — Prepare simulation folders
### Climate scenarios: baseline, RCP45, RCP85
### For Narval (Calcul Québec) 
### Original script by Dominic Cyr 
################################################################################

rm(list = ls())
gc()

# ---- USER SETTINGS ----------------------------------------------------------

## Your LANDIS folder on Narval scratch
rootDir <- "/home/rligalig/scratch/LANDIS/LANDIS_files"   # adjust if needed

## Input files directory (must already be transferred to cluster)
inputPathLandis <- file.path(rootDir, "inputsLandis")

## Dated output folder — all simulation folders go here
simOutputDir <- file.path(rootDir, paste0("simRun_", Sys.Date()))
dir.create(simOutputDir, showWarnings = FALSE, recursive = TRUE)
setwd(simOutputDir)

## Simulation settings
simDuration      <- 75
t0               <- 2020
forCSVersion     <- "3.1"
smoothAgeClasses <- TRUE
includeSnags     <- FALSE

## Experimental design — all three climate scenarios
expDesign <- list(
  area     = c("mixedwood-042-51"),
  scenario = c("baseline", "RCP45", "RCP85"),
  mgmt     = list(
    "mixedwood-042-51" = c("baseline_45p", "noHarvest")
  ),
  spinup  = FALSE,
  cropped = list("mixedwood-042-51" = FALSE),
  rep     = 5,
  ND      = data.frame(
    wind        = c(TRUE,  TRUE,  TRUE,  FALSE),
    BDA         = c(FALSE, TRUE,  TRUE,  FALSE),
    fire        = c(FALSE, FALSE, TRUE,  TRUE),
    ND_scenario = c("Wind","Wind_Sbw","Wind_Sbw_Fire","Wind_Fire"),
    stringsAsFactors = FALSE
  )
)

## BDA parameters
bdaParams <- list(
  ongoingAtT0 = FALSE,
  cycleMean   = 35,  cycleSD     = 2.5,
  durMortMean = 7,   durMortSD   = 2
)

## Fire region years per scenario
## baseline: only year 0
## RCP45, RCP85: years 10, 40, 70
## matches your file naming:
##   fire-regions_mixedwood-042-51_baseline_0.tif
##   fire-regions_mixedwood-042-51_RCP45_10.tif etc.
fireYears <- list(
  baseline = 0,
  RCP45    = c(10, 40, 70),
  RCP85    = c(10, 40, 70)
)

# ---- PACKAGES ---------------------------------------------------------------

pkgs <- c("stringr","dplyr","raster","parallel","doSNOW","foreach")
invisible(lapply(pkgs, function(p) {
  if (!requireNamespace(p, quietly = TRUE))
    install.packages(p, repos = "https://cloud.r-project.org")
  library(p, character.only = TRUE)
}))

# ---- BUILD simInfo ----------------------------------------------------------

simInfo <- list()
for (a in names(expDesign$mgmt)) {
  for (i in seq_len(nrow(expDesign$ND))) {
    simInfo[[paste(a, i, sep = "_")]] <- expand.grid(
      areaName     = a,
      scenario     = expDesign$scenario,
      mgmt         = expDesign$mgmt[[a]],
      cropped      = expDesign$cropped[[a]],
      spinup       = expDesign$spinup,
      includeSnags = includeSnags,
      wind         = expDesign$ND$wind[i],
      BDA          = expDesign$ND$BDA[i],
      fire         = expDesign$ND$fire[i],
      ND_scenario  = expDesign$ND$ND_scenario[i],
      replicate    = seq_len(expDesign$rep),
      stringsAsFactors = FALSE
    )
  }
}

simInfo <- do.call("rbind", simInfo) %>%
  mutate(harvest = mgmt != "noHarvest") %>%
  arrange(replicate, scenario, fire, BDA, wind, harvest) %>%
  dplyr::select(areaName, scenario, mgmt, cropped, spinup, includeSnags,
                harvest, wind, BDA, fire, ND_scenario, replicate)

sID     <- seq_len(nrow(simInfo)) - 1
simInfo <- data.frame(
  simID = str_pad(sID, nchar(max(sID)), pad = "0"),
  simInfo,
  stringsAsFactors = FALSE
)
simInfo[, "harvest"] <- simInfo[, "mgmt"] != "noHarvest"
row.names(simInfo)   <- seq_len(nrow(simInfo))

cat("Total simulations to prepare:", nrow(simInfo), "\n")
cat("Breakdown by scenario:\n")
print(table(simInfo$scenario))
cat("\n")

# ---- SAVE simInfo early so Stage 2 and 3 can read it -----------------------
write.csv(simInfo,
          file.path(simOutputDir, "simInfo.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

## Also save the simOutputDir path so Stage 2/3 can find it automatically
writeLines(simOutputDir, file.path(rootDir, "current_simOutputDir.txt"))
cat("simOutputDir path saved to: current_simOutputDir.txt\n\n")

# ---- PARALLEL PREP ----------------------------------------------------------
## On Narval we use more cores since memory per node is generous (249GB)
## Using 8 cores here — matches --cpus-per-task=8 in submit_stage1.sh
nCores <- min(8, nrow(simInfo))
cl     <- makeCluster(nCores, outfile = file.path(simOutputDir, "stage1_log.txt"))
registerDoSNOW(cl)

foreach(i = seq_len(nrow(simInfo)),
        .packages = c("raster","stringr"),
        .export   = c("simInfo","simOutputDir","inputPathLandis",
                      "smoothAgeClasses","includeSnags","forCSVersion",
                      "simDuration","t0","bdaParams","expDesign",
                      "fireYears")) %dopar% {

  simID        <- simInfo[i, "simID"]
  areaName     <- simInfo[i, "areaName"]
  scenario     <- simInfo[i, "scenario"]
  mgmt         <- simInfo[i, "mgmt"]
  spinup       <- simInfo[i, "spinup"]
  cropped      <- simInfo[i, "cropped"]
  harvest      <- simInfo[i, "harvest"]
  fire         <- simInfo[i, "fire"]
  wind         <- simInfo[i, "wind"]
  BDA          <- simInfo[i, "BDA"]
  includeSnags <- simInfo[i, "includeSnags"]
  inputDir     <- inputPathLandis
  simFolder    <- file.path(simOutputDir, simID)
  dir.create(simFolder, showWarnings = FALSE)

  # ---- Rasters -------------------------------------------------------------
  if (cropped) {
    rCrop <- raster(file.path(inputDir,
                              paste0("studyArea_", areaName, "_cropped.tif")))
    for (layer in c("initial-communities","landtypes")) {
      r <- crop(raster(file.path(inputDir,
                                 paste0(layer,"_",areaName,".tif"))), rCrop)
      r[is.na(rCrop)] <- NA
      writeRaster(r, file.path(simFolder, paste0(layer,".tif")),
                  datatype = "INT4S", overwrite = TRUE, NAflag = 0)
    }
  } else {
    for (layer in c("initial-communities","landtypes")) {
      file.copy(file.path(inputDir, paste0(layer,"_",areaName,".tif")),
                file.path(simFolder, paste0(layer,".tif")), overwrite = TRUE)
    }
  }

  # ---- Snags ---------------------------------------------------------------
  if (includeSnags) {
    file.copy(file.path(inputDir, paste0("initial-snags_",areaName,".txt")),
              file.path(simFolder, "initial-snags.txt"), overwrite = TRUE)
  }

  # ---- Smooth age classes --------------------------------------------------
  if (smoothAgeClasses) {
    spp <- read.table(file.path(inputDir,
                                paste0("species_",areaName,".txt")),
                      skip = 1, comment.char = ">")[, 1]
    x   <- readLines(file.path(inputDir,
                               paste0("initial-communities_",areaName,".txt")))
    tmp <- lapply(strsplit(x, " "), function(z) z[nchar(z) > 0])
    fname <- file.path(simFolder, "initial-communities.txt")
    file.create(fname)
    for (j in seq_along(tmp)) {
      l <- tmp[[j]]
      if (length(l) > 0 && l[1] %in% spp) {
        ages <- round(as.numeric(l[-1]) + runif(length(l)-1, -9, 0))
        l    <- paste0(l[1], "\t", paste(ages, collapse = " "))
      } else {
        l <- paste(l, collapse = " ")
      }
      write(l, file = fname, append = TRUE)
    }
  } else {
    file.copy(file.path(inputDir,
                        paste0("initial-communities_",areaName,".txt")),
              file.path(simFolder, "initial-communities.txt"), overwrite = TRUE)
  }

  file.copy(file.path(inputDir, paste0("landtypes_",areaName,".txt")),
            file.path(simFolder, "landtypes.txt"), overwrite = TRUE)

  # ---- ForCS files — all scenario-specific ---------------------------------
  ## forCS-input
  if (spinup) {
    file.copy(
      file.path(inputDir, paste0("forCS-input_",areaName,"_spinup.txt")),
      file.path(simFolder, "forCS-input.txt"), overwrite = TRUE)
  } else {
    file.copy(
      file.path(inputDir, paste0("forCS-input_",areaName,"_",scenario,".txt")),
      file.path(simFolder, "forCS-input.txt"), overwrite = TRUE)
  }

  ## forCS-climate: forCS-climate_mixedwood-042-51_RCP45.txt etc.
  file.copy(
    file.path(inputDir, paste0("forCS-climate_",areaName,"_",scenario,".txt")),
    file.path(simFolder, "forCS-climate.txt"), overwrite = TRUE)

  ## ForCS_DM: ForCS_DM_mixedwood-042-51_RCP85.txt etc.
  if (as.numeric(forCSVersion) >= 3.1) {
    file.copy(
      file.path(inputDir, paste0("ForCS_DM_",areaName,"_",scenario,".txt")),
      file.path(simFolder, "ForCS_DM.txt"), overwrite = TRUE)
  }

  # ---- Disturbances --------------------------------------------------------
  if (!spinup) {

    ## Harvest
    if (harvest) {
      if (cropped) {
        rCrop <- raster(file.path(inputDir,
                                  paste0("studyArea_",areaName,"_cropped.tif")))
        for (layer in c("stand-map","mgmt-areas")) {
          r <- crop(raster(file.path(inputDir,
                                     paste0(layer,"_",areaName,".tif"))), rCrop)
          r[is.na(rCrop)] <- NA
          writeRaster(r, file.path(simFolder, paste0(layer,".tif")),
                      datatype = "INT4S", overwrite = TRUE, NAflag = 0)
        }
      } else {
        for (layer in c("stand-map","mgmt-areas")) {
          file.copy(file.path(inputDir, paste0(layer,"_",areaName,".tif")),
                    file.path(simFolder, paste0(layer,".tif")), overwrite = TRUE)
        }
      }
      file.copy(
        file.path(inputDir,
                  paste0("biomass-harvest_",areaName,"_",mgmt,".txt")),
        file.path(simFolder, "biomass-harvest.txt"), overwrite = TRUE)
    }

    ## Wind
    if (wind) {
      file.copy(
        file.path(inputDir, paste0("base-wind_",areaName,".txt")),
        file.path(simFolder, "base-wind.txt"), overwrite = TRUE)
    }

    ## Fire — scenario-specific base-fire + correct fire-region rasters
    if (fire) {
      ## base-fire_mixedwood-042-51_RCP45.txt etc.
      file.copy(
        file.path(inputDir,
                  paste0("base-fire_",areaName,"_",scenario,".txt")),
        file.path(simFolder, "base-fire.txt"), overwrite = TRUE)

      ## fire-regions rasters — correct years per scenario
      yrs <- fireYears[[scenario]]
      for (y in yrs) {
        src <- file.path(inputDir,
                         paste0("fire-regions_",areaName,"_",
                                scenario,"_",y,".tif"))
        dst <- file.path(simFolder, paste0("fire-regions_",y,".tif"))
        if (cropped) {
          rCrop <- raster(file.path(inputDir,
                                    paste0("studyArea_",areaName,
                                           "_cropped.tif")))
          r <- crop(raster(src), rCrop)
          r[is.na(rCrop)] <- NA
          writeRaster(r, dst, datatype = "INT4S", overwrite = TRUE, NAflag = 0)
        } else {
          file.copy(src, dst, overwrite = TRUE)
        }
      }
    }

    ## BDA
    if (BDA) {
      tsle             <- t0 - 2006
      original_content <- readLines(file.path(inputPathLandis,
                                              "Base-BDA_budworm.txt"))
      base_bda_tmpl    <- readLines(file.path(inputPathLandis, "base-bda.txt"))
      bda_sec_idx      <- grep("BDAInputFiles", base_bda_tmpl)

      update_years <- function(content, start_year, duration) {
        content <- sub("StartYear \\d+", paste("StartYear", start_year), content)
        content <- sub("EndYear \\d+",
                       paste("EndYear", start_year + duration), content)
        content
      }

      start_year     <- round(rnorm(1, bdaParams$cycleMean,
                                    bdaParams$cycleSD)) - tsle
      BDAduration    <- round(rnorm(1, bdaParams$durMortMean,
                                    bdaParams$durMortSD))
      j              <- 1
      bda_file_names <- character()

      while (start_year <= simDuration) {
        if (j > 1)
          BDAduration <- round(rnorm(1, bdaParams$durMortMean,
                                      bdaParams$durMortSD))
        fname <- sprintf("Base-BDA_budworm-%d.txt", j)
        writeLines(update_years(original_content, start_year, BDAduration),
                   file.path(simFolder, fname))
        bda_file_names <- c(bda_file_names, fname)
        start_year     <- start_year + round(rnorm(1, bdaParams$cycleMean,
                                                    bdaParams$cycleSD))
        j <- j + 1
      }

      base_bda_tmpl[bda_sec_idx] <- paste0("BDAInputFiles\t",
                                            paste(bda_file_names,
                                                  collapse = "\n\t"))
      writeLines(base_bda_tmpl, file.path(simFolder, "base-bda.txt"))
    }

    ## scenario.txt
    x     <- readLines(file.path(inputPathLandis, "scenario.txt"))
    flags <- list(fire    = "Base Fire",
                  harvest = "Biomass Harvest",
                  wind    = "Base Wind",
                  BDA     = "Base BDA")
    on    <- list(fire = fire, harvest = harvest, wind = wind, BDA = BDA)
    for (nm in names(flags)) {
      if (!on[[nm]]) {
        idx    <- grep(flags[[nm]], x)
        x[idx] <- paste(">>", x[idx])
      }
    }
    idx    <- grep("Duration", x)
    x[idx] <- paste("Duration", simDuration)
    writeLines(x, file.path(simFolder, "scenario.txt"))

  } else {
    file.copy(file.path(inputPathLandis, "scenario_spinup.txt"),
              file.path(simFolder, "scenario.txt"), overwrite = TRUE)
  }

  ## species.txt + README
  file.copy(file.path(inputPathLandis, paste0("species_",areaName,".txt")),
            file.path(simFolder, "species.txt"), overwrite = TRUE)
  write.table(t(simInfo[i, ]),
              file.path(simFolder, "README.txt"),
              quote = FALSE, col.names = FALSE)

  cat("Prepared:", simID, "| scenario:", scenario,
      "| ND:", simInfo[i,"ND_scenario"], "\n")
}

stopCluster(cl)
gc()

cat("\n=== Stage 1 complete ===\n")
cat("Simulations prepared:", nrow(simInfo), "\n")
print(table(simInfo$scenario, simInfo$ND_scenario))
