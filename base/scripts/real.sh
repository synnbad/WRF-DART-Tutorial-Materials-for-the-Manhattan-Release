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

srun ${RUN_DIR}/WRF_RUN/real.exe

printf "%(%H:%M)T\n"

#if [ "$(grep "Successful completion of program real.exe" ./rsl.out.0000 | wc -l)"-eq 1 ]; then
    touch "${ICBC_DIR}/real_done"

 touch "${ICBC_DIR}/real_done"


exit 0
