#!/bin/bash
## Submit all 120 simulations as individual SLURM jobs

SIF=/home/rligalig/scratch/LANDIS/apptainer/landis-ii_v7_linux_rowena.sif
SIMDIR=/home/rligalig/scratch/LANDIS/LANDIS_files/simRun_2026-06-01

for simFolder in $SIMDIR/*/; do
  simID=$(basename $simFolder)
  # Skip non-simulation folders
  if [[ ! "$simID" =~ ^[0-9]+$ ]]; then
    continue
  fi
  sbatch --job-name=landis_$simID \
         --account=def-larosefi \
         --time=03-00:00:00 \
         --ntasks=1 \
         --cpus-per-task=1 \
         --mem=30G \
         --mail-type=FAIL \
         --mail-user=ligalig.rowena@courrier.uqam.ca \
         --output=/home/rligalig/scratch/LANDIS/logs/sim_${simID}_%j.out \
         --wrap="module load apptainer && apptainer exec -C -B $SIMDIR $SIF /bin/sh -c 'cd $simFolder && dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt'"
done
echo "All 120 jobs submitted!"
