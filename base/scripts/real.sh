#!/bin/bash



#======================================
#SBATCH --job-name=run_real
#SBATCH -A chipilskigroup_q
#SBATCH --time=00:10:00
#SBATCH --partition=chipilskigroup_q
#SBATCH --qos=normal
#SBATCH --output=run_real.out
#SBATCH --error=run_real.err
#SBATCH --ntasks=25
#SBATCH --export=ALL
#======================================


paramfile="$1"
source "$paramfile"

#  Change to the ICBC_DIR directory
cd /gpfs/home/sa24m/scratch/base/icbc
#cd ${ICBC_DIR}
# Execute the WRF real.exe program using MPI
# echo ${RUN_DIR}
#srun ${RUN_DIR}/WRF_RUN/real.exe
srun /gpfs/home/sa24m/scratch/base/rundir/WRF_RUN/real.exe

# Check if the program completed successfully
if grep -q "SUCCESS COMPLETE REAL_EM INIT" ./rsl.out.0000; then
    # Create a file to indicate successful completion
    touch /gpfs/home/sa24m/scratch/base/icbc/real_done
fi


