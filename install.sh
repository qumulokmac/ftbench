#!/bin/bash
################################################################################
# ftbench installer 
# kmac@qumulo.com
# Nov 10th, 2023
################################################################################

USER=`whoami`
###
# Prompt the user for the $FTEST_HOME location
###
printf "Enter the absolute path for the install directory [Hit enter for \$HOME/ftbench] "
read USERINPUT

if [ -z $USERINPUT ]
then
  export FTEST_HOME=${HOME}/ftbench
  echo "export FTEST_HOME=${HOME}/ftbench" >> ${HOME}/.bashrc
  printf "Set \$FTEST_HOME to ${FTEST_HOME}\n"
else
  if [[ "${USERINPUT}" != \/*  ]] ; then
    printf "Please use the absolute path. Example: /home/qumulo/installdir \n"
    exit 1
  else
    mkdir -p ${USERINPUT}
  fi
  printf "\nSetting \$FTEST_HOME to ${USERINPUT}\n"
  export FTEST_HOME=${USERINPUT}/ftbench
  echo "export FTEST_HOME=${USERINPUT}/ftbench" >> ${HOME}/.bashrc
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
  else
    sudo cp /tmp/frametest /usr/local/bin
    sudo chmod 755 /usr/local/bin/frametest
    sudo ln -s /usr/bin/parallel-ssh /usr/local/bin/pssh
  fi
###
# Chek that frameset is installed and working
###

printf "Checking that frametest is installed in /usr/local/bin and functional...\n"
/usr/local/bin/frametest > /dev/null 2>&1

if [[ $? != 1 ]]; then
  printf "Frametest is not working correctly. It is likely that the prerequesite libraries are mssing. See Readme.\n"
  exit 1
else
  printf "Frametest found and functional, proceeding\n"
fi
###
# Copy the content from the repo to the install directory
# Checking that this install.sh script is being run from the git base directory, where this install.sh resides
###
cd - > /dev/null 
if [ ! -e scripts/ftbench.sh ] ; then
  printf "Please run install.sh the git repo directory, exiting\n\n"
  exit 2
fi
mkdir -p $FTEST_HOME/config $FTEST_HOME/output $FTEST_HOME/archive $FTEST_HOME/tools ${FTEST_HOME}/scripts 
sudo mkdir /mnt/ftbench 
sudo chown $USER /mnt/ftbench

if [ ! $? ]; then
  printf "\nCould not create the ftbench subdirs, check: $FTEST_HOME\n"
  exit 1
fi

cp -rp  scripts/* ${FTEST_HOME}/scripts
cp -rp  config/* ${FTEST_HOME}/config
cp -rp  tools/* ${FTEST_HOME}/tools
chmod -R 755 ${FTEST_HOME}

printf "ftbench installed in: $FTEST_HOME\n"
printf "To set \$FTEST_HOME source the .bashrc file as such:\n\n"
printf ". ~/.bashrc\n"
printf "echo \$FTEST_HOME"


exit 0 
