#!/bin/bash

# Sample script to run dart_wrf

# Create working directories and directories to store files
# store megrid files
mkdir "working_directory"   # create a working directory
BASE_DIR="working_directory"
RUN_DIR="${BASE_DIR}/rundir"
ICBC_DIR="${BASE_DIR}/icbc"
PERTS_DIR="${BASE_DIR}/perts"
OUTPUT_DIR="${BASE_DIR}/output"

#  Assign path to DART, WRF, WPS and WRFDA build
SHELL_SCRIPTS_DIR="${BASE_DIR}/scripts"
DART_DIR="dart directory"                    # set this appropriately #%%%#
WRF_DM_SRC_DIR="WRF_Directory"                    # set this appropriately #%%%#
WPS_SRC_DIR="WPS Directory"                      # set this appropriately #%%%#
VAR_SRC_DIR="WRFDA Directory"                   # set this appropriately #%%%#

# for generating wrf template files
GEO_FILES_DIR="Path to geofiles"            # set this appropriately #%%%#
GRIB_DATA_DIR="${ICBC_DIR}/grib_data"                     # set this appropriately #%%%#

# list of variables for extraction and cycling
extract_vars_a=(U V PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC TSLB SMOIS TSK RAINC RAINNC GRAUPELNC)
# RAINC RAINNC GRAUPELNC
extract_vars_b=(U V W PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC TSLB SMOIS TSK RAINC RAINNC GRAUPELNC REFL_10CM VT_DBZ_WT)
cycle_vars_a=( U V PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC TSLB SMOIS TSK)
increment_vars_a=( U V PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC)


NUM_ENS=50
ASSIM_INT_MINUTES=0   # 0 means use ASSIM_INT_HOURS
ASSIM_INT_HOURS=6   # ignored if ASSIM_INT_MINUTES > 0
IC_PERT_SCALE=0.25
ADAPTIVE_INFLATION=1   # set to 1 if using adaptive inflation to tell the scripts to look for the files
NUM_DOMAINS=1

#  System specific commands
export REMOVE="rm -rf"
export COPY="cp -pfr"
export MOVE="mv -f"
export LINK="ln -fs"
export WGET="/usr/bin/wget"
export LIST="ls"


# set initial and final date
datea=2017042700
datefnl=2017042712

# =================================================
# Step 1. Generate initial Conditions
# First, generate a set of GFS states and boundary conditions that will be used in the cycling.
# Extract the grib data, run metgrid, and then twice execute real.exe to generate a pair of 
# WRF files and a boundary file for each analysis time.
# ================================================
# Run WPS and WRF in ICBC Directory
cd "{ICBC_DIR}"
ln -sf ${GEO_FILES_DIR}/geo_*.nc .
ln -sf "${WPS_SRC_DIR}/metgrid/METGRID.TBL" "${ICBC_DIR}/metgrid/METGRID.TBL"
ln -sf "${RUN_DIR}/input.nml" input.nml


while true; do

   if [ ! -d "${OUTPUT_DIR}/${datea}" ]; then
      mkdir -p "${OUTPUT_DIR}/${datea}"
   fi

   #  prepare to run WPS ungrib and metgrid
   start_date=$(echo $datea 0 -w | ${DART_DIR}/models/wrf/work/advance_time)
   end_date=$(echo $datea 6 -w | ${DART_DIR}/models/wrf/work/advance_time)
   

