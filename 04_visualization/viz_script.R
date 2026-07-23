###################################################################
###################################################################
### ForCS output visualization - Narval outputs
rm(list = ls())

# ---- SET PATHS ----
outputCompiled <- "C:/Users/Rowena/Downloads/outputCompiled/"

wwd <- paste0("C:/Users/Rowena/Downloads/outputCompiled/viz_", Sys.Date())
dir.create(wwd, showWarnings = FALSE, recursive = TRUE)
setwd(wwd)

require(dplyr)

ecoInd_corr <- TRUE
initYear <- 2020
unitConvFact <- 0.01 ### from gC/m2 to tonnes per ha
simName <- "simRun_2026-06-01"
a <- "mixedwood-042-51"
areaName <- a

carbonTbl <- list("mixedwood-042-51" = c(AAC = 1166700,
                                         area = 636270,
                                         Cdensity = .214))

require(ggplot2)
require(dplyr)
require(tidyr)
require(scales)

treatLevels <- list("mixedwood-042-51" = c("Wind" = "Wind",
                                           "Wind_Sbw" = "Wind and Spruce Budworm",
                                           "Wind_Fire" = "Wind and wildfires",
                                           "Wind_Sbw_Fire" = "Wind, Spruce Budworm and wildfires"))

mgmtLevels <- list("mixedwood-042-51" = c("baseline_45p" = "Baseline",
                                          "noHarvest" = "Conservation"))

cols <- list("mixedwood-042-51" = c("Wind" = "lightgreen",
                                    "Wind_Sbw" = "goldenrod3",
                                    "Wind_Fire" = "indianred",
                                    "Wind_Sbw_Fire" = "darkred"))


spGr <- c("ABIE.BAL" = "Fir/Spruce/Pine/Larch",
          "ACER.RUB" = "tolerant hardwoods",
          "ACER.SAH" = "tolerant hardwoods",
          "BETU.ALL" = "tolerant hardwoods",
          "BETU.PAP" = "intolerant hardwoods",
          "FAGU.GRA" = "tolerant hardwoods",
          "LARI.LAR" = "Fir/Spruce/Pine/Larch",
          "PICE.GLA" = "Fir/Spruce/Pine/Larch",
          "PICE.MAR" = "Fir/Spruce/Pine/Larch",
          "PICE.RUB" = "Fir/Spruce/Pine/Larch",
          "PINU.BAN" = "Fir/Spruce/Pine/Larch",
          "PINU.RES" = "Red and White Pines",
          "PINU.STR" = "Red and White Pines",
          "POPU.TRE" = "intolerant hardwoods",
          "QUER.RUB" = "tolerant hardwoods",
          "THUJ.SPP.ALL" = "Thuja",
          "TSUG.CAN" = "Tsuga")

spGrCol <- c("Fir/Spruce/Pine/Larch" = "darkolivegreen",
             "intolerant hardwoods" = "lemonchiffon3",
             "tolerant hardwoods" = "green3",
             "Red and White Pines" = "coral4",
             "Thuja" = "orange3",
             "Tsuga" = "coral1")
spGr <- factor(spGr, levels = names(spGrCol))

################################################################################
### Load output files
outputSummary <- get(load(paste0(outputCompiled, "output_summary_simRun_2026-06-01.RData")))
fps <- read.csv(paste0(outputCompiled, "output_BioToFPS_simRun_2026-06-01.csv"))
AGB <- get(load(paste0(outputCompiled, "output_bio_simRun_2026-06-01.RData")))

################################################################################
### NEP correction (bug in ForCS v3.1 and before)
if (ecoInd_corr) {
  variableLvl <- levels(outputSummary$variable)
  df <- pivot_wider(outputSummary, names_from = variable, values_from = value) %>%
    mutate(totalC = ABio + BBio + TotalDOM) %>%
    group_by(simID) %>%
    arrange(Time) %>%
    mutate(NBPcorr = totalC - lag(totalC)) %>%
    ungroup() %>%
    mutate(distOutflux = NEP - NBP,
           NBP = NBPcorr,
           NEP = NBP + distOutflux,
           NPP = NEP + Rh,
           NetGrowth = NPP - Turnover) %>%
    dplyr::select(simID, Time,
                  ABio, BBio, TotalDOM, DelBio, Turnover,
                  NetGrowth, NPP, Rh, NEP, NBP) %>%
    pivot_longer(cols = c("ABio", "BBio", "TotalDOM", "DelBio", "Turnover",
                          "NetGrowth", "NPP", "Rh", "NEP", "NBP"),
                 names_to = "variable",
                 values_to = "valueCorr")
  outputSummary <- left_join(outputSummary, df) %>%
    mutate(value = valueCorr,
           variable = factor(variable, levels = variableLvl)) %>%
    dplyr::select(-valueCorr)
}

################################################################################
### Rename scenarios
outputSummary <- outputSummary %>%
  filter(variable != "mgmtScenarioName") %>%
  mutate(value = as.numeric(value)) %>%
  mutate(ND_scenarioName = factor(treatLevels[[a]][match(as.character(ND_scenario), names(treatLevels[[a]]))],
                                  levels = treatLevels[[a]]),
         mgmtScenarioName = factor(mgmtLevels[[a]][match(as.character(mgmtScenarioName), names(mgmtLevels[[a]]))],
                                   levels = mgmtLevels[[a]]))
outputSummary <- droplevels(outputSummary)

AGB <- AGB %>%
  mutate(ND_scenarioName = factor(treatLevels[[a]][match(as.character(ND_scenario), names(treatLevels[[a]]))],
                                  levels = treatLevels[[a]]),
         mgmtScenarioName = factor(mgmtLevels[[a]][match(as.character(mgmtScenarioName), names(mgmtLevels[[a]]))],
                                   levels = mgmtLevels[[a]]))

fps <- fps %>%
  mutate(ND_scenarioName = factor(treatLevels[[a]][match(as.character(ND_scenario), names(treatLevels[[a]]))],
                                  levels = treatLevels[[a]]),
         mgmtScenarioName = factor(mgmtLevels[[a]][match(as.character(mgmtScenarioName), names(mgmtLevels[[a]]))],
                                   levels = mgmtLevels[[a]]))

################################################################################
### Carbon pools
variableLvl <- c("TotalEcosys", "TotalDOM", "ABio", "BBio")

df <- outputSummary %>%
  filter(Time >= 1, variable %in% variableLvl) %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time, variable) %>%
  summarise(value = mean(value),
            mgmtArea_ha = unique(mgmtArea_ha)) %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time, variable) %>%
  summarise(valueTotal = sum(value * mgmtArea_ha),
            mgmtArea_ha = sum(mgmtArea_ha)) %>%
  mutate(value = valueTotal / mgmtArea_ha) %>%
  as.data.frame()

df <- df %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time) %>%
  summarise(valueTotal = sum(valueTotal),
            mgmtArea_ha = unique(mgmtArea_ha)) %>%
  mutate(value = valueTotal / mgmtArea_ha,
         variable = "TotalEcosys") %>%
  as.data.frame() %>%
  rbind(df) %>%
  mutate(variable = factor(variable, levels = variableLvl))

p <- ggplot(df, aes(x = initYear + Time, y = value * unitConvFact,
                    linetype = mgmtScenarioName,
                    colour = ND_scenario)) +
  facet_grid(variable ~ scenario, scale = "free") +
  theme_bw() +
  scale_color_manual(name = "Natural disturbance\nscenario",
                     values = cols[[a]],
                     labels = treatLevels[[a]]) +
  scale_linetype_manual(name = "Management\nscenario",
                        values = c("Baseline" = "solid",
                                   "Conservation" = "dotted")) +
  geom_line(linewidth = 0.5) +
  theme(plot.caption = element_text(size = rel(.5), hjust = 0),
        axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Evolution of carbon density",
       subtitle = paste(areaName, simName),
       x = "",
       y = expression(paste("tonnes C", " ha"^"-1", "\n")))

pHeight <- 1 + 1.5 * length(unique(df$variable))
pWidth <- 4 + 3 * length(unique(df$scenario))

png(filename = paste0("pools_", simName, ".png"),
    width = pWidth, height = 6, units = "in", res = 600, pointsize = 10)
print(p)
dev.off()
cat("Saved: pools plot\n")

################################################################################
### Carbon fluxes
variableLvl <- c("DelBio", "Turnover", "NetGrowth", "NPP", "Rh", "NEP", "NBP")

caption <- c("DelBio: Annual change in biomass stocks",
             "Turnover: Annual transfer of biomass to dead organic matter",
             "NetGrowth: Change in biomass from growth alone",
             "NPP: Net Primary Production",
             "Rh: Heterotrophic respiration",
             "NEP: Net Ecosystem Productivity",
             "NBP: Net Biome Productivity")

df <- outputSummary %>%
  filter(Time >= 1,
         mgmtID >= 10000 | mgmtID == 1,
         variable %in% variableLvl) %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           replicate, Time, variable) %>%
  summarize(totalArea = sum(mgmtArea_ha),
            value = weighted.mean(value, mgmtArea_ha)) %>%
  ungroup() %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time, variable) %>%
  summarise(value = mean(value))

p <- ggplot(df, aes(x = initYear + Time, y = value * unitConvFact,
                    linetype = mgmtScenarioName,
                    colour = ND_scenario)) +
  facet_grid(variable ~ scenario, scale = "free") +
  theme_bw() +
  geom_hline(yintercept = 0, linetype = 1, color = "grey25", size = 0.35) +
  geom_line() +
  scale_color_manual(name = "Natural disturbance\nscenario",
                     values = cols[[a]],
                     labels = treatLevels[[a]]) +
  scale_linetype_manual(name = "Management\nscenario",
                        values = c("Baseline" = "solid",
                                   "Conservation" = "dotted")) +
  theme(plot.caption = element_text(size = rel(.5), hjust = 0),
        axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Carbon dynamics",
       subtitle = paste(areaName, simName),
       x = "",
       y = expression(paste("tonnes C", " ha"^"-1", " yr"^"-1", "\n")),
       caption = paste(caption, collapse = "\n"))

png(filename = paste0("fluxes_", simName, ".png"),
    width = 7, height = 8, units = "in", res = 600, pointsize = 10)
print(p + theme(legend.text = element_text(size = rel(.75))))
dev.off()
cat("Saved: fluxes plot\n")

################################################################################
### Fluxes relative to Wind_Sbw_Fire baseline
dfRef <- df %>%
  filter(ND_scenario == "Wind_Sbw_Fire" & mgmtScenario == "baseline_45p")

dfRel <- df %>%
  left_join(dfRef, by = c("areaName", "scenario", "Time", "variable")) %>%
  mutate(value.rel = value.x - value.y,
         ND_scenario = ND_scenario.x,
         ND_scenarioName = ND_scenarioName.x,
         mgmtScenario = mgmtScenario.x,
         mgmtScenarioName = mgmtScenarioName.x) %>%
  dplyr::select(areaName, scenario, ND_scenario, ND_scenarioName,
                mgmtScenario, mgmtScenarioName,
                Time, variable, value.x, value.rel)

p <- ggplot(dfRel, aes(x = initYear + Time, y = value.rel * unitConvFact,
                       linetype = mgmtScenarioName,
                       colour = ND_scenario)) +
  facet_grid(variable ~ scenario, scale = "free") +
  theme_bw() +
  geom_hline(yintercept = 0, linetype = 1, color = "grey25", size = 0.35) +
  geom_line() +
  scale_color_manual(name = "Natural disturbance\nscenario",
                     values = cols[[a]],
                     labels = treatLevels[[a]]) +
  scale_linetype_manual(name = "Management\nscenario",
                        values = c("Baseline" = "solid",
                                   "Conservation" = "dotted")) +
  labs(title = 'Carbon dynamics\nRelative to "Wind_Sbw_Fire / Baseline" scenario',
       subtitle = paste(areaName, simName),
       x = "",
       y = expression(paste("tonnes C", " ha"^"-1", " yr"^"-1", "\n")))

png(filename = paste0("fluxesRel_", simName, ".png"),
    width = 7, height = 8, units = "in", res = 600, pointsize = 10)
print(p + theme(legend.text = element_text(size = rel(.75))))
dev.off()
cat("Saved: relative fluxes plot\n")

################################################################################
### Cumulative relative fluxes
dfRelCumul <- dfRel %>%
  group_by(areaName, scenario, ND_scenario, ND_scenarioName,
           mgmtScenario, mgmtScenarioName, variable) %>%
  arrange(Time) %>%
  mutate(value.rel.cumul = cumsum(replace_na(value.rel, 0)))

p <- ggplot(dfRelCumul, aes(x = initYear + Time, y = value.rel.cumul * unitConvFact,
                            linetype = mgmtScenarioName,
                            colour = ND_scenario)) +
  facet_grid(variable ~ scenario, scale = "free") +
  theme_bw() +
  geom_hline(yintercept = 0, linetype = 1, color = "grey25", size = 0.35) +
  geom_line() +
  scale_color_manual(name = "Natural disturbance\nscenario",
                     values = cols[[a]],
                     labels = treatLevels[[a]]) +
  scale_linetype_manual(name = "Management\nscenario",
                        values = c("Baseline" = "solid",
                                   "Conservation" = "dotted")) +
  labs(title = 'Carbon dynamics\nCumulative differences relative to "Wind_Sbw_Fire / Baseline"',
       subtitle = paste(areaName, simName),
       x = "",
       y = expression(paste("tonnes C", " ha"^"-1", " yr"^"-1", "\n")))

png(filename = paste0("fluxesRelCumul_", simName, ".png"),
    width = 7, height = 8, units = "in", res = 600, pointsize = 10)
print(p + theme(legend.text = element_text(size = rel(.75))))
dev.off()
cat("Saved: cumulative relative fluxes plot\n")

################################################################################
### Forest Products Sector (FPS)
require(RColorBrewer)

df <- fps %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           species, Time) %>%
  summarise(BioToFPS_tonnesCTotal = mean(BioToFPS_tonnesCTotal),
            areaManagedTotal_ha = unique(areaManagedTotal_ha),
            areaHarvestedTotal_ha = mean(areaHarvestedTotal_ha)) %>%
  mutate(spGr = spGr[species]) %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           spGr, Time) %>%
  summarise(BioToFPS_tonnesCTotal = sum(BioToFPS_tonnesCTotal),
            areaManagedTotal_ha = unique(areaManagedTotal_ha),
            areaHarvestedTotal_ha = unique(areaHarvestedTotal_ha))

dfTotal <- df %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time) %>%
  summarise(BioToFPS_tonnesCTotal = sum(BioToFPS_tonnesCTotal),
            areaManagedTotal_ha = unique(areaManagedTotal_ha),
            areaHarvestedTotal_ha = mean(areaHarvestedTotal_ha))

labdf <- df %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName) %>%
  summarise(areaManagedTotal_ha = unique(areaManagedTotal_ha),
            areaHarvestedTotal_ha = mean(areaHarvestedTotal_ha)) %>%
  mutate(cEquivAAC = areaManagedTotal_ha / carbonTbl[[a]]["area"] *
           carbonTbl[[a]]["AAC"] * carbonTbl[[a]]["Cdensity"])

yMax <- df %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time) %>%
  summarise(BioToFPS_tonnesCTotal = sum(BioToFPS_tonnesCTotal / areaHarvestedTotal_ha)) %>%
  group_by() %>%
  summarise(yMax = max(BioToFPS_tonnesCTotal))
yMax <- as.numeric(yMax)

pWidth <- 4 * length(unique(df$scenario)) + 4
pHeight <- 1 + 2.25 * length(unique(df$ND_scenarioName))

png(filename = paste0("fps_spp_", simName, ".png"),
    width = pWidth, height = pHeight, units = "in", res = 600, pointsize = 10)
ggplot(df, aes(x = initYear + Time, y = BioToFPS_tonnesCTotal)) +
  stat_summary(aes(fill = spGr), fun.y = "sum", geom = "area", position = "stack") +
  facet_grid(ND_scenarioName ~ mgmtScenarioName) +
  scale_fill_manual(values = spGrCol, name = NULL) +
  scale_y_continuous(labels = label_number(suffix = "kt C", scale = 1e-3)) +
  theme_dark() +
  theme(plot.caption = element_text(size = rel(.5), hjust = 0),
        axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Transfers to harvested wood products",
       subtitle = paste(areaName, simName),
       x = "",
       y = "Transfers to HWP")
dev.off()
cat("Saved: FPS species plot\n")

################################################################################
### Aboveground biomass by species
df <- AGB %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time, replicate, species) %>%
  summarise(agb_tonnesTotal = sum(agb_tonnesTotal),
            areaTotal_ha = sum(unique(landtypeArea_ha))) %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time, species) %>%
  summarise(agb_tonnesTotal = mean(agb_tonnesTotal),
            areaTotal_ha = unique(areaTotal_ha)) %>%
  as.data.frame()

colourCount <- length(unique(df$species))
getPalette <- colorRampPalette(brewer.pal(9, "Set1"))
pHeight <- .5 + 3 * length(unique(df$mgmtScenario))
pWidth <- .5 + 3 * length(unique(df$ND_scenario))

png(filename = paste0("agb_sppStack_", simName, ".png"),
    width = pWidth, height = pHeight, units = "in", res = 600, pointsize = 10)
ggplot(df, aes(x = 2020 + Time, y = agb_tonnesTotal / areaTotal_ha)) +
  stat_summary(aes(fill = species), fun.y = "sum", geom = "area", position = "stack") +
  facet_grid(mgmtScenarioName ~ ND_scenarioName) +
  scale_fill_manual("", values = getPalette(colourCount)) +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Evolution of landscape composition - Aboveground biomass",
       subtitle = paste(areaName, simName),
       x = "",
       y = expression(paste("tonnes", " ha"^"-1")))
dev.off()
cat("Saved: AGB species stack plot\n")

################################################################################
### Aboveground biomass by age classes
df <- AGB %>%
  mutate(mgmt = mgmtScenario) %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time, replicate, ageClass, species) %>%
  summarise(agb_tonnesTotal = sum(agb_tonnesTotal),
            areaTotal_ha = sum(unique(landtypeArea_ha))) %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           ageClass, Time, species) %>%
  summarise(agb_tonnesTotal = mean(agb_tonnesTotal),
            areaTotal_ha = unique(areaTotal_ha)) %>%
  as.data.frame()

cols <- rev(brewer.pal(n = 9, name = "Greens")[3:9])
acLvls <- rev(levels(df$ageClass))
df[, "ageClass"] <- factor(df$ageClass, levels = acLvls)

pHeight <- .5 + 3 * length(unique(df$mgmtScenario))
pWidth <- .5 + 3 * length(unique(df$ND_scenario))

png(filename = paste0("agb_AgeClassStacked_", simName, ".png"),
    width = pWidth, height = pHeight, units = "in", res = 600, pointsize = 10)
ggplot(df, aes(x = 2020 + Time, y = agb_tonnesTotal / areaTotal_ha)) +
  stat_summary(aes(fill = ageClass), fun.y = "sum", geom = "area", position = "stack") +
  facet_grid(mgmtScenarioName ~ ND_scenarioName, scales = "fixed") +
  scale_fill_manual("Age classes", values = cols) +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = paste0("Evolution of age structure - ", areaName),
       subtitle = simName,
       x = "",
       y = expression(paste("tonnes", " ha"^"-1")))
dev.off()
cat("Saved: AGB age class plot\n")

cat("\n=== All visualization plots saved to:", wwd, "===\n")


###############
###################################################################
### AGB visualization by climate scenario


# ---- SET PATHS ----
outputCompiled <- "C:/Users/Rowena/Downloads/outputCompiled/"
wwd <- paste0("C:/Users/Rowena/Downloads/outputCompiled/viz_AGB_", Sys.Date())
dir.create(wwd, showWarnings = FALSE, recursive = TRUE)
setwd(wwd)

require(ggplot2)
require(dplyr)
require(RColorBrewer)

simName <- "simRun_2026-06-01"
a <- "mixedwood-042-51"
initYear <- 2020

treatLevels <- c("Wind" = "Wind",
                 "Wind_Sbw" = "Wind and SBW",
                 "Wind_Fire" = "Wind and Fire",
                 "Wind_Sbw_Fire" = "Wind, SBW and Fire")

mgmtLevels <- c("baseline_45p" = "Baseline",
                "noHarvest" = "Conservation")

spGr <- c("ABIE.BAL" = "Fir/Spruce/Pine/Larch",
          "ACER.RUB" = "tolerant hardwoods",
          "ACER.SAH" = "tolerant hardwoods",
          "BETU.ALL" = "tolerant hardwoods",
          "BETU.PAP" = "intolerant hardwoods",
          "FAGU.GRA" = "tolerant hardwoods",
          "LARI.LAR" = "Fir/Spruce/Pine/Larch",
          "PICE.GLA" = "Fir/Spruce/Pine/Larch",
          "PICE.MAR" = "Fir/Spruce/Pine/Larch",
          "PICE.RUB" = "Fir/Spruce/Pine/Larch",
          "PINU.BAN" = "Fir/Spruce/Pine/Larch",
          "PINU.RES" = "Red and White Pines",
          "PINU.STR" = "Red and White Pines",
          "POPU.TRE" = "intolerant hardwoods",
          "QUER.RUB" = "tolerant hardwoods",
          "THUJ.SPP.ALL" = "Thuja",
          "TSUG.CAN" = "Tsuga")

spGrCol <- c("Fir/Spruce/Pine/Larch" = "darkolivegreen",
             "intolerant hardwoods" = "lemonchiffon3",
             "tolerant hardwoods" = "green3",
             "Red and White Pines" = "coral4",
             "Thuja" = "orange3",
             "Tsuga" = "coral1")
spGr <- factor(spGr, levels = names(spGrCol))

### Load AGB output
AGB <- get(load(paste0(outputCompiled, "output_bio_simRun_2026-06-01.RData")))

AGB <- AGB %>%
  mutate(ND_scenarioName = factor(treatLevels[match(as.character(ND_scenario), names(treatLevels))],
                                  levels = treatLevels),
         mgmtScenarioName = factor(mgmtLevels[match(as.character(mgmtScenarioName), names(mgmtLevels))],
                                   levels = mgmtLevels))

################################################################################
### AGB by species — faceted by climate scenario
df <- AGB %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time, replicate, species) %>%
  summarise(agb_tonnesTotal = sum(agb_tonnesTotal),
            areaTotal_ha = sum(unique(landtypeArea_ha))) %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time, species) %>%
  summarise(agb_tonnesTotal = mean(agb_tonnesTotal),
            areaTotal_ha = unique(areaTotal_ha)) %>%
  as.data.frame()

colourCount <- length(unique(df$species))
getPalette <- colorRampPalette(brewer.pal(9, "Set1"))

## Plot 1: ND scenario × climate scenario (one panel per mgmt)
for(mgmt in unique(df$mgmtScenarioName)) {
  df_sub <- df %>% filter(mgmtScenarioName == mgmt)
  
  p <- ggplot(df_sub, aes(x = initYear + Time, y = agb_tonnesTotal / areaTotal_ha)) +
    stat_summary(aes(fill = species), fun.y = "sum", geom = "area", position = "stack") +
    facet_grid(scenario ~ ND_scenarioName) +
    scale_fill_manual("", values = getPalette(colourCount)) +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1),
          legend.text = element_text(size = rel(0.75))) +
    labs(title = paste0("AGB by species — ", mgmt),
         subtitle = paste(a, simName),
         x = "",
         y = expression(paste("tonnes", " ha"^"-1")))
  
  png(filename = paste0("agb_spp_climate_", mgmt, "_", simName, ".png"),
      width = 12, height = 8, units = "in", res = 300, pointsize = 10)
  print(p)
  dev.off()
  cat("Saved: AGB species plot —", mgmt, "\n")
}

################################################################################
### AGB by age class — faceted by climate scenario
df_age <- AGB %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time, replicate, ageClass, species) %>%
  summarise(agb_tonnesTotal = sum(agb_tonnesTotal),
            areaTotal_ha = sum(unique(landtypeArea_ha))) %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           ageClass, Time) %>%
  summarise(agb_tonnesTotal = mean(agb_tonnesTotal),
            areaTotal_ha = unique(areaTotal_ha)) %>%
  as.data.frame()

cols_age <- rev(brewer.pal(n = 9, name = "Greens")[3:9])
acLvls <- rev(levels(df_age$ageClass))
df_age[, "ageClass"] <- factor(df_age$ageClass, levels = acLvls)

## Plot 2: age class × climate scenario (one panel per mgmt)
for(mgmt in unique(df_age$mgmtScenarioName)) {
  df_sub <- df_age %>% filter(mgmtScenarioName == mgmt)
  
  p <- ggplot(df_sub, aes(x = initYear + Time, y = agb_tonnesTotal / areaTotal_ha)) +
    stat_summary(aes(fill = ageClass), fun.y = "sum", geom = "area", position = "stack") +
    facet_grid(scenario ~ ND_scenarioName, scales = "fixed") +
    scale_fill_manual("Age classes", values = cols_age) +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    labs(title = paste0("Age structure — ", mgmt),
         subtitle = paste(a, simName),
         x = "",
         y = expression(paste("tonnes", " ha"^"-1")))
  
  png(filename = paste0("agb_ageClass_climate_", mgmt, "_", simName, ".png"),
      width = 12, height = 8, units = "in", res = 300, pointsize = 10)
  print(p)
  dev.off()
  cat("Saved: Age class plot —", mgmt, "\n")
}

cat("\n=== All AGB plots saved to:", wwd, "===\n")


################################################################################
### Host vs Non-Host AGB by climate scenario
### Host species: ABIE.BAL, PICE.GLA, PICE.MAR
### Non-host: all others
################################################################################

# Add to the existing script after loading AGB

host_spp <- c("ABIE.BAL", "PICE.GLA", "PICE.MAR")

df_host <- AGB %>%
  mutate(hostStatus = ifelse(species %in% host_spp, "Host", "Non-host")) %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time, replicate, hostStatus) %>%
  summarise(agb_tonnesTotal = sum(agb_tonnesTotal),
            areaTotal_ha = sum(unique(landtypeArea_ha))) %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time, hostStatus) %>%
  summarise(agb_tonnesTotal = mean(agb_tonnesTotal),
            areaTotal_ha = unique(areaTotal_ha)) %>%
  mutate(agb_tonnesPerHa = agb_tonnesTotal / areaTotal_ha) %>%
  as.data.frame()

hostCols <- c("Host" = "darkgreen", "Non-host" = "goldenrod3")

## Plot per management type
for(mgmt in unique(df_host$mgmtScenarioName)) {
  df_sub <- df_host %>% filter(mgmtScenarioName == mgmt)
  
  ## Stacked area
  p1 <- ggplot(df_sub, aes(x = initYear + Time, y = agb_tonnesPerHa,
                           fill = hostStatus)) +
    geom_area(position = "stack") +
    facet_grid(scenario ~ ND_scenarioName) +
    scale_fill_manual("", values = hostCols) +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    labs(title = paste0("Host vs Non-host AGB — ", mgmt),
         subtitle = paste(a, simName),
         x = "",
         y = expression(paste("tonnes", " ha"^"-1")))
  
  png(filename = paste0("agb_hostVsNonHost_stacked_", mgmt, "_", simName, ".png"),
      width = 12, height = 8, units = "in", res = 300, pointsize = 10)
  print(p1)
  dev.off()
  cat("Saved: Host vs Non-host stacked —", mgmt, "\n")
  
  ## Line plot — easier to compare across scenarios
  p2 <- ggplot(df_sub, aes(x = initYear + Time, y = agb_tonnesPerHa,
                           colour = ND_scenario,
                           linetype = hostStatus)) +
    facet_grid(scenario ~ mgmtScenarioName, scales = "free_y") +
    geom_line() +
    scale_color_manual(name = "Disturbance scenario",
                       values = c("Wind" = "lightgreen",
                                  "Wind_Sbw" = "goldenrod3",
                                  "Wind_Fire" = "indianred",
                                  "Wind_Sbw_Fire" = "darkred")) +
    scale_linetype_manual(name = "",
                          values = c("Host" = "solid",
                                     "Non-host" = "dashed")) +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    labs(title = paste0("Host vs Non-host AGB — ", mgmt),
         subtitle = paste(a, simName),
         x = "",
         y = expression(paste("tonnes", " ha"^"-1")))
  
  png(filename = paste0("agb_hostVsNonHost_lines_", mgmt, "_", simName, ".png"),
      width = 12, height = 8, units = "in", res = 300, pointsize = 10)
  print(p2)
  dev.off()
  cat("Saved: Host vs Non-host lines —", mgmt, "\n")
}

## Also plot host proportion over time
df_prop <- df_host %>%
  group_by(areaName, scenario,
           ND_scenario, ND_scenarioName, mgmtScenario, mgmtScenarioName,
           Time) %>%
  mutate(totalAGB = sum(agb_tonnesTotal)) %>%
  filter(hostStatus == "Host") %>%
  mutate(hostProportion = agb_tonnesTotal / totalAGB * 100)

for(mgmt in unique(df_prop$mgmtScenarioName)) {
  df_sub <- df_prop %>% filter(mgmtScenarioName == mgmt)
  
  p3 <- ggplot(df_sub, aes(x = initYear + Time, y = hostProportion,
                           colour = ND_scenario)) +
    facet_grid(scenario ~ .) +
    geom_line() +
    scale_color_manual(name = "Disturbance scenario",
                       values = c("Wind" = "lightgreen",
                                  "Wind_Sbw" = "goldenrod3",
                                  "Wind_Fire" = "indianred",
                                  "Wind_Sbw_Fire" = "darkred")) +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    geom_hline(yintercept = 50, linetype = "dashed", color = "grey50") +
    labs(title = paste0("Host species proportion of total AGB — ", mgmt),
         subtitle = paste(a, simName),
         x = "",
         y = "Host AGB (%)")
  
  png(filename = paste0("agb_hostProportion_", mgmt, "_", simName, ".png"),
      width = 10, height = 8, units = "in", res = 300, pointsize = 10)
  print(p3)
  dev.off()
  cat("Saved: Host proportion —", mgmt, "\n")
}

cat("\n=== Host vs Non-host plots saved! ===\n")