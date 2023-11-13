#!/bin/bash
################################################################################
#
# Name:		ftbench-result-matrix.sh
# Author:	kmac@qumulo.com
# Date:		November 8th, 2023
# Purpose:	This script will pull the informstion needed for the PASS/FAIL matrix
#
################################################################################
# Be sure to read the README.md - https://github.com/qumulokmac/ftbench.git
#
################################################################################

###
# Check that FTBENCH_HOME is set and exists
###
if [ ! -e $FTBENCH_HOME ]; then
  printf "FTBENCH_HOME environmental variable is not set or doesnt exist"
  exit 1
fi

OUTPUTDIR="${FTBENCH_HOME}/output"

declare -a CSV 
declare -a DROPPED
DATE=`date +%Y%m%d%H%m%S`

################################################################################
function loadCSVs
{
  if [ ! -e ${OUTPUTDIR} ]; then
    printf "\n\nCould not find the output directory at: $OUTPUTDIR\n\n"
    exit -1
  else
    cd $OUTPUTDIR
    `ls -1 *.csv > /tmp/csv.files.${DATE}`
    CSV=(`cat /tmp/csv.files.${DATE}`)
  fi
}

function collectDrops
{
  `rm /tmp/*.drops`
  for file in "${CSV[@]}"
  do
  	declare CODEC
  	declare -i DROPPEDFRAMES
  	declare -i NUMSTREAMS

  	CODEC=$(echo $file  | cut -d '-' -f12 | sed -e 's/\.csv//g' | cut -d '_' -f1)
  	DROPPEDFRAMES=$(head $file | grep DroppedFrames $file  | sed -e 's/,/ /' | cut -d ' ' -f2 )
    NUMSTREAMS=$(echo $file  | cut -d '-' -f10 |  sed -e 's/\.csv//g')

    index="${CODEC}_${NUMSTREAMS}"
    `printf "${DROPPEDFRAMES}+" >> /tmp/${index}.${DATE}.drops`
    unset CODEC
    unset DROPPEDFRAMES
    unset NUMSTREAMS
  done
}

function reportTestResults
{
  cd /tmp
  sed -i 's/\+$/\n/g' *.${DATE}.drops
  `ls -1 *.drops > dropped.${DATE}`
  DROPPED=(`cat dropped.${DATE}`)

  printf "\"Codec\",\"Resolution\",\"Total streams\",\"Result\",\"Total dropped frames\"\n"
  for file in "${DROPPED[@]}"
  do 
    TDROP=`cat $file | bc`
    if [ "${TDROP}" != "0" ] ; then
      PF=FAIL
    else
      PF=PASS
    fi
    CODEC=$(echo $file  | cut -d '.' -f1 | cut -d '_' -f1 | sed -e 's/UHD/4K/g')
    RESOLUTION=$(echo $CODEC | sed -e 's/.*\(..\)/\1/')
    CODEC=$(echo $CODEC | sed -e 's/..$//' )

    # Humanize the Codec names
    case $CODEC in

    h264)
      CODEC="H.264"
      ;;
    AvidDNxHD)
      CODEC="Avid DNx HD"
      ;;
    AvidDNxHR)
      CODEC="Avid DNx HR"
      ;;
    ProRes422)
      CODEC="Apple ProRes 422"
      ;;
    ProRes4444)
      CODEC="Apple ProRes 4444"
      ;;
    ProRes4444HQ)
      CODEC="Apple ProRes 4444 HQ"
      ;;
    ProResHQ422)
      CODEC="Apple ProRes 422 HQ"
      ;;
    *)
      echo "Cannot humanize Codec $CODEC, unknown."
      ;;
    esac

    STREAMS=$(echo $file  | cut -d '.' -f1 | cut -d '_' -f2 )
    printf "\"${CODEC}\",\"${RESOLUTION}\",\"${STREAMS}\",\"${PF}\",\"${TDROP}\"\n"
  done
}

################################################################################
# Main
################################################################################

loadCSVs
collectDrops
reportTestResults

