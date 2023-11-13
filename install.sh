#!/bin/bash
################################################################################
# ftbench installer 
# kmac@qumulo.com
# Nov 10th, 2023
################################################################################

###
# Prompt the user for the $FTEST_HOME location
###
printf "Enter the absolute path for the install directory [Hit enter for \$HOME/ftbench] "
read answer

if [ -z $answer ]
then
  printf "\nSetting \$FTEST_HOME to ${answer}\n"
  export FTEST_HOME=$HOME/ftbench
  echo "export FTEST_HOME=$HOME/ftbench" >> $HOME/.bashrc
else
  if [ "${answer}" != '^\/' ] ; then
    printf "Please use the absolute path\n"
    exit 1
  fi
  printf "\nSetting \$FTEST_HOME to ${answer}\n"
  export FTEST_HOME=${answer}/ftbench
  echo "export FTEST_HOME=${answer}/ftbench" >> $HOME/.bashrc
fi

if [ ! -e $FTEST_HOME ]; then
  printf "Creating directory ${FTEST_HOME}\n"
  mkdir $FTEST_HOME
  if [ $? != 0 ] ; then
      printf "Could not create directory ${FTEST_HOME}\n"
      exit 1
  fi
fi
###
# Install frametest
###

  cd /tmp
  wget -P /tmp -q http://www.dvsus.com/gold/san/frametest/lin/frametest
  if [ $? != 0 ] ; then
      printf "Could not download frametest. Check network connectivity to: http://www.dvsus.com/gold/san/frametest/lin/frametest. \n"
      exit 1
  fi
  sudo chmod 755 /usr/local/bin/frametest
  sudo cp /tmp/frametest /usr/local/bin
  sudo ln -s /usr/bin/parallel-ssh /usr/local/bin/pssh
###
# Chek that frameset is installed and working
###

printf "Checking that frametest is installed in /usr/local/bin and functional...\n\n"
/usr/local/bin/frametest > /dev/null 2>&1

if [[ $? != 1 ]]; then
  printf "Frametest is not working correctly. It is likely that the prerequesite libraries are mssing. See Readme.\n"
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
mkdir -p $FTEST_HOME/config $FTEST_HOME/output $FTEST_HOME/archive $FTEST_HOME/tools ${FTEST_HOME}/scripts

if [ ! $? ]; then
  printf "\n\nCould not create the ftbench subdirs, check: $FTEST_HOME\n"
  exit 1
fi

cp -rp  scripts/* ${FTEST_HOME}/scripts
cp -rp  tools/* ${FTEST_HOME}/tools
chmod -R 755 ${FTEST_HOME}

printf "\nftbench installed in $FTEST_HOME\n"

exit 0 
