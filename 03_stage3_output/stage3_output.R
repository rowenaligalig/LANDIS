################################################################################
### STAGE 3 — Process ForCS outputs
### For Narval (Calcul Québec) — account: def-dcyr
### Sequential processing with gc() after each sim to avoid memory crashes
### Original script by Dominic Cyr — adapted by Wena
################################################################################

rm(list = ls())
gc()

# ---- USER SETTINGS ----------------------------------------------------------

rootDir <- "/home/rligalig/scratch/LANDIS/LANDIS_files"

## Read simOutputDir written by Stage 1 automatically
simOutputDir <- trimws(readLines(file.path(rootDir, "current_simOutputDir.txt")))
cat("Processing outputs from:", simOutputDir, "\n\n")

## Input files (needed for studyArea raster)
inputPathLandis <- file.path(rootDir, "inputsLandis")
areaName_main   <- "mixedwood-042-51"

## Scripts directory
scriptsDir <- file.path(rootDir, "scripts")

## Which logs to process
logs <- c("summary", "agbAgeClasses", "agbTotal", "ageMax", "FPS")

## Chunk size for combining output files at the end
## Keep small (5) to avoid loading too many RData files at once
chunkSize <- 5

# ---- PACKAGES ---------------------------------------------------------------

pkgs <- c("data.table","dplyr","raster","reshape2","stringr")
invisible(lapply(pkgs, function(p) {
  if (!requireNamespace(p, quietly = TRUE))
    install.packages(p, repos = "https://cloud.r-project.org")
  library(p, character.only = TRUE)
}))

# ---- LOAD simInfo -----------------------------------------------------------

simInfo <- read.csv(file.path(simOutputDir, "simInfo.csv"),
                    colClasses = c(simID = "character"))
simName <- basename(simOutputDir)

simIDs <- str_pad(simInfo$simID,
                  width = max(nchar(simInfo$simID)),
                  side  = "left", pad = "0")

## Only process folders that actually exist
existingDirs <- list.dirs(simOutputDir, full.names = FALSE, recursive = FALSE)
dirIndex     <- which(simIDs %in% existingDirs &
                        simInfo$areaName == areaName_main)

cat("Simulations found to process:", length(dirIndex), "\n\n")

## Load study area raster once — small, stays in memory
studyArea <- raster(file.path(inputPathLandis,
                              paste0("studyArea_", areaName_main, ".tif")))

## Load harvest helper if needed
if ("summary" %in% logs) {
  source(file.path(scriptsDir, "fetchHarvestImplementationFnc.R"))
}

# ---- SEQUENTIAL PROCESSING — one simulation at a time ----------------------

t1 <- Sys.time()

for (i in dirIndex) {

  simID            <- simIDs[i]
  sDir             <- file.path(simOutputDir, simID)
  areaName         <- simInfo[i, "areaName"]
  scenario         <- simInfo[i, "scenario"]
  mgmtScenario     <- simInfo[i, "mgmt"]
  mgmtScenarioName <- mgmtScenario
  harvest          <- simInfo[i, "harvest"]
  wind             <- simInfo[i, "wind"]
  BDA              <- simInfo[i, "BDA"]
  fire             <- simInfo[i, "fire"]
  ND_scenario      <- simInfo[i, "ND_scenario"]
  ND_scenarioName  <- ND_scenario
  replicate        <- simInfo[i, "replicate"]

  cat("-----------------------------------------------\n")
  cat("Processing", simID,
      "(", which(dirIndex == i), "of", length(dirIndex), ")",
      "| scenario:", scenario, "\n")
  cat("Time:", format(Sys.time()), "\n")

  ## Species levels
  sppLvls <- read.table(file.path(sDir, "species.txt"),
                        skip = 1, comment.char = ">")[, 1]
  if (is.factor(sppLvls)) sppLvls <- levels(sppLvls)

  ## Landtypes
  landtypes     <- raster(file.path(sDir, "landtypes.tif"))
  landtypes_RAT <- read.table(file.path(sDir, "landtypes.txt"),
                               skip = 1, comment.char = ">")
  landtypes_RAT <- landtypes_RAT[landtypes_RAT[,1] %in%
                                    c("yes","y","Yes","Y"), ]

  studyArea_ext          <- extend(studyArea, extent(landtypes))
  landtypes[is.na(studyArea_ext)] <- NA
  landtypes[landtypes == 0]       <- NA

  idx   <- which(!is.na(values(landtypes)))
  XY_lt <- data.frame(rowColFromCell(landtypes, idx),
                       ltID = values(landtypes)[idx])
  colnames(XY_lt)[1:2] <- c("row","column")

  ## Management areas
  if ("summary" %in% logs) {
    if (harvest) {
      mgmtAreas <- raster(file.path(sDir, "mgmt-areas.tif"))
      mgmtAreas[is.na(landtypes)] <- NA
      harvImpl  <- fetchHarvestImplementation(
        file.path(sDir, "biomass-harvest.txt"))
    } else {
      mgmtAreas <- landtypes
      mgmtAreas[!is.na(landtypes)] <- 1
    }

    areaSize_mgmt <- data.frame(freq(mgmtAreas))
    areaSize_mgmt[, "area_ha"] <- areaSize_mgmt$count *
      prod(res(mgmtAreas)) / 10000
    areaSize_mgmt <- data.frame(mgmtID      = areaSize_mgmt$value,
                                mgmtArea_ha = areaSize_mgmt$area_ha)
    areaSize_mgmt <- areaSize_mgmt[complete.cases(areaSize_mgmt), ]

    idx_m   <- which(!is.na(values(mgmtAreas)))
    XY_mgmt <- data.frame(rowColFromCell(mgmtAreas, idx_m),
                           mgmtID = values(mgmtAreas)[idx_m])
    colnames(XY_mgmt)[1:2] <- c("row","column")

    XY <- if ("agbAgeClasses" %in% logs) merge(XY_lt, XY_mgmt, all.x = TRUE) else XY_mgmt
  }

  ## ---- SUMMARY LOG ---------------------------------------------------------
  if ("summary" %in% logs) {
    logSummary <- fread(file.path(sDir, "log_Summary.csv"))
    df         <- left_join(XY, logSummary, by = c("row","column"))

    dfSummary <- df %>%
      group_by(mgmtID, Time) %>%
      summarise(
        simID = simID, areaName = areaName, scenario = scenario,
        mgmtScenario = mgmtScenario, mgmtScenarioName = mgmtScenarioName,
        ND_scenario = ND_scenario, ND_scenarioName = ND_scenarioName,
        harvest = harvest, wind = wind, BDA = BDA, fire = fire,
        replicate = replicate,
        ABio = mean(ABio), BBio = mean(BBio), TotalDOM = mean(TotalDOM),
        DelBio = mean(DelBio), Turnover = mean(Turnover),
        NetGrowth = mean(NetGrowth), NPP = mean(NPP),
        Rh = mean(Rh), NEP = mean(NEP), NBP = mean(NBP),
        .groups = "drop"
      ) %>%
      merge(areaSize_mgmt)

    dfSummary <- reshape2::melt(
      dfSummary,
      id.vars = c("simID","areaName","scenario","mgmtScenario",
                  "mgmtScenarioName","ND_scenario","ND_scenarioName",
                  "harvest","wind","BDA","fire","replicate",
                  "Time","mgmtID","mgmtArea_ha")
    ) %>% arrange(simID, Time, mgmtID, variable)

    save(dfSummary,
         file = file.path(simOutputDir, paste0("dfSummary_", simID, ".RData")))
    rm(logSummary, df, dfSummary); gc()
    cat("  summary done\n")
  }

  ## ---- AGB / AGE LOGS ------------------------------------------------------
  if (any(c("agbAgeClasses","agbTotal","ageMax") %in% logs)) {

    if ("agbAgeClasses" %in% logs) {
      areaSize_lt <- data.frame(freq(landtypes))
      areaSize_lt[, "area_ha"] <- areaSize_lt$count *
        prod(res(landtypes)) / 10000
      areaSize_lt <- data.frame(ltID      = areaSize_lt$value,
                                ltArea_ha = areaSize_lt$area_ha)
      areaSize_lt <- areaSize_lt[complete.cases(areaSize_lt), ]
    }

    XY_use <- if ("summary" %in% logs) XY else XY_lt
    agb     <- fread(file.path(sDir, "log_BiomassC.csv"))
    agb     <- left_join(XY_use, agb, by = c("row","column"))

    if ("agbAgeClasses" %in% logs) {
      breaks <- c(seq(0, 120, by = 20), 999)
      agb[, "ageClass"] <- cut(agb$Age, breaks)
      ltVals <- landtypes_RAT$V2

      zeroPadDF <- expand.grid(
        species         = unique(agb$species),
        ageClass        = unique(agb$ageClass),
        landtype        = ltVals,
        Time            = unique(agb$Time),
        agb_tonnesTotal = NA,
        stringsAsFactors = FALSE
      )

      agbSummary <- agb %>%
        mutate(landtype   = ltID,
               agb_tonnes = prod(res(landtypes)) / 10000 *
                 2 * (Wood + Leaf) / 100) %>%
        group_by(landtype, Time, species, ageClass) %>%
        summarise(agb_tonnesTotal = sum(agb_tonnes), .groups = "drop") %>%
        merge(zeroPadDF,
              by = c("species","ageClass","landtype","Time"), all.y = TRUE) %>%
        merge(areaSize_lt, by.x = "landtype", by.y = "ltID") %>%
        mutate(
          agb_tonnesTotal = ifelse(is.na(agb_tonnesTotal.x), 0,
                                   agb_tonnesTotal.x),
          agb_tonnesPerHa = round(agb_tonnesTotal / ltArea_ha, 2)
        )

      agbSummary <- data.frame(
        simID = simID, areaName = areaName, scenario = scenario,
        mgmtScenario = mgmtScenario, mgmtScenarioName = mgmtScenarioName,
        ND_scenario = ND_scenario, ND_scenarioName = ND_scenarioName,
        harvest = harvest, wind = wind, BDA = BDA, fire = fire,
        replicate = replicate,
        agbSummary[, c("Time","landtype","species","ageClass",
                       "agb_tonnesTotal","ltArea_ha","agb_tonnesPerHa")]
      )
      colnames(agbSummary)[colnames(agbSummary) == "ltArea_ha"] <- "landtypeArea_ha"

      save(agbSummary,
           file = file.path(simOutputDir,
                            paste0("agbSummary_", simID, ".RData")))
      rm(agbSummary); gc()
      cat("  agbAgeClasses done\n")
    }

    if ("agbTotal" %in% logs) {
      agbTotal <- agb %>%
        mutate(agb_tonnesPerHa = 2 * (Wood + Leaf) / 100) %>%
        group_by(row, column, Time, species) %>%
        summarise(agb_tonnesPerHa = round(sum(agb_tonnesPerHa), 2),
                  .groups = "drop")
      agbTotal$species <- factor(agbTotal$species, levels = sppLvls)
      agbTotal <- data.frame(
        simID = simID, areaName = areaName, scenario = scenario,
        mgmtScenario = mgmtScenario, mgmtScenarioName = mgmtScenarioName,
        ND_scenario = ND_scenario, ND_scenarioName = ND_scenarioName,
        harvest = harvest, wind = wind, BDA = BDA, fire = fire,
        replicate = replicate, agbTotal)
      save(agbTotal,
           file = file.path(simOutputDir,
                            paste0("agbTotal_", simName, "_", simID, ".RData")))
      rm(agbTotal); gc()
      cat("  agbTotal done\n")
    }

    if ("ageMax" %in% logs) {
      ageMax <- agb %>%
        group_by(row, column, Time) %>%
        summarise(ageMax = max(Age), .groups = "drop")
      ageMax <- data.frame(
        simID = simID, areaName = areaName, scenario = scenario,
        mgmtScenario = mgmtScenario, mgmtScenarioName = mgmtScenarioName,
        ND_scenario = ND_scenario, ND_scenarioName = ND_scenarioName,
        harvest = harvest, wind = wind, BDA = BDA, fire = fire,
        replicate = replicate, ageMax)
      save(ageMax,
           file = file.path(simOutputDir,
                            paste0("ageMax_", simName, "_", simID, ".RData")))
      rm(ageMax); gc()
      cat("  ageMax done\n")
    }

    rm(agb); gc()
  }

  ## ---- FPS LOG -------------------------------------------------------------
  if ("FPS" %in% logs && harvest) {
    mgmtAreas_fps <- raster(file.path(sDir, "mgmt-areas.tif"))
    mgmtAreas_fps[is.na(landtypes)] <- NA

    r  <- mgmtAreas_fps; r[] <- seq_len(ncell(r))
    xy <- as.data.frame(zonal(mgmtAreas_fps, r)) %>%
      mutate(row    = rowFromCell(mgmtAreas_fps, zone),
             column = colFromCell(mgmtAreas_fps, zone)) %>%
      filter(mean == 1) %>%
      dplyr::select(row, column)

    totalArea <- filter(
      as.data.frame(zonal(mgmtAreas_fps, mgmtAreas_fps, sum)),
      zone == 1)[, 2] * prod(res(mgmtAreas_fps)) / 10000

    FluxBio <- fread(file.path(sDir, "log_FluxBio.csv"))
    FluxBio  <- left_join(FluxBio, xy, by = c("row","column"))

    toFPS <- FluxBio %>%
      group_by(Time, species) %>%
      summarize(
        BioToFPS_tonnesCTotal = round(
          prod(res(mgmtAreas_fps)) / 10000 * sum(BioToFPS) / 100, 2),
        .groups = "drop") %>%
      mutate(areaManagedTotal_ha = totalArea)

    areaHarvested <- FluxBio %>%
      filter(BioToFPS > 0) %>%
      distinct(Time, row, column) %>%
      group_by(Time) %>%
      summarise(areaHarvestedTotal_ha = prod(res(mgmtAreas_fps)) / 10000 * n(),
                .groups = "drop")

    toFPS <- if (nrow(areaHarvested) > 0) merge(toFPS, areaHarvested) else
      mutate(toFPS, areaHarvestedTotal_ha = 0)

    toFPS$species <- factor(toFPS$species, levels = sppLvls)
    toFPS <- data.frame(
      simID = simID, areaName = areaName, scenario = scenario,
      mgmtScenario = mgmtScenario, mgmtScenarioName = mgmtScenarioName,
      ND_scenario = ND_scenario, ND_scenarioName = ND_scenarioName,
      wind = wind, BDA = BDA, fire = fire, replicate = replicate, toFPS)

    save(toFPS,
         file = file.path(simOutputDir, paste0("FPS_", simID, ".RData")))
    rm(toFPS, FluxBio, mgmtAreas_fps, xy); gc()
    cat("  FPS done\n")
  }

  ## Clean up all raster objects before next simulation
  rm(landtypes, landtypes_RAT, studyArea_ext, XY_lt, idx)
  if (exists("XY"))           rm(XY)
  if (exists("XY_mgmt"))      rm(XY_mgmt)
  if (exists("mgmtAreas"))    rm(mgmtAreas)
  if (exists("areaSize_mgmt")) rm(areaSize_mgmt)
  if (exists("areaSize_lt"))   rm(areaSize_lt)
  gc()

  cat("Done:", simID, "\n")
}

# ---- COMBINE OUTPUT FILES IN CHUNKS -----------------------------------------

cat("\n=== Combining output files ===\n")
allFiles <- list.files(simOutputDir, full.names = TRUE)

combine_chunks <- function(pattern, outFile, as_csv = FALSE) {
  fNames <- allFiles[grepl(pattern, basename(allFiles))]
  if (length(fNames) == 0) { cat("No files found for pattern:", pattern, "\n"); return() }
  chunks   <- split(fNames, ceiling(seq_along(fNames) / chunkSize))
  combined <- NULL
  for (ch in chunks) {
    chunkData <- do.call("rbind", lapply(ch, function(f) get(load(f))))
    combined  <- if (is.null(combined)) chunkData else rbind(combined, chunkData)
    rm(chunkData); gc()
  }
  if (as_csv) {
    write.csv(combined, file = outFile, row.names = FALSE)
  } else {
    save(combined, file = outFile)
  }
  file.remove(fNames)
  cat("Saved:", basename(outFile), "\n")
}

if ("summary" %in% logs)
  combine_chunks("^dfSummary_",
                 file.path(simOutputDir, paste0("output_summary_", simName, ".RData")))

if ("agbAgeClasses" %in% logs)
  combine_chunks("^agbSummary_",
                 file.path(simOutputDir, paste0("output_bio_", simName, ".RData")))

if ("FPS" %in% logs)
  combine_chunks("^FPS_",
                 file.path(simOutputDir, paste0("output_BioToFPS_", simName, ".csv")),
                 as_csv = TRUE)

t2 <- Sys.time()
cat("\n=== Stage 3 complete ===\n")
cat("Total processing time:", format(t2 - t1), "\n")
