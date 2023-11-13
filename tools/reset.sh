#!/bin/bash 
################################################################################
# Be sure to read the README.md - https://github.com/qumulokmac/ftbench.git
################################################################################

###
# Check that FTBENCH_HOME is set and exists
###
if [ ! -e $FTBENCH_HOME ]; then
  printf "FTBENCH_HOME environmental variable is not set or doesnt exist"
  exit 1
fi

WORKERHOSTS="${FTBENCH_HOME}/config/workers.conf"
OUTPUTDIR="${FTBENCH_HOME}/output"
OUTPUTDIR="${FTBENCH_HOME}/archive"
USER=`whoami`


echo "Checing if ftbench.sh is still running, Hit ctrl-c if it is not running. Enter anything to continue."
ps -ef | grep ftbench | grep -v grep 
read POO

echo "Stopping ftbench.sh..."
pkill ftbench.sh
echo "Killing stragler frametest processes"
pssh -h ${WORKERHOSTS} --inline-stdout "sudo pkill frametest"

echo "Process check, ftbench.sh should not be running, this should be empty."
ps -ef | grep ftbench | grep -v grep 

echo "Hit ctrl-c if it is still running and look into it. Enter anything to continue." 
read POO

echo "Archiving all of the generated logs and csv files from the prior run"
pssh -h $WORKERHOSTS  --inline-stdout "mv ${OUTPUTDIR}* ${ARCHIVEDIR}"

echo "Hit ctrl-c if archiving failed. Enter anything to continue." 
pssh -h $WORKERHOSTS  --inline-stdout "ls -l  ${OUTPUTDIR} | wc -l"
read POO


