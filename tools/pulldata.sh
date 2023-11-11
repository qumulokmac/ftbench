#!/bin/bash 

################################################################################
# Be sure to read the README.md - https://github.com/qumulokmac/ftbench.git
################################################################################

###
# Check that FTEST_HOME is set and exists
###
if [ ! -e $FTEST_HOME ]; then
  printf "FTEST_HOME environmental variable is not set or doesnt exist"
  exit 1
fi

WORKERHOSTS="${FTEST_HOME}/config/workers.conf"
OUTPUTDIR="${FTEST_HOME}/output"
USER=`whoami`

HOSTS=`cat $WORKERHOSTS`

for host in $HOSTS
do
    scp -rp $USER@$host:${OUTPUTDIR}/* ${OUTPUTDIR} >/dev/null
done
