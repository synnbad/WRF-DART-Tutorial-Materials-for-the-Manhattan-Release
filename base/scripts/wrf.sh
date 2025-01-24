#!/bin/bash
#SBATCH --job-name=run_real
#SBATCH -A chipilskigroup_q
#SBATCH --time=00:10:00
#SBATCH --partition=chipilskigroup_q
#SBATCH --qos=normal
#SBATCH --output=run_real.out
#SBATCH --error=run_real.err
#SBATCH --ntasks=10
#SBATCH --export=ALL

source /gpfs/home/sa24m/Research/base/scripts/param.sh


cd ${ICBC_DIR}


module restore

srun ${RUN_DIR}/WRF_RUN/wrf.exe

exit 0
