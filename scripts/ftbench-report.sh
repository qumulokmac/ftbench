#!/usr/bin/bash
####################################################################################################
# Name:         ftbench-report.sh
# Author:       kmac@qumulo.com
# Desc:         Script takes the output from the frametest benchmarks and formats it for import
# Date:         Npv 2nd, 2023
####################################################################################################

###############################################################################
# Be sure to read the README.md - https://github.com/qumulokmac/ftbench.git
################################################################################

###
# Check that FTEST_HOME is set and exists
###
if [ ! -e $FTEST_HOME ]; then
  printf "FTEST_HOME environmental variable is not set or doesnt exist"
  exit 1
fi

OUTPUTDIR="${FTEST_HOME}/output"

${FTEST_HOME}/tools/pulldata.sh

echo "\"Date\",\"Time\",\"Codec\",\"Dropped Frames\",\"Framesize\",\"NumFrames\",\"Threads\",\"FPS\",\"Zsize\",\"NumHosts\",\"Framerate\",\"Bandwidth\",\"Number of Streams\",\"Host\",\"Test Path\",\"Output Filename\""
for file in `find ${OUTPUTDIR} -name "*.csv"`
do
  CODEC=$(echo $file  | cut -d '-' -f12 | sed -e 's/\.csv//g')
  FRAMESIZE=$(echo $file  | cut -d '-' -f4 | sed -e 's/\.csv//g')
  NUMFRAMES=$(echo $file  | cut -d '-' -f5 | sed -e 's/\.csv//g')
  THREADS=$(echo $file  | cut -d '-' -f6 | sed -e 's/\.csv//g')
  FPS=$(echo $file  | cut -d '-' -f7 | sed -e 's/\.csv//g')
  ZSIZE=$(echo $file  | cut -d '-' -f8 | sed -e 's/\.csv//g')
  NUMHOSTS=$(echo $file  | cut -d '-' -f8 | sed -e 's/\.csv//g')
  NUMSTREAMS=$(echo $file  | cut -d '-' -f10 | sed -e 's/\.csv//g')

  DATE=$(head $file | grep Date $file  | sed -e 's/,/ /' | cut -d ' ' -f2 )
  TIME=$(head $file | grep Time $file  | sed -e 's/,/ /' | cut -d ' ' -f2 )
  HOST=$(head $file | grep Hostname $file  | sed -e 's/,/ /' | cut -d ' ' -f2 )
  TESTPATH=$(head $file | grep TestPath $file  | sed -e 's/,/ /' | cut -d ' ' -f2 )
  FRAMERATE=$(head $file | grep FrameRate $file  | sed -e 's/,/ /' | cut -d ' ' -f2 | sed -e 's/,fps//g' )
  BANDWIDTH=$(head $file | grep Bandwidth $file  | sed -e 's/,/ /' | cut -d ' ' -f2| sed -e 's/,MB\/s//g' )
  DROPPEDFRAMES=$(head $file | grep DroppedFrames $file  | sed -e 's/,/ /' | cut -d ' ' -f2 )

  printf "\"${DATE}\",\"${TIME}\",\"${CODEC}\",\"${DROPPEDFRAMES}\",\"${FRAMESIZE}\",\"${NUMFRAMES}\","
  printf "\"${THREADS}\",\"${FPS}\",\"${ZSIZE}\",\"${NUMHOSTS}\",\"${FRAMERATE}\","
  printf "\"${BANDWIDTH}\",\"${NUMSTREAMS}\",\"${HOST}\",${TESTPATH},\"${file}\"\n"
done

exit 0
