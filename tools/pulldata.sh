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
USER=`whoami`

HOSTS=`cat $WORKERHOSTS`

for host in $HOSTS
do
    scp -rp $USER@$host:${OUTPUTDIR}/* ${OUTPUTDIR} >/dev/null
done
