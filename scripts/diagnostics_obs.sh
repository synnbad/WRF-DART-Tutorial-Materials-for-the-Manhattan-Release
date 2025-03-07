#!/bin/bash

# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

# diagnostics_obs.sh - shell script that computes observation
#                      specific diagnostics.
#
# $1 - analysis date
# $2 - parameter file
#
# Created Aug. 2009 Ryan Torn, U. Albany

# Set date and parameter file
datea="$1"
paramfile="$2"
source "$paramfile"

cd "$OBS_DIAG_DIR"
cp -prf "${RUN_DIR}/input.nml" input.nml
gdate=($(echo $datea 0h -g | ${DART_DIR}/models/wrf/work/advance_time))
yyyy2=$(echo "$datea" | cut -c1-4)
mm2=$(echo "$datea" | cut -c5-6)
dd2=$(echo "$datea" | cut -c7-8)
hh2=$(echo "$datea" | cut -c9-10)

# Determine appropriate dates for observation diagnostics
nhours=$((OBS_VERIF_DAYS * 24))
datef=( $(echo "$datea -${nhours}" | ${DART_DIR}/models/wrf/work/advance_time) )

yyyy1=$(echo "$datef" | cut -c1-4)
mm1=$(echo "$datef" | cut -c5-6)
dd1=$(echo "$datef" | cut -c7-8)
hh1=$(echo "$datef" | cut -c9-10)

half_bin=$((ASSIM_INT_HOURS / 2))
datefbs=( $(echo $datef -${half_bin}h | ${DART_DIR}/models/wrf/work/advance_time) )
fbs_yyyy1=$(echo "$datefbs" | cut -c1-4)
fbs_mm1=$(echo "$datefbs" | cut -c5-6)
fbs_dd1=$(echo "$datefbs" | cut -c7-8)
fbs_hh1=$(echo "$datefbs" | cut -c9-10)

datefbe=( $(echo $datef ${half_bin}h | ${DART_DIR}/models/wrf/work/advance_time) )
fbe_yyyy1=$(echo "$datefbe" | cut -c1-4)
fbe_mm1=$(echo "$datefbe" | cut -c5-6)
fbe_dd1=$(echo "$datefbe" | cut -c7-8)
fbe_hh1=$(echo "$datefbe" | cut -c9-10)

datelbe=( $(echo $datea ${half_bin}h | ${DART_DIR}/models/wrf/work/advance_time) )
lbe_yyyy1=$(echo "$datelbe" | cut -c1-4)
lbe_mm1=$(echo "$datelbe" | cut -c5-6)
lbe_dd1=$(echo "$datelbe" | cut -c7-8)
lbe_hh1=$(echo "$datelbe" | cut -c9-10)

while [[ "$datef" -le "$datea" ]]; do
    if [[ -e "${OUTPUT_DIR}/${datef}/obs_seq.final" ]]; then
        ln -sf "${OUTPUT_DIR}/${datef}/obs_seq.final" "obs_seq.final_${datef}"
    fi
    datef=$(echo "$datef $ASSIM_INT_HOURS" | "${DART_DIR}/models/wrf/work/advance_time")
    # datef=( $(echo $datef ${ASSIM_INT_HOURS}h | ${DART_DIR}/models/wrf/work/advance_time) )
done

readlink -f obs_seq.final_* > flist

cat > script.sed << EOF
/obs_sequence_name/c\
obs_sequence_name = '',
/obs_sequence_list/c\
obs_sequence_list = 'flist',
/first_bin_center/c\
first_bin_center =  ${yyyy1}, ${mm1}, ${dd1}, ${hh1}, 0, 0,
/last_bin_center/c\
last_bin_center  =  ${yyyy2}, ${mm2}, ${dd2}, ${hh2}, 0, 0,
/filename_seq /c\
filename_seq = 'obs_seq.final',
/filename_seq_list/c\
filename_seq_list = '',
/filename_out/c\
filename_out = 'obs_seq.final_reduced',
/first_obs_days/c\
first_obs_days = -1,
/first_obs_seconds/c\
first_obs_seconds = -1,
/last_obs_days/c\
last_obs_days = -1,
/last_obs_seconds/c\
last_obs_seconds = -1,
/edit_copies/c\
edit_copies        = .true.,
/new_copy_index/c\
new_copy_index     = 1, 2, 3, 4, 5,
/first_bin_start/c\
first_bin_start    = ${fbs_yyyy1}, ${fbs_mm1}, ${fbs_dd1}, ${fbs_hh1}, 0, 0,
/first_bin_end/c\
first_bin_end      = ${fbe_yyyy1}, ${fbe_mm1}, ${fbe_dd1}, ${fbe_hh1}, 0, 0,
/last_bin_end/c\
last_bin_end       = ${lbe_yyyy1}, ${lbe_mm1}, ${lbe_dd1}, ${lbe_hh1}, 0, 0,
EOF

sed -f script.sed "${RUN_DIR}/input.nml" > input.nml

# Create the state-space diagnostic summary
"${DART_DIR}/models/wrf/work/obs_diag" || exit 1
mv obs_diag_output.nc "${OUTPUT_DIR}/${datea}/."
mv "$(ls -1 observation_locations.*.dat | tail -1)" "${OUTPUT_DIR}/${datea}/observation_locations.dat"

# Create a netCDF file with the original observation data
"${DART_DIR}/models/wrf/work/obs_seq_to_netcdf"
mv obs_epoch* "${OUTPUT_DIR}/${datea}/"
"$REMOVE" *.txt obs_seq.final_* flist observation_locations.*.dat

# Prune the obs_seq.final and store result
ln -sf "${OUTPUT_DIR}/${datea}/obs_seq.final" .
"${DART_DIR}/models/wrf/work/obs_sequence_tool"
mv obs_seq.final_reduced "${OUTPUT_DIR}/${datea}/."
"$REMOVE" obs_seq.final

# Process the mean analysis increment
cd "${OUTPUT_DIR}/${datea}"
cp -pr "${SHELL_SCRIPTS_DIR}/mean_increment.ncl" .
echo "ncl ${OUTPUT_DIR}/${datea}/mean_increment.ncl" > nclrun.out
chmod +x nclrun.out
./nclrun.out

touch "${OUTPUT_DIR}/${datea}/obs_diags_done"

exit 0
