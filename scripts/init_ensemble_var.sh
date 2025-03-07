#!/bin/bash

initial_date=$1
paramfile=$(readlink -f "$2") # Get absolute path for param.csh from command line arg
echo $paramfile
source "$paramfile"

cd "${RUN_DIR}"

# Generate the i/o lists in rundir automatically when initializing the ensemble
num_ens=${NUM_ENS}
input_file_name="input_list_d01.txt"
input_file_path="./advance_temp"
output_file_name="output_list_d01.txt"

n=1

[ -e "$input_file_name" ] && rm "$input_file_name"
[ -e "$output_file_name" ] && rm "$output_file_name"

while [ "$n" -le "$num_ens" ]; do
    ensstring=$(printf "%04d" "$n")

    in_file_name="${input_file_path}${n}/wrfinput_d01"
    out_file_name="filter_restart_d01.${ensstring}"


    echo "$in_file_name" >> "$input_file_name"
    echo "$out_file_name" >> "$output_file_name"

    n=$((n + 1))
done

###

gdate=($(echo $initial_date 0h -g | ${DART_DIR}/models/wrf/work/advance_time))
gdatef=($(echo $initial_date ${ASSIM_INT_HOURS}h -g | ${DART_DIR}/models/wrf/work/advance_time))


wdate=$(echo "$initial_date" | "${DART_DIR}/models/wrf/work/advance_time")

yyyy=$(echo "$initial_date" | cut -b1-4)

mm=$(echo "$initial_date" | cut -b5-6)
dd=$(echo "$initial_date" | cut -b7-8)
hh=$(echo "$initial_date" | cut -b9-10)

${COPY} "${TEMPLATE_DIR}/namelist.input.meso" namelist.input
${REMOVE} "${RUN_DIR}/WRF"
${LINK} "${OUTPUT_DIR}/${initial_date}" WRF

n=1
while [ "$n" -le "$NUM_ENS" ]; do
    echo "  QUEUEING ENSEMBLE MEMBER $n at $(date)"

    mkdir -p "${RUN_DIR}/advance_temp${n}"

    ${LINK} "${RUN_DIR}/WRF_RUN/"* "${RUN_DIR}/advance_temp${n}/."
    ${LINK} "${RUN_DIR}/input.nml" "${RUN_DIR}/advance_temp${n}/input.nml"

    ${COPY} "${OUTPUT_DIR}/${initial_date}/wrfinput_d01_${gdate[0]}_${gdate[1]}_mean" \
              "${RUN_DIR}/advance_temp${n}/wrfvar_output.nc"
    sleep 3
    ${COPY} "${RUN_DIR}/add_bank_perts.ncl" "${RUN_DIR}/advance_temp${n}/."

    cmd3="ncl 'MEM_NUM=${n}' 'PERTS_DIR=\"${PERTS_DIR}\"' ${RUN_DIR}/advance_temp${n}/add_bank_perts.ncl"
    ${REMOVE} "${RUN_DIR}/advance_temp${n}/nclrun3.out"
    cat > "${RUN_DIR}/advance_temp${n}/nclrun3.out" << EOF
$cmd3
EOF
    echo "$cmd3" > "${RUN_DIR}/advance_temp${n}/nclrun3.out.tim"

    cat > "${RUN_DIR}/rt_assim_init_${n}.sh" << EOF
#!/bin/bash
#=================================================================
#SBATCH --job-name=first_advance_${n}
#SBATCH --output=first_advance_${n}.out
#SBATCH --error=first_advance_${n}.err
#SBATCH --account=backfill
#SBATCH -t 01:00:00
#SBATCH --partition=backfill
#SBATCH --priority=${ADVANCE_PRIORITY}
#SBATCH -n 50
#SBATCH --mem-per-cpu=8000M
#=================================================================

echo "rt_assim_init_${n}.sh is running in $(pwd)"

cd "${RUN_DIR}/advance_temp${n}"

if [ -e wrfvar_output.nc ]; then
    echo "Running nclrun3.out to create wrfinput_d01 for member $n at $(date)"

    chmod +x nclrun3.out
    ./nclrun3.out >& add_perts.out

    if [ ! -s add_perts.err ]; then
        echo "Perts added to member ${n}"
    else
        echo "ERROR! Non-zero status returned from add_bank_perts.ncl. Check ${RUN_DIR}/advance_temp${n}/add_perts.err."
        cat add_perts.err
        exit 1
    fi

    ${MOVE} wrfvar_output.nc wrfinput_d01
    echo "wrfvar_output moved as  wrfinput_d01"
fi

cd ${RUN_DIR}


echo "Running first_advance.sh for member $n at $(date)"
"${SHELL_SCRIPTS_DIR}/first_advance.sh" $initial_date $n $paramfile

EOF

    sbatch "${RUN_DIR}/rt_assim_init_${n}.sh"

    n=$((n + 1))
done
echo "init done"
exit 0

