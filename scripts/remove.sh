#!/bin/bash

# Enable safety flags
set -e  # Exit on error
set -u  # Treat unset variables as errors
set -o pipefail  # Ensure pipeline failures are not masked

# Function to safely remove files if they exist
safe_rm() {
    for file in $1; do
        if [[ -e "$file" ]]; then
            rm -f "$file"
            echo "Removed file: $file"
        else
            echo "Not found: $file"
        fi
    done
}

# Function to safely remove directories (Handles Wildcards)
safe_rmdir() {
    for dir in $1; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir"
            echo "Removed directory: $dir"
        else
            echo "Directory not found: $dir"
        fi
    done
}
cd ../rundir
# Remove files if they exist
safe_rm "first_advance_*"
safe_rm "rt_assim_init_*"
safe_rm "start_member_*"
safe_rm "done_member_*"
safe_rm "filter_control*"
safe_rm "HAD_TO_WAIT"
safe_rm "cycle_finished_*"
safe_rm "blown_*.out"
safe_rm "postassim_member_*.nc"
safe_rm "input_priorinf_mean.nc"
safe_rm "input_priorinf_sd.nc"
safe_rm "preassim_member_*.nc"
safe_rm "prev_cycle_done"
safe_rm "dart_log.out"
safe_rm "*.txt"
safe_rm "/gpfs/research/scratch/sa24m/base/output/2017042706/*.nc"

# Remove directories if they exist (Handles Wildcards)
safe_rmdir "/gpfs/research/scratch/sa24m/base/rundir/advance_temp*"  
safe_rmdir "Inflation_input"
safe_rmdir "../output/2017042700/Inflation_input"
safe_rmdir "/gpfs/research/scratch/sa24m/base/output/2017042706/logs/*"

echo "✅ Cleanup completed successfully!"

exit 0