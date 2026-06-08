#!/bin/bash
#SBATCH --job-name=landis_stage2
#SBATCH --account=def-larosefi
#SBATCH --time=168:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --output=/home/rligalig/scratch/LANDIS/logs/stage2_%j.out
#SBATCH --error=/home/rligalig/scratch/LANDIS/logs/stage2_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=rligalig@uqam.ca

##############################################################################
## STAGE 2 — Run LANDIS-II simulations
## Submit AFTER Stage 1 is complete:  sbatch submit_stage2.sh
## Or chain automatically after Stage 1:
##   sbatch --dependency=afterok:<STAGE1_JOBID> submit_stage2.sh
##
## NOTE: --time=48:00:00 is a generous estimate for ~120 simulations
##       Adjust down once you know how long each simulation takes
##############################################################################

echo "=========================================="
echo "STAGE 2 started: $(date)"
echo "Node: $(hostname)"
echo "CPUs allocated: $SLURM_CPUS_PER_TASK"
echo "=========================================="

mkdir -p /home/rligalig/scratch/LANDIS/logs

## Load modules
module load StdEnv/2023
module load r/4.5.0
module load apptainer

Rscript /home/rligalig/scratch/LANDIS/LANDIS_files/sims/stage2_run.R

