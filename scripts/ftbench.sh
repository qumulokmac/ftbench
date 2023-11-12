#!/usr/bin/bash 
################################################################################
#
# Name:    ftbench.sh
# Author:  kmac@qumulo.com
# Date:    October 31st, 2023
#
# Note:  For frametest to work, you need to install the GLIBC compat libraries (It's a 32-bit app)
#   Ubuntu:  sudo apt-get install gcc-multilib
#   Centos:  sudo yum install glibc.i686
#
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

FTEXEC="/usr/local/bin"
BASEDATADIR="/mnt/ftbench/run-$$"
JOBFILE="${FTEST_HOME}/config/jobs.conf"
WORKERHOSTS="${FTEST_HOME}/config/workers.conf"
OUTPUTDIR="${FTEST_HOME}/output"
USER=`whoami`

################################################################################
function purgeDatadir
{
  echo "Starting the purge for ${BASEDATADIR} at `date`"
  find ${BASEDATADIR} -type f -print0 | xargs -0 rm -r --
  echo "Purged `date`"
}

function gatherLogs
{
  for (( hostindex=0; hostindex<${#HOSTS[@]}; hostindex++ ))
  do 
    printf "\n\n"
    printf '=%.0s' {1..100}

    mkdir -p ${OUTPUTDIR}
  
    if [ ! $? ]; then
      printf "\n\nCould not create the gathered log dir: ${OUTPUTDIR}\n"
      printf "Reconcile manually\n\n"
    fi

    command="scp -rp $USER@${HOSTS[$hostindex]}:/${OUTPUTDIR} ${OUTPUTDIR}/"
    printf "\nGathering output: ${command}\n\n"
    bash -c "${command}" 

    printf '=%.0s' {1..100}
    printf '\n'
  done

}

function loadHosts
{
  if [ ! -e ${WORKERHOSTS} ]; then
    printf "\n\nCould not find the host config file: $WORKERHOSTS\n\n"
    exit -1
  else
    readarray -t HOSTS < $WORKERHOSTS
  fi
}

function loadNodes
{
  if [ ! -e ${NODECFGFILE} ]; then
    printf "\n\nCould not find the node config file: $NODECFGFILE\n\n"
    exit -1
  else
    readarray -t NODES < $NODECFGFILE
  fi
}

function setup
{
  if [ ! -e ${JOBFILE} ]; then
    printf "\n\nCould not find the config file: $JOBFILE\n\n"
    exit -1
  else
    readarray -t conf < $JOBFILE
  fi

  mkdir -p ${OUTPUTDIR}
  if [ ! $? ]; then
    printf "\n\nCould not create the log dir: ${OUTPUTDIR}\n\n"
    exit -1
  else
    sudo chown -R `whoami` ${OUTPUTDIR}
  fi

  mkdir -p ${BASEDATADIR}
  if [ ! $? ]; then
    printf "\n\nCould not create the log dir: ${BASEDATADIR}\n\n"
    exit -1
  else
    sudo chown -R `whoami` ${BASEDATADIR}
  fi
}

function buildStreams()
{
  IFS='|'
  read -ra settings <<< $1

  if [ "${#settings[@]}" -ne "9" ]; then
    echo "CONFIG FORMAT ERROR: Entry has ${#settings[@]} fields. There should be exactly 9."
    echo "${settings[*]}"
    echo "Moving on"
    return 1
  fi

  operation=${settings[0]}
  framesize=${settings[1]}
  numframes=${settings[2]}
  numthreads=${settings[3]}
  fps=${settings[4]}
  zsize=${settings[5]}
  numhosts=${settings[6]}
  numstreams=${settings[7]}
  codecname=${settings[8]}

  ###
  # Need to add field level validation 
  ###

  printf '=%.0s' {1..100}
  printf "\n\tFramesize: $framesize\n"
  printf "\tNumber of frames: $numframes\n"
  printf "\tNumber of threads: $numthreads\n"
  printf "\tFPS: $fps\n"
  printf "\tZ-size: $zsize\n"
  printf "\tNumber of hosts: $numhosts\n"
  printf "\tStreams: $numstreams\n"
  printf "\tCodec: $codecname\n"

  UUID=`uuidgen`
  THISDATADIR="${BASEDATADIR}/${UUID}"
  mkdir -p ${THISDATADIR}
  if [ ! $? ]; then
    printf "\n\nCould not create the log dir: ${THISDATADIR}\n\n"
    exit -1
  else
    echo "Setting data directory: ${THISDATADIR}"
  fi

  for  (( streamindex=0; streamindex<$numstreams; streamindex++ ))
  do 
    DATE=`date +%Y%m%d%H%m%S` 
    BASENAME="ft-${DATE}-${RANDOM}-$framesize-$numframes-$numthreads-$fps-$zsize-$numhosts-$numstreams-$streamindex-$codecname"
    LOGFILE="${BASENAME}.log"
    WRITESTREAMS["$streamindex"]="sudo chrt 75 ${FTEXEC}/frametest --noinfo -x ${OUTPUTDIR}/${BASENAME}_write.csv -w $framesize -t $numthreads -n $numframes -f $fps ${THISDATADIR} "
    READSTREAMS["$streamindex"]="sudo chrt 75 ${FTEXEC}/frametest --noinfo -x ${OUTPUTDIR}/${BASENAME}_read.csv -r -t $numthreads -n $numframes -z $zsize -f $fps ${THISDATADIR} "
  done
  echo "Built ${#WRITESTREAMS[@]} streams for $UUID."

}

function waitOnStreams
{
  WAITTIME=30
  for pid in "${!WATCHPIDS[@]}"
  do
    echo "Checking on $pid"
    while [ -d /proc/${pid} ]
    do
      echo "Waiting $WAITTIME seconds for PID $pid ..."
      sleep $WAITTIME
    done
    echo "Process $pid has ended."
  done
  unset WATCHPIDS

}

function runWriteStreams
{
  hostindex=0  
  max=${#HOSTS[@]}
  
  for  (( streamindex=0; streamindex<$numstreams; streamindex++ ))
  do 
    command="ssh -tt ${USER}@${HOSTS[$hostindex]} '${WRITESTREAMS["${streamindex}"]} >> ${OUTPUTDIR}/ssh-${hostindex}-${HOSTS[$hostindex]}-${streamindex}.log' 2>&1 &"

    printf "\nRunning: $command \n\n"
    eval ${command}
    WATCHPIDS[$!]=$streamindex

    if [[ ("$hostindex" -eq "$((max-1))") && ("$streamindex" -ne "$((numstreams-1))") ]] ; then
      hostindex=0
      # echo "Resetting host index: $hostindex"

    else
      hostindex=$((hostindex+1))
      # echo "Incrementing host index: $hostindex"
    fi
  done
  waitOnStreams
}

function runReadStreams     
{
  hostindex=0  
  max=${#HOSTS[@]}

  for  (( streamindex=0; streamindex<$numstreams; streamindex++ ))
  do 
    command="ssh -tt ${USER}@${HOSTS[$hostindex]} '${READSTREAMS["${streamindex}"]}  >> ${OUTPUTDIR}/ssh-${hostindex}-${HOSTS[$hostindex]}-${streamindex}.log'  2>&1 &"

    printf "\nRunning: $command \n\n"
    eval ${command}
    WATCHPIDS[$!]=$streamindex

    if [[ ("$hostindex" -eq "$((max-1))") && ("$streamindex" -ne "$((numstreams-1))") ]] ; then
      hostindex=0
      # echo "Resetting host index: $hostindex"

    else
      hostindex=$((hostindex+1))
      # echo "Incrementing host index: $hostindex"
    fi
  done
  waitOnStreams
}

################################################################################
# Main
################################################################################

declare -a conf

setup
loadHosts
# loadNodes

len=${#conf[@]}

for (( i=0; i<$len; i++ ))
do 
  declare -gA WRITESTREAMS
  declare -gA READSTREAMS
  declare -a WATCHPIDS

  [[ ${conf[$i]} =~ ^#.* ]] && continue      # skip comments
  [[ -z ${conf[$i]} ]] && continue        # skip empty lines
  buildStreams "${conf[${i}]}" 

  runWriteStreams
  runReadStreams
  purgeDatadir

  unset WRITESTREAMS
  unset READSTREAMS
  unset WATCHPIDS

done

gatherLogs

exit 0 


