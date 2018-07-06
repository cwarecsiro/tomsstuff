### Notes  

**Install**    
To install on the hpc, you'll need to set an accessible directory to write into.   
This requires using with_libpaths to tell install_github what you're up to.   
The following will install the package into your /home/ account (along with dependencies)  
Either make a new dir, or point it where you like otherwise.
install on hpc as follows:  
`library(devtools)`  
`usr = Sys.info()[['user']]`  
`withr::with_libpaths(new = paste('/home/', usr', install_github('cwarecsiro/tomsstuff'))`

On windows, you can just use:
`install_github('cwarecsiro/tomsstuff')

**Use**  
representativeness_config sets up a job (.sh) script to send to slurm on the hpc.  
You can optionally be on a windows machine, and it will - as long as you have putty   
insalled - send the shell script to the hpc to run (pearcey only presently).  

If you set dry_run to TRUE, the shell script will be created by not submitted.   
You can fiddle with this, and submit directly from an hpc terminal, or use the   
representativeness_run function. 