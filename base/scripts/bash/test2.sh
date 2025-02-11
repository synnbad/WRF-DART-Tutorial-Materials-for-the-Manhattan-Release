#!/bin/sh

#SBATCH --job-name="test2"
#SBATCH -n 100
#SBATCH -A chipilskigroup_q
#SBATCH -t 00:10:00
#SBATCH --partition=chipilskigroup_q

source /gpfs/home/sa24m/Research/base/scripts/param.sh

#paramfile
echo "parameter file set"

# source paramfile
echo "parameter file sourced"

module purge
module load intel/21
module load openmpi/4.1.0
module load python/3
module load matlab/2022b
module load precompiled
module load hdf5/1.10.4
module load mvapich/2.3.5
module load netcdf/4.7.0


cd /gpfs/home/sa24m/Research/base/scripts
srun ${RUN_DIR}/WRF_RUN/real.exe

