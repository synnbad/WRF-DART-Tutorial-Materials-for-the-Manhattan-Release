#!/bin/bash
#
# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

#=====================================================================
echo "gen_retro_icbc.sh is running in $(pwd)"

########################################################################
#
#   gen_retro_icbc.sh - shell script that generates the
#                                     necessary wrfinput_d01 and
#                                     wrfbdy_d01 files for running
#                                     a real-time analysis system.
#
#     created May 2009, Ryan Torn, U. Albany
#
# This creates   output/${date}/wrfbdy_d01_{days}_{seconds}_mean
#                output/${date}/wrfinput_d01_{days}_{time_step1}_mean
#                output/${date}/wrfinput_d01_{days}_{time_step2}_mean
########################################################################
#SBATCH --job-name="gen_retro_icbc"
#SBATCH --ntasks=15
#SBATCH -A chipilskigroup_q
#SBATCH -t 00:10:00
#SBATCH --partition=chipilskigroup_q
#SBATCH --output=gen_retro_icbc.%j.log # Standard output and error log exclusive
#SBATCH --export=AL
#######################################################################


datea=2017042700
datefnl=2017042712 # set this appropriately #%%%#
paramfile="/gpfs/home/sa24m/scratch/base/scripts/param.sh"   # set this appropriately #%%%#


source "$paramfile"

# The geo_*.nc files should already be in the ${ICBC_DIR}/*/ directories.
# ${LINK} ${GEO_FILES_DIR}/geo_*.nc .

mkdir -p "${ICBC_DIR}/metgrid"
${LINK} "${WPS_SRC_DIR}/metgrid/METGRID.TBL" "${ICBC_DIR}/metgrid/METGRID.TBL"

while true; do
   echo "Entering gen_retro_icbc.sh for $datea"

   if [ ! -d "${OUTPUT_DIR}/${datea}" ]; then
      mkdir -p "${OUTPUT_DIR}/${datea}"
   fi

   cd "${ICBC_DIR}"
   ${LINK} "${RUN_DIR}/input.nml" input.nml
   # ${REMOVE} gfs*pgrb2* *grib2

  ${LINK} ${GEO_FILES_DIR}/geo_*.nc .

   #  prepare to run WPS ungrib and metgrid
   start_date=$(echo $datea 0 -w | ${DART_DIR}/models/wrf/work/advance_time)
   end_date=$(echo $datea 6 -w | ${DART_DIR}/models/wrf/work/advance_time)
   echo "start date = $start_date"
   echo ""
   echo "end_date  = $end_date"
   ${REMOVE} script.sed
   ${REMOVE} namelist.wps
   cat > script.sed << EOF
/start_date/c\
start_date = 2*'${start_date}',
/end_date/c\
end_date   = 2*'${end_date}',
/prefix/c\
prefix = 'FILE',
EOF


   sed -f script.sed "${TEMPLATE_DIR}/namelist.wps.template" > namelist.wps

   ${LINK} "${WPS_SRC_DIR}/ungrib/Variable_Tables/Vtable.${GRIB_SRC}" Vtable


   # I added prefix for ungrib because running with ECMWF data requires 
   # ungrib based on pressure levels, surface levels and SST
   # build grib file names - may need to change for other data sources.

   if [ "$GRIB_SRC" != 'GFS' ]; then
      echo "gen_retro_icbc.sh: GRIB_SRC is set to $GRIB_SRC"
      echo "gen_retro_icbc.sh: There are some assumptions about using 'GFS'."
      echo "If you want to use something else, you will need to change the"
      echo "values of gribfile_a, gribfile_b"
      #exit 2
   fi

   # gribfile_a=${GRIB_DATA_DIR}/${datea}/gfs_ds084.1/gfs.0p25.${datea}.f000.grib2
   # gribfile_a=${BASE_DIR}/gfs.0p25.${datea}.f000.grib2
   # gribfile_b=/gpfs/home/sa24m/scratch/DATA/ERA_5_input/level_dart_new_api.grib
   gribfile_a=/gpfs/home/sa24m/scratch/DATA/ERA_5_input/*_dart_new_api.grib
   # gribfile_b=${GRIB_DATA_DIR}/${datea}/gfs_ds084.1/gfs.0p25.${datea}.f006.grib2
   # gribfile_b=/gpfs/home/sa24m/Research/base/gfs.0p25.2017042700.f006.grib2
   # gribfile_a=/gpfs/home/sa24m/Research/base/gfs.0p25.2017042700.f000.grib2
   # gribfile_a=/gpfs/home/sa24m/Research/DATA/ERA_5_input/*dart*s.g*

   #gribfile_a=/gpfs/home/sa24m/Research/DATA/dart_tut_grib/gdas1.fnl0p25.2017042700.f00.grib2
   #gribfile_b=/gpfs/home/sa24m/Research/DATA/dart_tut_grib/gdas1.fnl0p25.2017042706.f00.grib2

   # gribfile_b=${GRIB_DATA_DIR}/${datea}/gfs_ds084.1/gfs.0p25.${datea}.f006.grib2
   # ${LINK} "$gribfile_a" GRIBFILE.AAA
   # ${LINK} "$gribfile_b" GRIBFILE.AAB
   cp ${WPS_SRC_DIR}/link_grib.csh ${ICBC_DIR}/
   ./link_grib.csh "$gribfile_a"

   ${REMOVE} output.ungrib.exe.${GRIB_SRC}
   "${WPS_SRC_DIR}/ungrib.exe" &> output.ungrib.exe.${GRIB_SRC}
   # echo "ungrib for PL done"

   ${REMOVE} output.metgrid.exe
   "${WPS_SRC_DIR}/metgrid.exe" &> output.metgrid.exe

   ${COPY} ${WPS_SRC_DIR}/met_em.d01.* .

   datef=$(echo "$datea $ASSIM_INT_HOURS" | "${DART_DIR}/models/wrf/work/advance_time")
   gdatef=( $(echo "$datef 0 -g" | "${DART_DIR}/models/wrf/work/advance_time") )
   hh=$(echo "$datea" | cut -b9-10)

   #  Run real.exe twice, once to get first time wrfinput_d0? and wrfbdy_d01,
   #  then again to get second time wrfinput_d0? file
   n=1
   while [ $n -le 2 ]; do

      echo "RUNNING REAL, STEP $n"
      echo " "

      if [ $n -eq 1 ]; then
         date1=$datea
         date2=$datef
         fcst_hours=$ASSIM_INT_HOURS
      else
         date1=$datef
         date2=$datef
         fcst_hours=0
      fi

      yyyy1=$(echo "$date1" | cut -c 1-4)
      mm1=$(echo "$date1" | cut -c 5-6)
      dd1=$(echo "$date1" | cut -c 7-8)
      hh1=$(echo "$date1" | cut -c 9-10)
      yyyy2=$(echo "$date2" | cut -c 1-4)
      mm2=$(echo "$date2" | cut -c 5-6)
      dd2=$(echo "$date2" | cut -c 7-8)
      hh2=$(echo "$date2" | cut -c 9-10)

      ${REMOVE} namelist.input script.sed
      cat > script.sed << EOF
  /run_hours/c\
  run_hours                  = ${fcst_hours},
  /run_minutes/c\
  run_minutes                = 0,
  /run_seconds/c\
  run_seconds                = 0,
  /start_year/c\
  start_year                 = ${yyyy1}, ${yyyy1},
  /start_month/c\
  start_month                = ${mm1}, ${mm1},
  /start_day/c\
  start_day                  = ${dd1}, ${dd1},
  /start_hour/c\
  start_hour                 = ${hh1}, ${hh1},
  /start_minute/c\
  start_minute               = 00, 00,
  /start_second/c\
  start_second               = 00, 00,
  /end_year/c\
  end_year                   = ${yyyy2}, ${yyyy2},
  /end_month/c\
  end_month                  = ${mm2}, ${mm2},
  /end_day/c\
  end_day                    = ${dd2}, ${dd2},
  /end_hour/c\
  end_hour                   = ${hh2}, ${hh2},
  /end_minute/c\
  end_minute                 = 00, 00,
  /end_second/c\
  end_second                 = 00, 00,
EOF


      sed -f script.sed "${TEMPLATE_DIR}/namelist.input.meso">namelist.input
      rm -f script.sed real_done rsl.*
      echo "2i">script.sed
      echo "#======================================" >> script.sed
      echo "#SBATCH --job-name=run_real" >> script.sed
      echo "#SBATCH -A ${COMPUTER_CHARGE_ACCOUNT}" >> script.sed
      echo "#SBATCH --time=00:10:00" >> script.sed
      echo "#SBATCH --partition=${ADVANCE_QUEUE}" >> script.sed
      echo "#SBATCH --qos=${ADVANCE_PRIORITY}" >> script.sed
      echo "#SBATCH --output=run_real.out" >> script.sed
      echo "#SBATCH --error=run_real.err" >> script.sed
      echo "#SBATCH --ntasks=${ADVANCE_PROCS}" >> script.sed
      echo "#SBATCH --export=ALL" >> script.sed
      echo "#======================================"  >> script.sed
      echo "" >> script.sed
      echo "" >> script.sed
      echo 's%${1}%'"${paramfile}%g"                   >> script.sed
      sed -f script.sed "${SHELL_SCRIPTS_DIR}/real.sh">real.sh.save
      mv real.sh.save real.sh
      sbatch real.sh

      # need to look for something to know when this job is done
      while [ ! -e "${ICBC_DIR}/real_done" ]; do
          sleep 15
      done
      cat rsl.out.0000>>out.real.exe
      rm rsl.*

      #  move output files to storage
      gdate=($(echo "$date1 0 -g" | "${DART_DIR}/models/wrf/work/advance_time"))
      ${MOVE} wrfinput_d01 "${OUTPUT_DIR}/${datea}/wrfinput_d01_${gdate[0]}_${gdate[1]}_mean"
      if [ $n -eq 1 ]; then
         ${MOVE} wrfbdy_d01 "${OUTPUT_DIR}/${datea}/wrfbdy_d01_${gdatef[0]}_${gdatef[1]}_mean"
         cp namelist.input "${OUTPUT_DIR}/${datea}/"
      fi

      n=$((n + 1))

   done

   # move to next time, or exit if final time is reached
   if [ "$datea" == "$datefnl" ]; then
      echo "Reached the final date "
      echo "Script exiting normally"
      exit 0
   fi
   datea=$(echo "$datea $ASSIM_INT_HOURS" | "${DART_DIR}/models/wrf/work/advance_time")
   echo "starting next time: $datea"
done

exit 0

