#!/bin/bash

datea=$1
emember=$2
paramfile=$3

source "$paramfile"

start_time=$(date +%s)
echo "host is $(hostname)"

domains=$NUM_DOMAINS

cd "${RUN_DIR}"

read -ra gdate <<< "$(echo $datea 0 -g | ${RUN_DIR}/advance_time)"
read -ra gdatef <<< "$(echo $datea $ASSIM_INT_HOURS -g | ${RUN_DIR}/advance_time)"


yyyy=$(echo "$datea" | cut -b1-4)

mm=$(echo "$datea" | cut -b5-6)

dd=$(echo "$datea" | cut -b7-8)

hh=$(echo "$datea" | cut -b9-10)

nn="00"

ss="00"

echo "$start_time" > "${RUN_DIR}/start_member_${emember}"

# Go into member directory and generate the needed wrf.info file
cd "${RUN_DIR}/advance_temp${emember}"

icnum=$(echo "$emember + 10000" | bc | cut -b2-5)
if [ -e "${RUN_DIR}/advance_temp${emember}/wrf.info" ]; then
    ${REMOVE} "${RUN_DIR}/advance_temp${emember}/wrf.info"
fi

touch wrf.info

if [ "$SUPER_PLATFORM" == "slurm" ]; then
    cat > "${RUN_DIR}/advance_temp${emember}/wrf.info" << EOF
${gdatef[1]}  ${gdatef[0]}
${gdate[1]}   ${gdate[0]}
$yyyy $mm $dd $hh $nn $ss
           1
srun -n50 ./wrf.exe

EOF

elif [ "$SUPER_PLATFORM" == "derecho" ]; then
    export MPI_SHEPHERD=false

    cat > "${RUN_DIR}/advance_temp${emember}/wrf.info" << EOF
${gdatef[1]}  ${gdatef[0]}
${gdate[1]}   ${gdate[0]}
$yyyy $mm $dd $hh $nn $ss
           $domains
#mpiexec -n 128 -ppn 128 ./wrf.exe
srun --mpi=pmix -n19 ./wrf.exe
srun ./wrf.exe
EOF
fi

cd "${RUN_DIR}"

echo "rundir first_advance"

echo "$emember" > "${RUN_DIR}/filter_control${icnum}"

echo "filter_restart_d01.${icnum}" >> "${RUN_DIR}/filter_control${icnum}"

echo "prior_d01.${icnum}" >> "${RUN_DIR}/filter_control${icnum}"

echo "icnum = ${icnum}"
echo "emember = ${emember}"
echo "NUM_DOMANAINS = $NUM_DOMAINS"

# Integrate the model forward in time
"${RUN_DIR}/new_advance_model.sh" $emember $NUM_DOMAINS "filter_control${icnum}" $paramfile


${REMOVE} "${RUN_DIR}/filter_control${icnum}"

# Move the output to the appropriate directory
mkdir -p "${OUTPUT_DIR}/${datea}/PRIORS"
mv "${RUN_DIR}/prior_d01.${icnum}" "${OUTPUT_DIR}/${datea}/PRIORS/prior_d01.${icnum}"

end_time=$(date +%s)
length_time=$((end_time - start_time))
echo "duration = $length_time"

exit 0
