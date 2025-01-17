#!/bin/bash
#
# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

# `datea` and `paramfile` are command-line arguments - OR -
# are set by a string editor (sed) command.

# Updated by Stephen Asare

datea="${1}"
paramfile="${2}"

source "$paramfile"

start_time=$(date +%s)
echo "host is $(hostname)"

cd "${RUN_DIR}"
echo "$start_time" > "${RUN_DIR}/filter_started"

# Make sure the previous results are not hanging around
[ -e "${RUN_DIR}/obs_seq.final" ] && ${REMOVE} "${RUN_DIR}/obs_seq.final"
[ -e "${RUN_DIR}/filter_done" ] && ${REMOVE} "${RUN_DIR}/filter_done"

# Run data assimilation system
if [ "$SUPER_PLATFORM" == "LSF queuing system" ]; then

   export TARGET_CPU_LIST=-1
   export FORT_BUFFERED=true
   mpirun.lsf ./filter || exit 1

elif [ "$SUPER_PLATFORM" == "derecho" ]; then

   export MPI_SHEPHERD=FALSE

   export TMPDIR=/dev/shm
   ulimit -s unlimited
   # mpiexec -n 256 -ppn 128 ./filter || exit 1
   srun -ntasks=15 ./filter || exit 1

fi

if [ -e "${RUN_DIR}/obs_seq.final" ]; then
   touch "${RUN_DIR}/filter_done"
fi

end_time=$(date +%s)
length_time=$((end_time - start_time))
echo "duration = $length_time"

exit 0
