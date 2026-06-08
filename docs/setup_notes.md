# Setup Notes — LANDIS-II on Narval

## System information
- Cluster: Narval (Alliance Canada)
- Account: def-larosefi
- R version: 4.5.0
- Apptainer version: loaded via module

## Key paths on Narval
- Simulation files: ~/scratch/LANDIS/LANDIS_files/
- Input files: ~/scratch/LANDIS/LANDIS_files/inputsLandis/
- Simulation output: ~/scratch/LANDIS/LANDIS_files/simRun_DATE/
- Apptainer: ~/scratch/LANDIS/apptainer/landis_ii_v7_linux_rowena.sif
- Logs: ~/scratch/LANDIS/logs/

## Modules required
```bash
module load StdEnv/2023
module load r/4.5.0
module load gdal/3.7.2
module load geos/3.12.0
module load proj/9.4.1
module load apptainer
```

## Runtime estimates
- Stage 1: ~30 minutes (120 simulations)
- Stage 2: ~5-6 hours per simulation (parallel)
- Stage 3: ~26 hours total (sequential, 249GB RAM)

## Common issues and fixes
See apptainer/README.md for input file fixes required.

## Output files
- output_summary_*.RData — carbon pools and fluxes
- output_bio_*.RData — aboveground biomass by species and age
- output_BioToFPS_*.csv — forest products sector transfers
