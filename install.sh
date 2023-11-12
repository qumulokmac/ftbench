#!/bin/bash
################################################################################
# ftbench installer 
# kmac@qumulo.com
# Nov 10th, 2023
################################################################################

###
# Check that FTEST_HOME is set and exists
###
if [ ! -e $FTEST_HOME ]; then
  printf "FTEST_HOME environmental variable is not set or doesnt exist\n"
  printf "Run mkdir \$FTEST_HOME ?\n\n"
  exit 1
fi

###
# Chek that frameset is installed and working
###

printf "Checking that frametest is installed in /usr/local/bin and working...\n\n"
/usr/local/bin/frametest > /dev/null 2>&1

if [[ $? != 1 ]]; then
  printf "Frametest is not installed or the prerequesite libraries are mssing. See Readme\n"
  exit 1
else
  printf "Frametest found and functional, proceeding\n\n"
fi
###
# Copy the content from the repo to the install directory
# Checking that this install.sh script is being run from the git base directory, where this install.sh resides
###
if [ ! -e 'scripts/ftbench.sh' ] ; then
  printf "Please run install.sh the git repo directory, exiting\n\n"
  exit 2
fi
mkdir -p $FTEST_HOME/config $FTEST_HOME/output $FTEST_HOME/archive 

if [ ! $? ]; then
  printf "\n\nCould not create the ftbench subdirs, check: $FTEST_HOME\n"
  exit 1
fi

cp -rp  scripts ${FTEST_HOME}
cp -rp  tools ${FTEST_HOME}
mkdir -p ${FTEST_HOME}/output ${FTEST_HOME}/archive

printf "\nftbench installed in $FTEST_HOME\n"

exit 0 
