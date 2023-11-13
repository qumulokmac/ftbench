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

function loadHosts
{
  if [ ! -e ${WORKERHOSTS} ]; then
    printf "\n\nCould not find the host config file: $WORKERHOSTS\n\n"
    exit -1
  else
    readarray -t HOSTS < $WORKERHOSTS
  fi
}

declare -a conf
declare -i total=1

loadHosts

while [[ "${total}" != "0" ]]
do
  total=0
  for host in $HOSTS
  do
	count=`ssh $USER@$host "ps -ef | grep frametest | grep -v grep |  grep bash | wc -l | awk '{print \$1}'"`
	total=$(expr $total + $count)
	if [ $total == 0 ] ; then
		echo "All done"
		exit 0
	else
		printf "Host $host has $count frametest processes running\n"
	fi
  done
  echo "There are $total processes still running"
  sleep 30
done
echo "There are ${total} frametest processes running, moving on"


