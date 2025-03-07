#!/bin/bash
#
# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

# =================================================
# Load the param.sh file
# Edits by Stephen Asare
source /gpfs/home/sa24m/Research/base/scripts/param.sh

# Slurm job directives
#SBATCH --job-name="gen_retro_icbc"
#SBATCH --ntasks=100
#SBATCH -A chipilskigroup_q
#SBATCH -t 00:10:00
#SBATCH --partition=chipilskigroup_q
#SBATCH -o gen_retro_icbc.%j.out
# =============================================================

# Output the settings for debugging
echo "Running with the following settings:"
echo "Tasks per node: ${SLURM_TASKS_PER_NODE}"
echo "Total tasks: ${ADVANCE_PROCS}"

echo "gen_retro_icbc.sh is running in $(pwd)"

# Set initial and final dates
datea="2017042700"
datefnl="2017042712"
paramfile="/gpfs/home/sa24m/Research/base/scripts/param.sh"

# Source parameter file
source "$paramfile"

# Link necessary files
mkdir -p "${ICBC_DIR}/metgrid"
ln -fs "${WPS_SRC_DIR}/metgrid/METGRID.TBL" "${ICBC_DIR}/metgrid/METGRID.TBL"

while true; do
   echo "Entering gen_retro_icbc.sh for $datea"

   # Create output directory if it doesn't exist
   mkdir -p "${OUTPUT_DIR}/${datea}"

   # Link and remove files as needed
   cd "${ICBC_DIR}" || exit
   ln -fs "${RUN_DIR}/input.nml" "input.nml"
   rm -f gfs*pgrb2* *grib2

   # Prepare to run WPS ungrib and metgrid
   start_date=$("${DART_DIR}/models/wrf/work/advance_time" "$datea" 0 -w)
   end_date=$("${DART_DIR}/models/wrf/work/advance_time" "$datea" 6 -w)
   echo "$start_date"

   # Set up namelist replacements
   cat > script.sed << EOF
/start_date/c\
 start_date = 2*'${start_date}',
/end_date/c\
 end_date   = 2*'${end_date}',
EOF

   if [[ $GRIB_SRC != "GFS" ]]; then 
      echo "gen_retro_icbc.sh: GRIB_SRC is set to $GRIB_SRC, expected 'GFS'. Adjust values if using another data source."
      exit 2
   fi

   # Link GRIB files and configure WPS files
   gribfile_a="${GRIB_DATA_DIR}/${datea}/gfs_ds084.1/gfs.0p25.${datea}.f000.grib2"
   gribfile_b="${GRIB_DATA_DIR}/${datea}/gfs_ds084.1/gfs.0p25.${datea}.f006.grib2"
   ln -fs "$gribfile_a" "GRIBFILE.AAA"
   ln -fs "$gribfile_b" "GRIBFILE.AAB"

   # Set up WPS namelist
   sed -f script.sed "${TEMPLATE_DIR}/namelist.wps.template" > namelist.wps
   ln -fs "${WPS_SRC_DIR}/ungrib/Variable_Tables/Vtable.${GRIB_SRC}" Vtable

   rm -f output.ungrib.exe.${GRIB_SRC}
   "${WPS_SRC_DIR}/ungrib.exe" >& output.ungrib.exe.${GRIB_SRC}

   rm -f output.metgrid.exe
   "${WPS_SRC_DIR}/metgrid.exe" >& output.metgrid.exe

   ln -fs "${WPS_SRC_DIR}/met_em.d01.*" .

   # Set forecast date and run real.exe twice
   datef=$("${DART_DIR}/models/wrf/work/advance_time" "$datea" "$ASSIM_INT_HOURS")
   gdatef=($("${DART_DIR}/models/wrf/work/advance_time" "$datef" 0 -g))
   hh="${datea:8:2}"

   for n in {1..2}; do
      echo "RUNNING REAL, STEP $n"
      if [[ $n -eq 1 ]]; then
         date1="$datea"
         date2="$datef"
         fcst_hours="$ASSIM_INT_HOURS"
      else
         date1="$datef"
         date2="$datef"
         fcst_hours=0
      fi

      yyyy1="${date1:0:4}"
      mm1="${date1:4:2}"
      dd1="${date1:6:2}"
      hh1="${date1:8:2}"
      yyyy2="${date2:0:4}"
      mm2="${date2:4:2}"
      dd2="${date2:6:2}"
      hh2="${date2:8:2}"

      rm -f namelist.input script.sed
      cat > script.sed << EOF
/run_hours/c\
run_hours                  = ${fcst_hours},
/start_year/c\
start_year                 = ${yyyy1}, ${yyyy1},
/end_year/c\
end_year                   = ${yyyy2}, ${yyyy2},
EOF

      sed -f script.sed "${TEMPLATE_DIR}/namelist.input.meso" > namelist.input

      # Submit Slurm job for real.exe
      sbatch real.sh
      sleep 15

      # Move output files to storage
      gdate=($("${DART_DIR}/models/wrf/work/advance_time" "$date1" 0 -g))
      mv wrfinput_d01 "${OUTPUT_DIR}/${datea}/wrfinput_d01_${gdate[0]}_${gdate[1]}_mean"
      [[ $n -eq 1 ]] && mv wrfbdy_d01 "${OUTPUT_DIR}/${datea}/wrfbdy_d01_${gdatef[0]}_${gdatef[1]}_mean"
   done

   # Move to next time, or exit if final time is reached
   if [[ $datea == $datefnl ]]; then
      echo "Reached the final date. Exiting."
      exit 0
   fi
   datea=$("${DART_DIR}/models/wrf/work/advance_time" "$datea" "$ASSIM_INT_HOURS")
   echo "starting next time: $datea"
done

exit 0

