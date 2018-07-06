#'@title Representativeness
#'
#'@description Perform Tom-style representativeness analyses  
#'
#'@param dir (string) Directory where raster grids (transgrids) are located. Will read every file by default.
#'@param ext (str) Three letter string denoting the raster file extention (i.e. type of grid - e.g. flt, tif). Default 'flt.'
#'@param xy (string) Filepath to a CSV file where locations to sample the grid are located. Assumes x, y, z format. Column names are not important.
#'@param analysis (string) The type of analysis to perform. Options are 'min_dis', 'sumsim', 'sumsim_cond.' See notes below. 
#'@param dst (string) Directory and filename to save outputs to. If NULL a folder will be created in dir called 'representativeness_<datetime>' to which output files will be written.
#'@param job_script (string) Filepath to write jobs script to. Deafult (NULL) will try and use another given arg, else /home/$USER/REPRESENTATIVENESS_<datetime>.sh
#'@param walltime (string) Wall time to pass to slurm. If NULL this is guessed.
#'@param mem (int) Memory require to pass to slurm (in GB). If NULL this is guessed.
#'@param logfile (str) Filepath to write log file to. Default will be the location from which the analysis is executed (probably /home/$USER/slurm-<JOBID>.log)
#'@param jobname (str) Job name to pass to slurm. Default will be default to slurm's choice.
#'@param nCPU (int) Number of CPUs to use (default 19)
#'@param dry_run (bool) If TRUE, job will not be submitted to slurm, but filepath to job script (.sh) returned. 
#'
#'@return If dry_run, filepath to job script, else outputs written to dir.
#'
#'@note 
#'\itemize{
##'  \item{"min_dis"} {calculates minimum distance to all locations (calculated on ecological distance)}
##'  \item{"sumsim"} {calculates the summed similarity to all locations}
##'  \item{"sumsim_cond"} {calculates the summed similarity to all locations multiplied by a value given in the third column of locations (e.g. condition, richness, etc)}
##' }
#'
#'@importFrom data.table fread
#'@importFrom getPass getPass
#'
#'@export
#'
representativeness_config = function(dir, ext = 'flt', xy, analysis, dst = NULL,
                                     job_script = NULL, walltime = NULL, nCPU = 19, 
                                     mem = NULL, logfile = NULL, jobname = NULL, 
                                     dry_run = TRUE){
  ## get user
  usr = Sys.info()[['user']]
  ## get system
  if (is.null(job_script)){
    
    if (Sys.info()[['sysname']] == 'Windows'){
    ## write to unc path
    job_script = paste0('//pearceyhome.csiro.au/home_intel/', usr)
      if (is.null(jobname)){
        job_script = paste0(job_script, '/', gsub('.CSV', '', basename(xy)), '.sh')
      } else {
        job_script = paste0(job_script, '/', job_name, '.sh')
      }
    }
  } ## job script done
  
  if (!is.null(jobname)){
    t = strsplit(as.character(Sys.time()), ' ')[[1]][2]
    jobname = paste(analysis, t, sep = '_')
  }
  
  if(!is.null(mem)){
    mem = paste0(mem, 'GB')
  } else {
    mem = '48GB'
  }
  
  if (is.null(walltime)){
    nrows = nrow(fread(xy, select = 1L))
    if (nrows < 50000){
      walltime = '01:59:00'
    } else if (nrows > 50000 & nrows < 100000) {
      walltime = '03:59:00'
    } else if (nrows > 100000 & nrows < 150000) {
      walltime = '06:59:00'
    } else {
      walltime = '1-00:00:00' # 24 hr
    }
  }
  
  if (is.null(logfile)){
    logfile = paste0(jobname, '.txt')
  }
  
  sink(job_script)
  cat('#!/bin/bash', sep = '\n')
  cat(paste0('#SBATCH --job-name=', jobname), sep = '\n')
  cat('#SBATCH --nodes=1', sep = '\n')
  cat(paste0('#SBATCH --ntasks-per-node=', nCPU), sep = '\n')
  cat(paste0('#SBATCH --mem=', mem), sep = '\n')
  cat(paste0('#SBATCH --time=', walltime), sep = '\n')
  cat(paste0('#SBATCH --output=', logfile), sep = '\n')
  cat ('\n')
  cat('echo "Launching slurm job id $SLURM_JOB_ID"', sep = '\n')
  cat('echo "$(date)"', sep = '\n')
  cat('\n')
  cat('module load python/3.6.1', sep = '\n')
  cat(paste('python /home/war42q/tomsstuff_py/representativeness.py', 
            dir, ext, xy, analysis, nCPU, dst), sep = '\n')
  cat('\n')
  cat('exit_code=$?', sep = '\n')
  cat('if [ "$exit_code" -ne 0 ]; then', sep = '\n') 
  cat('\t', 'echo "----------------------------------------"')
  cat('\n')
  cat('\t', 'echo "<< JOB FAIL! >> Exit code was $exit_code"')
  cat('\n')
  cat('else', sep = '\n')
  cat('\t', 'echo "Done!"')
  cat('\n')
  cat('fi')
  sink()
  
  if(dry_run){
    return(job_script)
    
  } else {
    representativeness_run(job_script)
  }
}


#'@title Run representativeness 
#'
#'@description Run representativeness using slurm
#'
#'@param job_script (string) Filepath to write jobs script to. 
#'
#'@return output from SLURM
#'
#'#'@importFrom getPass getPass
#'
#'@export
#'
representativeness_run = function(job_script){
  usr = Sys.info()[['user']]
  this_system = Sys.info()[['nodename']]
  this_system = unlist(lapply(c('pearcey', 'bracewell', 'ruby'), function(x)
    length(grep(x, this_system))))
  if (sum(this_system) > 0){
    system(paste('sbatch', job_script), intern = TRUE)
    print(system(paste('squeue -u', usr), intern = TRUE))
  } else {
    ## text file with slurm args
    txtfile = paste0(tempfile(), '.txt')
    sink(txtfile)
    cat('#!/bin/sh', sep = '\n')
    cat(paste('sbatch', job_script), sep = '\n')
    cat(paste('squeue -u', usr), sep = '\n')
    cat('exec /bin/bash')
    sink()
    ## submit job via putty
    pw = getPass()
    putty = paste('"C:\\Program Files (x86)\\PuTTY\\plink.exe"')
    args = paste("-ssh", paste0(usr, '@pearcey.hpc.csiro.au -l ', usr), "-pw", pw, '-m', txtfile) 
    system(paste(putty, args), intern = T)
    pw = NULL
  }
}

