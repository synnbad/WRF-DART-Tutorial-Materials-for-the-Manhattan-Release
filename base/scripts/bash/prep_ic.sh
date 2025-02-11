#!/bin/bash
#
# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download


echo "DEBUG: Number of arguments passed: $#"
printf "DEBUG: ARG1='%s'\nDEBUG: ARG2='%s'\nDEBUG: ARG3='%s'\nDEBUG: ARG4='%s'\n" "$1" "$2" "$3" "$4"



if [ $# -gt 0 ]; then
   n="${1}"          # Ensemble member number
   datep="${2}"      # Needed for correct path to file
   dn="${3}"
   paramfile="${4}"
else  # Values come from environment variables
   n="${mem_num}"
   datep="${date}"
   dn="${domain}"
   paramfile="${paramf}"
fi

source "$paramfile"

echo "n = $n"
echo "datep = $datep"

echo "prep_ic.sh using n=$n datep=$datep dn=$dn paramfile=$paramfile"

if [ "$dn" == "1" ]; then
   # For domain 1, use cycle_vars_a
   IFS=',' read -r -a cycle_vars_array <<< "${cycle_vars_a[*]}"
   cycle_str=$(IFS=,; echo "${cycle_vars_a[*]}")
   echo "${cycle_str}"
else
   # For other domains, use cycle_vars_b
   IFS=',' read -r -a cycle_vars_array <<< "${cycle_vars_b[*]}"
   cycle_str=$(IFS=','; echo "${cycle_vars_array[*]}")
   # echo "${cycle_str}"
fi

ensstring=$(printf "%04d" "$n")
dchar=$(printf "%02d" "$dn")

echo "out_dir = ${OUTPUT_DIR}/${datep}/PRIORS/prior_d${dchar}.${ensstring}"
echo  "run_dir = ${RUN_DIR}/advance_temp${n}/wrfinput_d${dchar}"

echo "dchar = $dchar"
echo "ensstring = $ensstring"

ncks -A -v "${cycle_str}" \
     "${OUTPUT_DIR}/${datep}/PRIORS/prior_d${dchar}.${ensstring}" \
     "${RUN_DIR}/advance_temp${n}/wrfinput_d${dchar}"

echo "n = $n"
touch "${RUN_DIR}/ic_d${dchar}_${n}_ready"
echo 'precip done'
exit 0

