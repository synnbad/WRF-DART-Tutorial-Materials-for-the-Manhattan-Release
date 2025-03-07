#!/bin/bash
#
#------------------------------------------------------------------
# Bash conversion of the original C-shell script
#------------------------------------------------------------------
#
# DART software - Copyright UCAR.
# This open source software is provided by UCAR, "as is", without
# charge, subject to all terms of use at:
# http://www.image.ucar.edu/DAReS/DART/DART_download
#
# Utility to save a set of perturbations generated from WRFDA CV3 option
#
# Provide the following:
#   namelist.input
#   wrfinput_d01
#   ensemble size
#   list of perturbed variables
#   wrfda executable and be.dat
#
#------------------------------------------------------------------

# ----------------------
# User-defined variables
# ----------------------
datea="2017042700"  # Must match wrfinput_d01 date
wrfda_dir="/gpfs/home/sa24m/scratch/WRFDA"   # set this appropriately #%%%#
work_dir="/gpfs/home/sa24m/scratch/base"       # set this appropriately #%%%#
save_dir="/gpfs/home/sa24m/scratch/base/boundary_perts"  # set this appropriately #%%%#
DART_DIR="/gpfs/home/sa24m/scratch/DART/DART"      # set this appropriately #%%%#
template_dir="/gpfs/home/sa24m/scratch/base/template"  # set this appropriately #%%%#

IC_PERT_SCALE="0.009"
IC_HORIZ_SCALE="0.8"
IC_VERT_SCALE="0.8"

num_ens=150          # Number of perturbations to generate
                     # Must be at least ensemble size
                     # Suggest 3-4x. Test with single first if needed.

wrfin_dir="${work_dir}/wrfin"
ASSIM_INT_HOURS="6"

# Load any needed modules
# module load nco   # or the appropriate command for your environment
module restore
conda activate ncar_env
# -----------------------------
# Make (and/or enter) work_dir
# -----------------------------
mkdir -p "${work_dir}"
cd "${work_dir}" || { echo "Cannot cd to ${work_dir}"; exit 1; }

# Copy template input.nml
cp "${template_dir}/input.nml.template" "input.nml"

# --------------------------------
# Use DART advance_time to get dates
# --------------------------------
# The original csh used this pattern:
#   echo "$datea 0h -g" | ${DART_DIR}/models/wrf/work/advance_time
# Below is the same in bash:
gdate="$(echo "${datea} 0h -g" | "${DART_DIR}/models/wrf/work/advance_time")"
gdatef="$(echo "${datea} ${ASSIM_INT_HOURS}h -g" | "${DART_DIR}/models/wrf/work/advance_time")"
wdate="$(echo "${datea} 0h -w" | "${DART_DIR}/models/wrf/work/advance_time")"

# Parse datea into components
yyyy="$(echo "${datea}" | cut -b1-4)"
mm="$(echo "${datea}" | cut -b5-6)"
dd="$(echo "${datea}" | cut -b7-8)"
hh="$(echo "${datea}" | cut -b9-10)"

# -------------------------------------------------------------------------
# Loop over number of perturbations (num_ens), generate run directories, etc.
# -------------------------------------------------------------------------
n=1
while [ "${n}" -le "${num_ens}" ]; do

    # Create member directory and copy over wrfda files
    mkdir -p "${work_dir}/mem_${n}"
    cd "${work_dir}/mem_${n}" || { echo "Cannot cd to ${work_dir}/mem_${n}"; exit 1; }
    cp "${wrfda_dir}"/* .

    # Link to wrfinput
    ln -sf "${wrfin_dir}/wrfinput_d01" "fg"

    # Prep the namelist for wrfvar
    seed_array2=$((n * 10))

    # Build an sed script on the fly to inject variables
    cat > script.sed << EOF
/run_hours/c\
 run_hours                  = 0,
/run_minutes/c\
 run_minutes                = 0,
/run_seconds/c\
 run_seconds                = 0,
/start_year/c\
 start_year                 = 1*${yyyy},
/start_month/c\
 start_month                = 1*${mm},
/start_day/c\
 start_day                  = 1*${dd},
/start_hour/c\
 start_hour                 = 1*${hh},
/start_minute/c\
 start_minute               = 1*00,
/start_second/c\
 start_second               = 1*00,
/end_year/c\
 end_year                   = 1*${yyyy},
/end_month/c\
 end_month                  = 1*${mm},
/end_day/c\
 end_day                    = 1*${dd},
/end_hour/c\
 end_hour                   = 1*${hh},
/end_minute/c\
 end_minute                 = 1*00,
/end_second/c\
 end_second                 = 1*00,
/analysis_date/c\
 analysis_date = '${wdate}.0000',
s/PERT_SCALING/${IC_PERT_SCALE}/
s/HORIZ_SCALE/${IC_HORIZ_SCALE}/
s/VERT_SCALE/${IC_VERT_SCALE}/
/seed_array1/c\
 seed_array1 = ${datea},
/seed_array2/c\
 seed_array2 = ${seed_array2} /
EOF

    sed -f script.sed "${template_dir}/namelist.input.3dvar" > namelist.input

    # Create a PBS submit script for this member in bash
    # Note: You can rename #PBS lines to #SBATCH or others if using SLURM, etc.
    cat > "gen_pert_${n}.sh" << EOF
#!/bin/bash
#=================================================================
#SBATCH --job-name=gen_pert_bank_mem${n}
#SBATCH --output=oe.out
#SBATCH --account=backfill      #%%%#
#SBATCH -t 00:05:00
#SBATCH --priority=regular
#SBATCH --partition=backfill               #%%%#
#SBATCH -n 10
#SBATCH --ntasks-per-node=2
#=================================================================

cd "${work_dir}/mem_${n}" || exit 1

# Run wrfvar
mpiexec_mpt dplace -s 1 ./da_wrfvar.exe &> output.wrfvar
mv wrfvar_output wrfinput_d01

# Extract only the fields that are updated by wrfvar
ncks -h -F -A -a -v U,V,T,QVAPOR,MU fg orig_data.nc
ncks -h -F -A -a -v U,V,T,QVAPOR,MU wrfinput_d01 pert_data.nc

# Make the difference file for this member
ncdiff pert_data.nc orig_data.nc pert_bank_mem_${n}.nc
mv pert_bank_mem_${n}.nc "${save_dir}/pert_bank_mem_${n}.nc"
EOF

    # Submit the job
    sbatch "gen_pert_${n}.sh"

    # Increment loop counter
    ((n++))
done

# Optionally, sleep or wait for jobs to complete and do any cleanup
exit 0
