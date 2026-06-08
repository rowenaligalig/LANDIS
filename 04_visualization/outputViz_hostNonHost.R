###################################################################
### Host vs Non-Host AGB visualization
### Host species: ABIE.BAL, PICE.GLA, PICE.MAR
rm(list = ls())

outputCompiled <- "C:/Users/Rowena/Downloads/outputCompiled/"
wwd <- paste0("C:/Users/Rowena/Downloads/outputCompiled/viz_host_", Sys.Date())
dir.create(wwd, showWarnings = FALSE, recursive = TRUE)
setwd(wwd)

require(ggplot2)
require(dplyr)
require(RColorBrewer)

simName <- "simRun_2026-06-01"
a <- "mixedwood-042-51"
initYear <- 2020
host_spp <- c("ABIE.BAL", "PICE.GLA", "PICE.MAR")

AGB <- get(load(paste0(outputCompiled, "output_bio_simRun_2026-06-01.RData")))

cat("Host vs Non-host script loaded!\n")
