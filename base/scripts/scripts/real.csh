#!/bin/csh
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




 set paramfile = ${1}
 source $paramfile

 cd ${ICBC_DIR}
 mpiexec -n 128 -ppn 128 ${RUN_DIR}/WRF_RUN/real.exe

#if ( grep "Successful completion of program real.exe" ./rsl.out.0000 | wc -l  == 1  )  touch ${I$

 touch ${ICBC_DIR}/real_done

exit 0

