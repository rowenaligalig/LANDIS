#!/bin/bash
#SBATCH --job-name=landis_stage3
#SBATCH --account=def-larosefi
#SBATCH --time=5-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=249G
#SBATCH --output=/home/rligalig/scratch/LANDIS/logs/stage3_%j.out
#SBATCH --error=/home/rligalig/scratch/LANDIS/logs/stage3_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=ligalig.rowena@courrier.uqam.ca

##############################################################################
## STAGE 3 — Process ForCS outputs
## Submit AFTER Stage 2 is complete:  sbatch submit_stage3.sh
## Or chain automatically after Stage 2:
##   sbatch --dependency=afterok:<STAGE2_JOBID> submit_stage3.sh
##
## NOTE: mem=64G is higher here because output processing reads large
##       CSV files (log_BiomassC.csv etc.) — but sequential processing
##       means only ONE simulation's data is in RAM at a time
##############################################################################

echo "=========================================="
echo "STAGE 3 started: $(date)"
echo "Node: $(hostname)"
echo "Memory allocated: $SLURM_MEM_PER_NODE MB"
echo "=========================================="

mkdir -p /home/rligalig/scratch/LANDIS/logs

## Load modules
module load StdEnv/2023
module load r/4.5.0
module load gdal/3.7.2
module load geos/3.12.0
module load proj/9.4.1

## Run Stage 3
Rscript /home/rligalig/scratch/LANDIS/LANDIS_files/sims/stage3_output.R

echo "=========================================="
echo "STAGE 3 finished: $(date)"
echo "=========================================="
