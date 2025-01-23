#!/bin/bash
#
# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

# TJH   ADAPTIVE_INFLATION is disconnected from input.nml
# TJH   ASSIM_INT_HOURS  is implicit in (ALL) the scripts except assim_advance.csh
#                        ASSIM_INT_MINUTES support needs to be added to param.csh,
#                        it is referenced in assim_advance.csh but not declared in param.csh
# Edited by Stephen Asare Florida State University
# Set up environment. Current settings are for NCAR's Derecho
# module load nco          # set this appropriately #%%%#
# module load ncl/6.6.2    # set this appropriately #%%%#

source /gpfs/research/software/python/anaconda38/etc/profile.d/conda.sh
echo "Activating conda environment"
#conda init bash
conda activate ncar_env
# conda info --env

module restore

#  Set the assimilation parameters
NUM_ENS=50
ASSIM_INT_MINUTES=0   # 0 means use ASSIM_INT_HOURS
ASSIM_INT_HOURS=6   # ignored if ASSIM_INT_MINUTES > 0
IC_PERT_SCALE=0.25
ADAPTIVE_INFLATION=1   # set to 1 if using adaptive inflation to tell the scripts to look for the files
NUM_DOMAINS=1

#  Directories where things are run
#  IMPORTANT : Scripts provided rely on this directory structure and names relative to BASE_DIR.
#              Do not change, otherwise tutorial will fail.    
BASE_DIR="/gpfs/home/sa24m/Research/base"     # set this appropriately #%%%#
RUN_DIR="${BASE_DIR}/rundir"
TEMPLATE_DIR="${BASE_DIR}/template"
OBSPROC_DIR="${BASE_DIR}/obsproc"
OUTPUT_DIR="${BASE_DIR}/output"
ICBC_DIR="${BASE_DIR}/icbc"
POST_STAGE_DIR="${BASE_DIR}/post"
OBS_DIAG_DIR="${BASE_DIR}/obs_diag"
PERTS_DIR="${BASE_DIR}/perts"

#  Assign path to DART, WRF, WPS and WRFDA build
SHELL_SCRIPTS_DIR="${BASE_DIR}/scripts"
DART_DIR="/gpfs/home/sa24m/Research/DART"                    # set this appropriately #%%%#
WRF_DM_SRC_DIR="/gpfs/home/sa24m/Research/WRFV4.5.2"                    # set this appropriately #%%%#
WPS_SRC_DIR="/gpfs/home/sa24m/Research/WPSV4.5"                      # set this appropriately #%%%#
VAR_SRC_DIR="/gpfs/home/sa24m/Research/WRFDA"                   # set this appropriately #%%%#

# for generating wrf template files
GEO_FILES_DIR="/gpfs/home/sa24m/Research/WPSV4.5"            # set this appropriately #%%%#
GRIB_DATA_DIR="${ICBC_DIR}/grib_data"                     # set this appropriately #%%%#
GRIB_SRC='GFS'                                     # set this appropriately #%%%#

# list of variables for extraction and cycling
extract_vars_a=(U V PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC TSLB SMOIS TSK RAINC RAINNC GRAUPELNC)
extract_vars_b=(U V W PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC TSLB SMOIS TSK RAINC RAINNC GRAUPELNC REFL_10CM VT_DBZ_WT)
cycle_vars_a=( U V PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC TSLB SMOIS TSK)
increment_vars_a=( U V PH THM MU QVAPOR QCLOUD QRAIN QICE QSNOW QGRAUP QNICE QNRAIN U10 V10 T2 Q2 PSFC)

#  Diagnostic parameters
OBS_VERIF_DAYS=7

#  Generic queuing system parameters
SUPER_PLATFORM='slurm'
COMPUTER_CHARGE_ACCOUNT=chipilskigroup_q                  # set this appropriately #%%%#
EMAIL=sasare@fsu.edu                 # set this appropriately #%%%#

if [[ $SUPER_PLATFORM == "derecho" ]]; then
   # Derecho values (uses 'PBS' queueing system) 
   # Set these appropriately for your PBS system  #%%%#  
   FILTER_QUEUE="main"
   FILTER_PRIORITY="premium"
   FILTER_TIME=0:35:00
   FILTER_NODES=2
   FILTER_PROCS=96
   FILTER_MPI=96

   ADVANCE_QUEUE="main"
   ADVANCE_PRIORITY="premium"
   ADVANCE_TIME=0:20:00
   ADVANCE_NODES=1
   ADVANCE_PROCS=96
   ADVANCE_MPI=96
else
   # 'LSF' queueing system example
   # Set these appropriately for your LSF or Slurm system #%%%# 
   FILTER_QUEUE=chipilskigroup_q 
   FILTER_TIME=00:25:00
   ADVANCE_QUEUE=chipilskigroup_q 
   ADVANCE_TIME=00:18:00
   ADVANCE_PRIORITY=normal
   FILTER_NODES=2
   FILTER_PROCS=20
   ADVANCE_NODES=4
   ADVANCE_PROCS=48
   SLURM_TASKS_PER_NODE=12
fi

#  System specific commands
export REMOVE="rm -rf"
export COPY="cp -pfr"
export MOVE="mv -f"
export LINK="ln -fs"
export WGET="/usr/bin/wget"
export LIST="ls"


echo "param.sh done"


# exit 0

