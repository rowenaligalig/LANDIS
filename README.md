# LANDIS-II Chapter 2 — Narval HPC Workflow

## Overview
This repository contains the scripts and documentation for running LANDIS-II v7 simulations on the Narval HPC cluster (Alliance Canada) for Chapter 2 of my PhD thesis.

**Research question:** How do post-disturbance management strategies and climate scenarios interact to shape long-term carbon dynamics and resilience in Québec mixedwood forests?

## Study area
- Landscape: mixedwood-042-51
- Resolution: 250m
- Simulation period: 2020–2095 (75 years)

## Experimental design
- 3 climate scenarios: baseline, RCP45, RCP85
- 4 disturbance combinations: Wind, Wind+SBW, Wind+SBW+Fire, Wind+Fire
- 2 management strategies: baseline harvest (45%), no harvest
- 5 replicates
- **Total: 120 simulations**

## Workflow
1. **Stage 1** — Prepare simulation folders
2. **Stage 2** — Run LANDIS-II simulations (parallel SLURM jobs)
3. **Stage 3** — Process ForCS outputs
4. **Visualization** — Generate carbon dynamics plots

## Requirements
- R 4.5.0
- LANDIS-II v7 via Apptainer (.sif file)
- Narval cluster account (Alliance Canada)

