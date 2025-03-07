2i
#======================================
#SBATCH --job-name=run_real
#SBATCH -A 
#SBATCH --time=00:10:00
#SBATCH --partition=
#SBATCH --qos=
#SBATCH --output=run_real.out
#SBATCH --error=run_real.err
#SBATCH --ntasks=
#SBATCH --export=ALL
#======================================


s%${1}%/gpfs/home/sa24m/Research/base1/scripts/param.sh%g
