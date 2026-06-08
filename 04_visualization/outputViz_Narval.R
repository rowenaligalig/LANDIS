###################################################################
### ForCS output visualization - Narval outputs
rm(list = ls())

# ---- SET PATHS ----
outputCompiled <- "C:/Users/Rowena/Downloads/outputCompiled/"
wwd <- paste0("C:/Users/Rowena/Downloads/outputCompiled/viz_", Sys.Date())
dir.create(wwd, showWarnings = FALSE, recursive = TRUE)
setwd(wwd)

require(ggplot2)
require(dplyr)
require(tidyr)
require(scales)
require(RColorBrewer)

simName <- "simRun_2026-06-01"
a <- "mixedwood-042-51"
initYear <- 2020
unitConvFact <- 0.01

ecoInd_corr <- TRUE

treatLevels <- c("Wind" = "Wind",
                 "Wind_Sbw" = "Wind and SBW",
                 "Wind_Fire" = "Wind and Fire",
                 "Wind_Sbw_Fire" = "Wind, SBW and Fire")

mgmtLevels <- c("baseline_45p" = "Baseline",
                "noHarvest" = "Conservation")

cols <- c("Wind" = "lightgreen",
          "Wind_Sbw" = "goldenrod3",
          "Wind_Fire" = "indianred",
          "Wind_Sbw_Fire" = "darkred")

### Load output files
outputSummary <- get(load(paste0(outputCompiled, "output_summary_simRun_2026-06-01.RData")))
fps <- read.csv(paste0(outputCompiled, "output_BioToFPS_simRun_2026-06-01.csv"))
AGB <- get(load(paste0(outputCompiled, "output_bio_simRun_2026-06-01.RData")))

### Rename scenarios
outputSummary <- outputSummary %>%
  filter(variable != "mgmtScenarioName") %>%
  mutate(value = as.numeric(value),
         ND_scenarioName = factor(treatLevels[match(as.character(ND_scenario), names(treatLevels))],
                                  levels = treatLevels),
         mgmtScenarioName = factor(mgmtLevels[match(as.character(mgmtScenarioName), names(mgmtLevels))],
                                   levels = mgmtLevels))
outputSummary <- droplevels(outputSummary)

cat("Visualization script loaded successfully!\n")
cat("Edit output paths and run sections as needed.\n")
