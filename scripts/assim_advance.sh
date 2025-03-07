#!/bin/bash
#
# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

# Command-line arguments
module restore

datea="${1}"
emember="${2}"
paramfile="${3}"

# Source the parameter file
source "$paramfile"

echo "datea = $datea"
echo "emember = $emember"
echo "paramfile = $paramfile"

domains="$NUM_DOMAINS"

start_time=$(date +%s)
echo "host is $(hostname)"
echo "assim_advance.sh is running in $(pwd)"

echo "RUN_DIR = $RUN_DIR"

cd "$RUN_DIR"
# ls $RUN_DIR/advance_time
gdate=($(echo $datea 0h -g | "$RUN_DIR/advance_time"))
echo "gdate = $gdate"


if (( ASSIM_INT_MINUTES <= 0 )); then
  gdatef=( $(echo $datea ${ASSIM_INT_HOURS}h -g | "$RUN_DIR/advance_time") )
else
  gdatef=( $(echo $datea ${ASSIM_INT_HOURS}m -g | "$RUN_DIR/advance_time") )
fi


yyyy="${datea:0:4}"
mm="${datea:4:2}"
dd="${datea:6:2}"
hh="${datea:8:2}"
nn="00"
ss="00"

# Copy files to appropriate location
echo "$start_time" > "${RUN_DIR}/start_member_${emember}"

# Prepare the member directory
mkdir -p "${RUN_DIR}/advance_temp${emember}"

cd "${RUN_DIR}/advance_temp${emember}"
icnum=$(printf "%04d" "$((emember + 10000))")

if [[ -e "${RUN_DIR}/advance_temp${emember}/wrf.info" ]]; then
  rm -f "${RUN_DIR}/advance_temp${emember}/wrf.info"
fi
touch wrf.info

if [[ "$SUPER_PLATFORM" == "slurm" ]]; then

  echo "${gdatef[1]}  ${gdatef[0]}" > "${RUN_DIR}/advance_temp${emember}/wrf.info"
  echo "${gdate[1]}   ${gdate[0]}" >> "${RUN_DIR}/advance_temp${emember}/wrf.info"
  echo "$yyyy $mm $dd $hh $nn $ss" >> "${RUN_DIR}/advance_temp${emember}/wrf.info"
  echo "         $domains" >> "${RUN_DIR}/advance_temp${emember}/wrf.info"
  echo "srun ./wrf.exe" >> "${RUN_DIR}/advance_temp${emember}/wrf.info"


#   cat > "${RUN_DIR}/advance_temp${emember}/wrf.info" << EOF
# ${gdatef[1]}  ${gdatef[0]}
# ${gdate[1]}   ${gdate[0]}
# $yyyy $mm $dd $hh $nn $ss
#           $domains
# srun ./wrf.exe
# EOF

elif [[ "$SUPER_PLATFORM" == "derecho" ]]; then
  # module load openmpi
  cat > "${RUN_DIR}/advance_temp${emember}/wrf.info" << EOF
${gdatef[1]}  ${gdatef[0]}
${gdate[1]}   ${gdate[0]}
$yyyy $mm $dd $hh $nn $ss
           $domains
 mpiexec -n 128 -ppn 128 ./wrf.exe
EOF
fi

cd "$RUN_DIR" 

echo "$emember"                      > "${RUN_DIR}/filter_control${icnum}"
echo "filter_restart_d01.${icnum}"   >> "${RUN_DIR}/filter_control${icnum}"
echo "prior_d01.${icnum}"            >> "${RUN_DIR}/filter_control${icnum}"

# Integrate the model forward in time
"${RUN_DIR}/new_advance_model.sh" "${emember}" "$domains" "filter_control${icnum}" "$paramfile"
rm -f "${RUN_DIR}/filter_control${icnum}"

end_time=$(date +%s)
length_time=$(( end_time - start_time ))
echo "duration = $length_time"

exit 0
