#!/bin/bash
# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

#   driver.csh - script that is the driver for the
#                            CONUS analysis system
#                            MODIFIED for new DART direct
#                            file access
#
#      provide an input argument of the first
#      analysis time in yyyymmddhh format.
#
#   Created May 2009, Ryan Torn, U. Albany
#   Modified by G. Romine to run realtime cases 2011-18
#    Modified by Stephen Asare to convert from csh to sh
#
########################################################################
#   run as: nohup csh driver.sh 2017042706 param.sh >& run.log &
########################################################################
# Set the correct values here
paramfile=$(readlink -f "$2") # Get absolute path for param.csh from command line arg
datefnl=2017042712 # Target date YYYYMMDDHH  # Set this appropriately #%%%#
########################################################################
# Likely do not need to change anything below
########################################################################


source "$paramfile"

echo "$(uname -a)"
cd "${RUN_DIR}"

# First determine the appropriate analysis date

if [ $# -gt 0 ]; then
    datea="${1}" # Starting date
    export restore=1   # Set the restore variable
    echo 'Starting a restore'
else
    echo "Please enter a date: yyyymmddhh"
    exit
fi

touch "${RUN_DIR}/cycle_started_${datea}"

while true; do

    if [ ! -d "${OUTPUT_DIR}/${datea}" ] && [ "$restore" = "1" ]; then
        ${REMOVE} "${RUN_DIR}/ABORT_RETRO"
        echo 'Exiting because output directory does not exist and this is a restore'
        exit
    fi

    datep=$(${DART_DIR}/models/wrf/work/advance_time "$datea" -${ASSIM_INT_HOURS})
    gdate=($(${DART_DIR}/models/wrf/work/advance_time "$datea" 0 -g))
    gdatef=($(${DART_DIR}/models/wrf/work/advance_time "$datea" "${ASSIM_INT_HOURS}" -g))
    wdate=$(${DART_DIR}/models/wrf/work/advance_time "$datea" 0 -w)
    hh=$(echo "$datea" | cut -b9-10)

    echo 'Ready to check inputs'
    domains="$NUM_DOMAINS"   # From the param file

    # Check to make sure all input data exists
    if [ "$domains" = "1" ]; then
        for infile in \
            "wrfinput_d01_${gdate[0]}_${gdate[1]}_mean" \
            "wrfinput_d01_${gdatef[0]}_${gdatef[1]}_mean" \
            "wrfbdy_d01_${gdatef[0]}_${gdatef[1]}_mean" \
            "obs_seq.out"; do

            if [ ! -e "${OUTPUT_DIR}/${datea}/${infile}" ]; then
                echo  "${OUTPUT_DIR}/${datea}/${infile} is missing! Stopping the system"
                touch ABORT_RETRO
                exit 2
            fi
        done
    fi

    # Clear the advance_temp directory, write in new template file, and
    # overwrite variables with the compact prior netcdf files
    #
    # NOTE that multiple domains might be present, but only looking for domain 1

    if [ "$SUPER_PLATFORM" = 'LSF queuing system' ]; then
        ic_queue="caldera"
        logfile="${RUN_DIR}/ic_gen.log"
        sub_command="bsub -q ${ic_queue} -W 00:05 -o ${logfile} -n 1 -P ${COMPUTER_CHARGE_ACCOUNT}"
    elif [ "$SUPER_PLATFORM" = 'derecho' ]; then
        ic_queue="main"
        sub_command="qsub -l select=1:ncpus=128:mpiprocs=128:mem=5GB -l walltime=00:03:00 -q ${ic_queue} -A ${COMPUTER_CHARGE_ACCOUNT} -j oe -k eod -N icgen"
    fi

    echo "This platform is $SUPER_PLATFORM and the job submission command is $sub_command"

    dn=1
    while [ "$dn" -le "$domains" ]; do
        dchar=$(printf "%02d" "$dn")
        n=1
        while [ "$n" -le "$NUM_ENS" ]; do
            ensstring=$(printf "%04d" "$n")
            if [ -e "${OUTPUT_DIR}/${datep}/PRIORS/prior_d${dchar}.${ensstring}" ]; then

                if [ "$dn" = "1" ] && [ -d "${RUN_DIR}/advance_temp${n}" ]; then
                    ${REMOVE} "${RUN_DIR}/advance_temp${n}"
                fi

                mkdir -p "${RUN_DIR}/advance_temp${n}"
                ${LINK} "${OUTPUT_DIR}/${datea}/wrfinput_d${dchar}_${gdate[0]}_${gdate[1]}_mean" \
                         "${RUN_DIR}/advance_temp${n}/wrfinput_d${dchar}"
            else
                echo "${OUTPUT_DIR}/${datep}/PRIORS/prior_d${dchar}.${ensstring} is missing! Stopping the system"
                touch ABORT_RETRO
                exit 3
            fi
            n=$((n + 1))
        done  # Loop through ensemble members
        dn=$((dn + 1))
    done   # Loop through domains

    # Fire off a bunch of small jobs to create the initial conditions for the short model forecast.
    # The prep_ic.sh script creates a file "${RUN_DIR}/ic_d${dchar}_${n}_ready" to signal a
    # successful completion.
    # NOTE: Submit commands here are system specific and work for this tutorial, users may want/need to change
    #       for their system and/or production.

    n=1
    while [ "$n" -le "$NUM_ENS" ]; do
        if [ "$SUPER_PLATFORM" = 'derecho' ]; then   # Can't pass along arguments in the same way
            $sub_command -v mem_num=${n},date=${datep},domain=${domains},paramf=${paramfile} "${SHELL_SCRIPTS_DIR}/prep_ic.sh"
        else
            $sub_command "${SHELL_SCRIPTS_DIR}/prep_ic.sh ${n} ${datep} ${dn} ${paramfile}"
        fi
        n=$((n + 1))
    done  # Loop through ensemble members

    # If any of the queued jobs has not completed in 5 minutes, run them manually
    # Cleanup any failed stuffs
    # NOTE: No automated cleanup for queued jobs. User may want to add system-specific monitoring.
    dn=1
    while [ "$dn" -le "$domains" ]; do
        dchar=$(printf "%02d" "$dn")
        n=1
        loop=1
        while [ "$n" -le "$NUM_ENS" ]; do
            if [ -e "${RUN_DIR}/ic_d${dchar}_${n}_ready" ]; then
                ${REMOVE} "${RUN_DIR}/ic_d${dchar}_${n}_ready"
                n=$((n + 1))
                loop=1
            else
                echo "Waiting for ic member $n in domain $dn"
                sleep 5
                loop=$((loop + 1))
                if [ "$loop" -gt 60 ]; then    # Wait 5 minutes for the ic file to be ready, else run manually
                    echo "Gave up on ic member $n - redo"
                    "${SHELL_SCRIPTS_DIR}/prep_ic.sh" "${n}" "${datep}" "${dn}" "${paramfile}"
                    # If manual execution of script, shouldn't queued job be killed?
                fi
            fi
        done
        dn=$((dn + 1))
    done   # Loop through domains

    mkdir -p "${OUTPUT_DIR}/${datea}/logs"
    ${MOVE} icgen.o* "${OUTPUT_DIR}/${datea}/logs/"

    # Get wrfinput source information
    ${COPY} "${OUTPUT_DIR}/${datea}/wrfinput_d01_${gdate[0]}_${gdate[1]}_mean" wrfinput_d01
    dn=1
    while [ "$dn" -le "$domains" ]; do

        dchar=$(printf "%02d" "$dn")
        ${COPY} "${OUTPUT_DIR}/${datea}/wrfinput_d${dchar}_${gdate[0]}_${gdate[1]}_mean" "wrfinput_d${dchar}"
        dn=$((dn + 1))

    done

    # Copy the inflation files from the previous time, update for domains
    # TJH ADAPTIVE_INFLATION comes from scripts/param.csh but is disjoint from input.nml

    if [ "$ADAPTIVE_INFLATION" = "1" ]; then
        # Create the home for inflation and future state space diagnostic files
        # Should try to check each file here, but shortcutting for prior (most common) and link them all

        mkdir -p "${RUN_DIR}"/{Inflation_input,Output}

        if [ -e "${OUTPUT_DIR}/${datep}/Inflation_input/input_priorinf_mean.nc" ]; then

            ${LINK} "${OUTPUT_DIR}/${datep}/Inflation_input/input_priorinf"*.nc "${RUN_DIR}/."
            ${LINK} "${OUTPUT_DIR}/${datep}/Inflation_input/input_postinf"*.nc "${RUN_DIR}/."

        else

            echo "${OUTPUT_DIR}/${datep}/Inflation_input/input_priorinf_mean.nc file does not exist. Stopping"
            touch ABORT_RETRO
            exit 3

        fi
    fi   # ADAPTIVE_INFLATION file check

    ${LINK} "${OUTPUT_DIR}/${datea}/obs_seq.out" .
    ${REMOVE} "${RUN_DIR}/WRF"
    ${REMOVE} "${RUN_DIR}/prev_cycle_done"
    ${LINK} "${OUTPUT_DIR}/${datea}" "${RUN_DIR}/WRF"

    # Run filter to generate the analysis
    ${REMOVE} script.sed
    if [ "$SUPER_PLATFORM" = 'slurm' ]; then

        # This is a most unusual application of 'sed' to insert the batch submission
        # directives into a file.

        cat > script.sed << EOF
2i\\
#==================================================================\\
#SBATCH --job-name=assimilate_${datea}\\
#SBATCH --output=assimilate_${datea}.%j.log\\
#SBATCH --account=${COMPUTER_CHARGE_ACCOUNT}\\
#SBATCH --time=${FILTER_TIME}\\
#SBATCH --partition=${FILTER_QUEUE}\\
#SBATCH --exclusive\\
#==================================================================
s%\${1}%${datea}%g
s%\${2}%${paramfile}%g
EOF

        sed -f script.sed "${SHELL_SCRIPTS_DIR}/assimilate.sh" > assimilate.sh

        if [ -n "$reservation" ]; then
            echo "USING RESERVATION," $(/contrib/lsf/get_my_rsvid)
            bsub -U "$(/contrib/lsf/get_my_rsvid)" < assimilate.sh
        else
            bsub < assimilate.sh
        fi
        this_filter_runtime="${FILTER_TIME}"

    elif [ "$SUPER_PLATFORM" = 'derecho' ]; then

        cat > script.sed << EOF
2i\\
#=================================================================\\
#PBS -N assimilate_${datea}\\
#PBS -j oe\\
#PBS -A ${COMPUTER_CHARGE_ACCOUNT}\\
#PBS -l walltime=${FILTER_TIME}\\
#PBS -q ${FILTER_QUEUE}\\
#PBS -l job_priority=${FILTER_PRIORITY}\\
#PBS -m ae\\
#PBS -M ${EMAIL}\\
#PBS -k eod\\
#PBS -l select=${FILTER_NODES}:ncpus=${FILTER_PROCS}:mpiprocs=${FILTER_MPI}\\
#=================================================================
s%\${1}%${datea}%g
s%\${2}%${paramfile}%g
EOF

        sed -f script.sed "${SHELL_SCRIPTS_DIR}/assimilate.sh" > assimilate.sh

        qsub assimilate.sh

        this_filter_runtime="${FILTER_TIME}"

    fi

    cd "$RUN_DIR"   # Make sure we are still in the right place

    filter_thresh=$(echo "$this_filter_runtime" | cut -b3-4)
    filter_thresh=$((filter_thresh * 60 + $(echo "$this_filter_runtime" | cut -b1-1) * 3600))

    while [ ! -e filter_done ]; do

        # Check the timing. If it took longer than the time allocated, abort.
        if [ -e filter_started ]; then

            start_time=$(head -1 filter_started)
            end_time=$(date +%s)

            total_time=$((end_time - start_time))
            if [ "$total_time" -gt "$filter_thresh" ]; then

                # If the job needs to be aborted ... we need to qdel the hanging job

                echo "Time exceeded the maximum allowable time. Exiting."
                touch ABORT_RETRO
                ${REMOVE} filter_started
                exit 5

            fi

        fi
        sleep 10

    done

    echo "Filter is done, cleaning up"

    ${MOVE} icgen.o* "${OUTPUT_DIR}/${datea}/logs/"
    ${REMOVE} "${RUN_DIR}/filter_started"  \
              "${RUN_DIR}/filter_done"  \
              "${RUN_DIR}/obs_seq.out"     \
              "${RUN_DIR}/postassim_priorinf"*  \
              "${RUN_DIR}/preassim_priorinf"*
    if [ -e assimilate.sh ]; then ${REMOVE} "${RUN_DIR}/assimilate.sh"; fi

    echo "Listing contents of rundir before archiving at $(date)"
    ls -l *.nc blown* dart_log* filter_* input.nml obs_seq* Output/inf_ic*
    mkdir -p "${OUTPUT_DIR}/${datea}/"{Inflation_input,WRFIN,PRIORS,logs}

    # Create an analysis increment file that has valid static data.
    # First, create the difference of a subset of variables
    # Second, create a netCDF file with just the static data
    # Third, append the static data onto the difference.
    ncdiff -F -O -v "$extract_str" postassim_mean.nc preassim_mean.nc analysis_increment.nc
    ncks -F -O -x -v "${extract_str}" postassim_mean.nc static_data.nc
    ncks -A static_data.nc analysis_increment.nc

    # Move diagnostic and obs_seq.final data to storage directories

    for FILE in postassim_mean.nc preassim_mean.nc postassim_sd.nc preassim_sd.nc \
                obs_seq.final analysis_increment.nc output_mean.nc output_sd.nc; do
        if [ -e "$FILE" ] && [ -s "$FILE" ]; then
            ${MOVE} "$FILE" "${OUTPUT_DIR}/${datea}/."
            if [ ! $? -eq 0 ]; then
                echo "Failed moving ${RUN_DIR}/${FILE}"
                touch BOMBED
            fi
        else
            echo "${OUTPUT_DIR}/${FILE} does not exist and should."
            ls -l
            touch BOMBED
        fi
    done

    echo "Past the analysis file moves"

    # Move inflation files to storage directories
    # The output inflation file is used as the input for the next cycle,
    # so rename the file 'on the fly'.
    cd "${RUN_DIR}"
    if [ "$ADAPTIVE_INFLATION" = "1" ]; then
        old_file=(input_postinf_mean.nc  input_postinf_sd.nc  input_priorinf_mean.nc  input_priorinf_sd.nc)
        new_file=(output_postinf_mean.nc output_postinf_sd.nc output_priorinf_mean.nc output_priorinf_sd.nc)
        i=0
        nfiles=${#new_file[@]}
        while [ "$i" -lt "$nfiles" ]; do
            if [ -e "${new_file[$i]}" ] && [ -s "${new_file[$i]}" ]; then
                ${MOVE} "${new_file[$i]}" "${OUTPUT_DIR}/${datea}/Inflation_input/${old_file[$i]}"
                if [ ! $? -eq 0 ]; then
                    echo "Failed moving ${RUN_DIR}/Output/${new_file[$i]}"
                    touch BOMBED
                fi
            fi
            i=$((i + 1))
        done
        echo "Past the inflation file moves"
    fi   # Adaptive_inflation file moves

    # Submit jobs to integrate ensemble members to next analysis time ...
    # BEFORE calculating the observation-space diagnostics for the existing cycle.

    echo "Ready to integrate ensemble members"

    # Removing old start_member and done_member diagnostics
    if [ -e "${RUN_DIR}/start_member_1" ]; then
        ${REMOVE} "${RUN_DIR}/start_member_"*  \
                  "${RUN_DIR}/done_member_"*
    fi

    n=1
    while [ "$n" -le "$NUM_ENS" ]; do

        if [ "$SUPER_PLATFORM" = 'LSF queuing system' ]; then

            cat > script.sed << EOF
2i\\
#==================================================================\\
#SBATCH --job-name=assim_advance_${n}\\
#SBATCH --output=assim_advance_${n}.%j.log\\
#SBATCH --account=${COMPUTER_CHARGE_ACCOUNT}\\
#SBATCH --time=${ADVANCE_TIME}\\
#SBATCH --partition=${ADVANCE_QUEUE}\\
#SBATCH --ntasks=${ADVANCE_CORES}\\
#SBATCH --exclusive\\
#==================================================================
s%\${1}%${datea}%g
s%\${2}%${n}%g
s%\${3}%${paramfile}%g
EOF

            sed -f script.sed "${SHELL_SCRIPTS_DIR}/assim_advance.sh" > "assim_advance_mem${n}.sh"
            if [ -n "$reservation" ]; then
                echo "MEMBER ${n} USING RESERVATION," $(/contrib/lsf/get_my_rsvid)
                bsub -U "$(/contrib/lsf/get_my_rsvid)" < "assim_advance_mem${n}.sh"
            else
                bsub < "assim_advance_mem${n}.sh"
            fi

        elif [ "$SUPER_PLATFORM" = 'derecho' ]; then

            cat > script.sed << EOF
2i\\
#=================================================================\\
#PBS -N assim_advance_${n}\\
#PBS -j oe\\
#PBS -A ${COMPUTER_CHARGE_ACCOUNT}\\
#PBS -l walltime=${ADVANCE_TIME}\\
#PBS -q ${ADVANCE_QUEUE}\\
#PBS -l job_priority=${ADVANCE_PRIORITY}\\
#PBS -m a\\
#PBS -M ${EMAIL}\\
#PBS -k eod\\
#PBS -l select=${ADVANCE_NODES}:ncpus=${ADVANCE_PROCS}:mpiprocs=${ADVANCE_MPI}\\
#=================================================================
s%\${1}%${datea}%g
s%\${2}%${n}%g
s%\${3}%${paramfile}%g
EOF

            sed -f script.sed "${SHELL_SCRIPTS_DIR}/assim_advance.sh" > "assim_advance_mem${n}.sh"
            qsub "assim_advance_mem${n}.sh"

        fi
        n=$((n + 1))

    done

    # Compute Diagnostic Quantities (in the background)

    if [ -e obs_diag.log ]; then ${REMOVE} obs_diag.log; fi
    "${SHELL_SCRIPTS_DIR}/diagnostics_obs.sh" "$datea" "$paramfile" >& "${RUN_DIR}/obs_diag.log" &

    # ---------------------------------------------------------------------------
    # Check to see if all of the ensemble members have advanced
    # ---------------------------------------------------------------------------

    advance_thresh=$(echo "${ADVANCE_TIME}" | cut -b3-4)
    advance_thresh=$((advance_thresh * 60 + $(echo "${ADVANCE_TIME}" | cut -b1-1) * 3600))

    n=1
    while [ "$n" -le "$NUM_ENS" ]; do

        ensstring=$(printf "%04d" "$n")
        keep_trying=true

        while [ "$keep_trying" = 'true' ]; do

            # Wait for the script to start
            while [ ! -e "${RUN_DIR}/start_member_${n}" ]; do

                if [ "$SUPER_PLATFORM" = 'LSF queuing system' ]; then

                    if [ "$(bjobs -w | grep -c "assim_advance_${n}")" -eq 0 ]; then

                        echo "assim_advance_${n} is missing from the queue"
                        if [ -n "$reservation" ]; then
                            echo "MEMBER ${n} USING RESERVATION," $(/contrib/lsf/get_my_rsvid)
                            bsub -U "$(/contrib/lsf/get_my_rsvid)" < "assim_advance_mem${n}.sh"
                        else
                            bsub < "assim_advance_mem${n}.sh"
                        fi

                    fi

                elif [ "$SUPER_PLATFORM" = 'derecho' ]; then

                    if [ "$(qstat -wa | grep -c "assim_advance_${n}")" -eq 0 ]; then

                        echo "Warning, detected that assim_advance_${n} is missing from the queue"
                        echo "If this warning leads to missing output from ensemble ${n}"
                        echo "Consider enabling the qsub command within keep_trying while statement in driver.sh"

                        # qsub "assim_advance_mem${n}.sh"
                    fi

                fi
                sleep 5

            done
            start_time=$(head -1 "start_member_${n}")
            echo "Member $n has started. Start time $start_time"

            # Wait for the output file
            while true; do

                current_time=$(date +%s)
                length_time=$((current_time - start_time))

                if [ -e "${RUN_DIR}/done_member_${n}" ]; then

                    # If the output file already exists, move on
                    keep_trying=false
                    break

                elif [ "$length_time" -gt "$advance_thresh" ]; then

                    # Obviously, the job crashed. Resubmit to queue
                    ${REMOVE} "start_member_${n}"
                    echo "Didn't find the member done file"
                    if [ "$SUPER_PLATFORM" = 'LSF queuing system' ]; then

                        if [ -n "$reservation" ]; then
                            echo "MEMBER ${n} USING RESERVATION," $(/contrib/lsf/get_my_rsvid)
                            bsub -U "$(/contrib/lsf/get_my_rsvid)" < "assim_advance_mem${n}.sh"
                        else
                            bsub < "assim_advance_mem${n}.sh"
                        fi

                    elif [ "$SUPER_PLATFORM" = 'derecho' ]; then

                        qsub "assim_advance_mem${n}.sh"
                        sleep 5
                    fi
                    break

                fi
                sleep 15    # This might need to be longer

            done

        done

        # Move output data to correct location
        echo "Moving ${n} ${ensstring}"
        ${MOVE} "${RUN_DIR}/assim_advance_${n}.o"*              "${OUTPUT_DIR}/${datea}/logs/."
        ${MOVE} "WRFOUT/wrf.out_${gdatef[0]}_${gdatef[1]}_${n}" "${OUTPUT_DIR}/${datea}/logs/."
        ${MOVE} "WRFIN/wrfinput_d01_${n}.gz"                    "${OUTPUT_DIR}/${datea}/WRFIN/."
        ${MOVE} "${RUN_DIR}/prior_d01.${ensstring}"             "${OUTPUT_DIR}/${datea}/PRIORS/."
        ${REMOVE} "start_member_${n}" "done_member_${n}" "filter_restart_d01.${ensstring}"
        if [ -e "assim_advance_mem${n}.sh" ]; then ${REMOVE} "assim_advance_mem${n}.sh"; fi
        pert=$(cat "${RUN_DIR}/advance_temp${n}/mem${n}_pert_bank_num")
        echo "Member $n uses perturbation bank ensemble member $pert" >>  "${OUTPUT_DIR}/${datea}/pert_bank_members.txt"

        n=$((n + 1))

    done

    # ---------------------------------------------------------------------------
    # All ensemble members should have advanced by now.
    # ---------------------------------------------------------------------------

    if [ -e obs_prep.log ]; then ${REMOVE} obs_prep.log; fi

    # Clean everything up and finish

    # Move DART-specific data to storage directory
    ${COPY} input.nml "${OUTPUT_DIR}/${datea}/."
    ${MOVE} "${RUN_DIR}/dart_log.out" "${RUN_DIR}/dart_log.nml" "${RUN_DIR}"/*.log "${OUTPUT_DIR}/${datea}/logs/."

    # Remove temporary files from both the run directory and old storage directories
    ${REMOVE} "${OUTPUT_DIR}/${datep}/wrfinput_d"*"_mean" "${RUN_DIR}/wrfinput_d"* "${RUN_DIR}/WRF"

    # Prep data for archive
    cd "${OUTPUT_DIR}/${datea}"
    gzip -f wrfinput_d*_"${gdate[0]}"_"${gdate[1]}"_mean wrfinput_d*_"${gdatef[0]}"_"${gdatef[1]}"_mean wrfbdy_d*_mean
    tar -cvf retro.tar obs_seq.out wrfin*.gz wrfbdy_d*.gz
    tar -rvf dart_data.tar obs_seq.out obs_seq.final wrfinput_d*.gz wrfbdy_d*.gz \
                          Inflation_input/* logs/* *.dat input.nml
    ${REMOVE} wrfinput_d*_"${gdate[0]}"_"${gdate[1]}"_mean.gz wrfbdy_d*.gz
    gunzip -f wrfinput_d*_"${gdatef[0]}"_"${gdatef[1]}"_mean.gz

    cd "${RUN_DIR}"
    ${MOVE} "${RUN_DIR}/assim"*.o*            "${OUTPUT_DIR}/${datea}/logs/."
    ${MOVE} "${RUN_DIR}"/*log                 "${OUTPUT_DIR}/${datea}/logs/."
    ${REMOVE} "${RUN_DIR}/input_priorinf_"*
    ${REMOVE} "${RUN_DIR}/static_data"*
    touch prev_cycle_done
    touch "${RUN_DIR}/cycle_finished_${datea}"
    rm "${RUN_DIR}/cycle_started_${datea}"

    # If doing a reanalysis, increment the time if not done. Otherwise, let the script exit
    if [ "$restore" = "1" ]; then
        if [ "$datea" = "$datefnl" ]; then
            echo "Reached the final date"
            echo "Script exiting normally"
            exit 0
        fi
        datea=$(${DART_DIR}/models/wrf/work/advance_time "$datea" "${ASSIM_INT_HOURS}")
    else
        echo "Script exiting normally cycle ${datea}"
        exit 0
    fi
done

exit 0

