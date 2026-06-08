#!/bin/bash
#SBATCH --job-name=landis_stage1
#SBATCH --account=def-dcyr
#SBATCH --time=03:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --output=/home/rligalig/scratch/LANDIS/logs/stage1_%j.out
#SBATCH --error=/home/rligalig/scratch/LANDIS/logs/stage1_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=rligalig@uqam.ca

##############################################################################
## STAGE 1 — Prepare simulation folders
## Submit with: sbatch submit_stage1.sh
## Check job:   squeue -u $USER
## Cancel:      scancel <JOBID>
##############################################################################

echo "=========================================="
echo "STAGE 1 started: $(date)"
echo "Node: $(hostname)"
echo "CPUs allocated: $SLURM_CPUS_PER_TASK"
echo "Memory allocated: $SLURM_MEM_PER_NODE MB"
echo "=========================================="

## Create logs folder if it doesn't exist
mkdir -p /home/rligalig/scratch/LANDIS/logs

## Load required modules
## Check what is available with: module spider r
## Check gdal with:              module spider gdal
module load StdEnv/2023
module load r/4.5.0
module load gdal/3.7.2
module load geos/3.12.0
module load proj/9.3.1

## Run Stage 1
Rscript /home/rligalig/scratch/LANDIS/LANDIS_files/sims/stage1_prep.R

echo "=========================================="
echo "STAGE 1 finished: $(date)"
echo "=========================================="
