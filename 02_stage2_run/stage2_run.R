################################################################################
### STAGE 2 — Run LANDIS-II simulations
### For Narval (Calcul Québec) — account: def-dcyr
### Runs simulations sequentially — LANDIS-II uses its own internal threads
### Original script by Dominic Cyr — adapted by Wena
################################################################################

rm(list = ls())
gc()

# ---- USER SETTINGS ----------------------------------------------------------

rootDir <- "/home/rligalig/scratch/LANDIS"

## Read simOutputDir written by Stage 1 automatically
simOutputDir <- trimws(readLines(file.path(rootDir, "current_simOutputDir.txt")))
cat("Reading simulations from:", simOutputDir, "\n\n")

## LANDIS-II command on Narval
## Check available versions with: module spider landis
## Check dotnet with:             module spider dotnet
## The module load lines are in submit_stage2.sh — here we just call the binary
landisCmd <- "apptainer exec -C -B /home/rligalig/scratch/LANDIS/LANDIS_files/simRun_2026-06-01 /home/rligalig/scratch/LANDIS/apptainer/landis-ii_v7_linux_rowena.sif /bin/sh -c"
#landisCmd <- "apptainer exec -C -B /home/rligalig/scratch/LANDIS/LANDIS_files /home/rligalig/scratch/LANDIS/apptainer/landis_ii_v7_linux_manawan_reworked.sif /bin/sh -c 'cd SIMFOLDER && dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt'"
## *** If LANDIS-II path is different on your cluster, update the line above ***
## *** Ask Calcul Québec support or Dom for the correct path                  ***

# ---- PACKAGES ---------------------------------------------------------------

if (!requireNamespace("stringr", quietly = TRUE)) install.packages("stringr")
library(stringr)

# ---- LOAD simInfo -----------------------------------------------------------

simInfo <- read.csv(file.path(simOutputDir, "simInfo.csv"),
                    colClasses = c(simID = "character"))
simIDs  <- str_pad(simInfo$simID,
                   width = max(nchar(simInfo$simID)),
                   side  = "left", pad = "0")

cat("Total simulations to run:", nrow(simInfo), "\n\n")

# ---- RUN LANDIS-II SEQUENTIALLY --------------------------------------------

for (i in seq_len(nrow(simInfo))) {
  simFolder <- file.path(simOutputDir, simIDs[i])

  cat("------------------------------------------------------\n")
  cat("Running simulation", simIDs[i],
      "(", i, "of", nrow(simInfo), ")",
      "| scenario:", simInfo[i, "scenario"],
      "| ND:", simInfo[i, "ND_scenario"], "\n")
  cat("Started:", format(Sys.time()), "\n")

  ## Update README with system info
  readmePath <- file.path(simFolder, "README.txt")
  if (file.exists(readmePath)) {
    readmeOld <- readLines(readmePath)
    lastCol   <- tail(colnames(simInfo), 1)
    cutLine   <- which(grepl(lastCol, readmeOld))
    if (length(cutLine) > 0)
      readmeOld <- readmeOld[seq_len(cutLine[1])]

    writeLines(
      c(readmeOld, "",
        "#############################################################",
        "########### System Info — Narval",
        "#############################################################",
        capture.output(print(as.data.frame(Sys.info())))),
      readmePath
    )
  }

  ## Run LANDIS-II using system() — Linux equivalent of shell() on Windows
exitCode <- tryCatch({
    system(paste0("module load apptainer && ", landisCmd, " 'cd ", shQuote(simFolder), " && dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt'"),
           wait = TRUE)
  }, error = function(e) {
    cat("ERROR in simulation", simIDs[i], ":", conditionMessage(e), "\n")
    return(-1)
  })

  if (!is.null(exitCode) && exitCode != 0) {
    cat("WARNING: non-zero exit code for simID", simIDs[i],
        "— check LANDIS log inside", simFolder, "\n")
  } else {
    cat("Finished:", simIDs[i], "at", format(Sys.time()), "\n")
  }

  gc()
}

cat("\n=== Stage 2 complete — all simulations finished ===\n")
