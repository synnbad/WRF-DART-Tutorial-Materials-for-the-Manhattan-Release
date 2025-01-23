#!/bin/bash


#======================================
#SBATCH --job-name=run_real
#SBATCH -A chipilskigroup_q
#SBATCH --time=00:10:00
#SBATCH --partition=chipilskigroup_q
#SBATCH --qos=normal
#SBATCH --output=run_real.out
#SBATCH --error=run_real.err
#SBATCH --ntasks=10
#SBATCH --export=ALL
#======================================



#  Change to the ICBC_DIR directory
cd /gpfs/home/sa24m/Research/base/icbc

# Execute the WRF real.exe program using MPI
srun /gpfs/home/sa24m/Research/base/rundir/WRF_RUN/real.exe

# Check if the program completed successfully
if grep -q "SUCCESS COMPLETE REAL_EM INIT" ./rsl.out.0000; then
    # Create a file to indicate successful completion
    touch /gpfs/home/sa24m/Research/base/icbc/real_done
fi

exit 0

