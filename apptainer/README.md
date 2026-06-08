# Apptainer Setup for LANDIS-II v7 on Narval

## Overview
LANDIS-II v7 requires .NET 2.0 which is not available on Narval.
We use an Apptainer (.sif file) to run LANDIS-II in a container.

## Steps to build the Apptainer

### 1. Install Docker Desktop
Download from: https://www.docker.com/products/docker-desktop/
On Windows, WSL 2 must be enabled first.

### 2. Build the Docker image
```bash
cd Docker_Images/Clean_Docker_LANDIS-II_7_AllExtensions
docker build -t landis_ii_v7_linux_rowena ./
```

### 3. Save Docker image to tar file
```bash
docker save landis_ii_v7_linux_rowena -o landis_ii_v7_linux_rowena.tar
```

### 4. Build Apptainer .sif file
```bash
docker run --rm --privileged \
  --mount type=bind,src=${PWD},dst=/tmp \
  kaczmarj/apptainer:latest build \
  /tmp/landis_ii_v7_linux_rowena.sif \
  docker-archive:///tmp/landis_ii_v7_linux_rowena.tar
```

### 5. Upload to Narval
```bash
scp landis_ii_v7_linux_rowena.sif rligalig@narval.alliancecan.ca:~/scratch/LANDIS/apptainer/
```

## Running LANDIS-II with Apptainer on Narval
```bash
module load apptainer
apptainer exec -C -B /home/rligalig/scratch/LANDIS/LANDIS_files/simRun_DATE \
  /home/rligalig/scratch/LANDIS/apptainer/landis_ii_v7_linux_rowena.sif \
  /bin/sh -c "cd SIMFOLDER && dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt"
```

## Input file fixes required
The Apptainer uses slightly different extension versions than the Windows installation.
The following fixes were applied to input files before running:

### forCS-input.txt
- Comment out `DisturbanceMatrixFile` line
- Insert missing sections before `ANPPTimeSeries`:
  - `DisturbFireTransferDOM`
  - `DisturbOtherTransferDOM`
  - `DisturbFireTransferBiomass`
  - `DisturbOtherTransferBiomass`

### base-wind.txt
- Rename `LogFile` to `SummaryLogFile`
- Add `EventLogFile wind/event-log.csv` at end

### base-bda.txt
- Must use main BDA file (`LandisData "Base BDA"`)
- Update `BDAInputFiles` to list all budworm agent files

### Base-BDA_budworm-*.txt
- Replace `SeedEpicenterCoeff` with `SeedEpicenterMax`
- Add `SeedEpicenterCoeff` after `SeedEpicenterMax`
