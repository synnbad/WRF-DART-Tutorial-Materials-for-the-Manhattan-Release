#!/bin/csh
#
# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

# init_ensemble_var.csh - script that creates perturbed initial
#                         conditions from the WRF-VAR system.
#                         (perts are drawn from the perturbation bank)
#
# created Nov. 2007, Ryan Torn NCAR/MMM
# modified by G. Romine 2011-2018

set initial_date = ${1}
set paramfile = `readlink -f ${2}` # Get absolute path for param.csh from command line arg
source $paramfile

cd ${RUN_DIR}

# KRF Generate the i/o lists in rundir automatically when initializing the ensemble
set num_ens = ${NUM_ENS}
set input_file_name  = "input_list_d01.txt"
set input_file_path  = "./advance_temp"
set output_file_name = "output_list_d01.txt"

set n = 1

if ( -e $input_file_name )  rm $input_file_name
if ( -e $output_file_name ) rm $output_file_name

while ($n <= $num_ens)

   set     ensstring = `printf %04d $n`
   set  in_file_name = ${input_file_path}${n}"/wrfinput_d01"
   set out_file_name = "filter_restart_d01."$ensstring

   echo $in_file_name  >> $input_file_name
   echo $out_file_name >> $output_file_name

   @ n++
end
###

set gdate  = (`echo $initial_date 0h -g | ${DART_DIR}/models/wrf/work/advance_time`)
set gdatef = (`echo $initial_date ${ASSIM_INT_HOURS}h -g | ${DART_DIR}/models/wrf/work/advance_time`)
set wdate  =  `echo $initial_date 0h -w | ${DART_DIR}/models/wrf/work/advance_time`
set yyyy   = `echo $initial_date | cut -b1-4`
set mm     = `echo $initial_date | cut -b5-6`
set dd     = `echo $initial_date | cut -b7-8`
set hh     = `echo $initial_date | cut -b9-10`

${COPY} ${TEMPLATE_DIR}/namelist.input.meso namelist.input
${REMOVE} ${RUN_DIR}/WRF
${LINK} ${OUTPUT_DIR}/${initial_date} WRF

set n = 1
while ( $n <= $NUM_ENS )

   echo "  QUEUEING ENSEMBLE MEMBER $n at `date`"

   mkdir -p ${RUN_DIR}/advance_temp${n}

   ${LINK} ${RUN_DIR}/WRF_RUN/* ${RUN_DIR}/advance_temp${n}/.
   ${LINK} ${RUN_DIR}/input.nml ${RUN_DIR}/advance_temp${n}/input.nml

   ${COPY} ${OUTPUT_DIR}/${initial_date}/wrfinput_d01_${gdate[1]}_${gdate[2]}_mean \
           ${RUN_DIR}/advance_temp${n}/wrfvar_output.nc
   sleep 2
   ${COPY} ${RUN_DIR}/add_bank_perts.ncl ${RUN_DIR}/advance_temp${n}/.

   set cmd3 = "ncl 'MEM_NUM=${n}' 'PERTS_DIR="\""${PERTS_DIR}"\""' ${RUN_DIR}/advance_temp${n}/add_bank_perts.ncl"
   ${REMOVE} ${RUN_DIR}/advance_temp${n}/nclrun3.out
          cat >!    ${RUN_DIR}/advance_temp${n}/nclrun3.out << EOF
          $cmd3
EOF

   echo $cmd3 >! ${RUN_DIR}/advance_temp${n}/nclrun3.out.tim   # TJH replace cat above


   cat >! ${RUN_DIR}/rt_assim_init_${n}.sh << EOF
#!/bin/sh
#=================================================================
#======================================
#SBATCH --job-name=first_advance_${n}
#SBATCH -A chipilskigroup_q
#SBATCH --time=00:10:00
#SBATCH --partition=chipilskigroup_q
#SBATCH --qos=normal
#SBATCH --output=first_advance_${n}.out
#SBATCH --error=first_advance_${n}.err
#SBATCH --ntasks=10
#SBATCH --export=ALL
#======================================
module restore

echo "rt_assim_init_${n}.sh is running in \$(pwd)"

cd ${RUN_DIR}/advance_temp${n}

if [ -e wrfvar_output.nc ]; then
    echo "Running nclrun3.out to create wrfinput_d01 for member $n at \$(date)"

    chmod +x nclrun3.out
    ./nclrun3.out > add_perts.out 2> add_perts.err

    if [ ! -s add_perts.err ]; then
        echo "Perts added to member ${n}"
    else
        echo "ERROR! Non-zero status returned from add_bank_perts.ncl. Check ${RUN_DIR}/advance_temp${n}/add_perts.err."
        cat add_perts.err
        exit 1
    fi

    ${MOVE} wrfvar_output.nc wrfinput_d01
    echo "wrfvar_output moved as wrfinput_d01"
fi

cd ${RUN_DIR}
echo "Running first_advance.csh for member $n at \$(date)"

csh /gpfs/home/sa24m/Research/base/scripts/first_advance.csh $initial_date $n /gpfs/home/sa24m/Research/base/scripts/param.csh
EOF

sbatch ${RUN_DIR}/rt_assim_init_${n}.sh

   @ n++

end

exit 0

