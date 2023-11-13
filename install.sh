#!/bin/bash
################################################################################
# FT Bench installer script
# kmac@qumulo.com
# Nov 10th, 2023
#
################################################################################

USER=`whoami`
###
# Prompt the user for the $FTBENCH_HOME location
###
printf "Enter the absolute path for the install directory [\$HOME/ftbench] "
read USERINPUT

if [ -z $USERINPUT ]
then
  export FTBENCH_HOME=${HOME}/ftbench
  echo "export FTBENCH_HOME=${HOME}/ftbench" >> ${HOME}/.bashrc
  printf "Set \$FTBENCH_HOME to ${FTBENCH_HOME}\n"
else
  if [[ "${USERINPUT}" != \/*  ]] ; then
    printf "Please use the absolute path. Example: /home/qumulo/installdir \n"
    exit 1
  else
    mkdir -p ${USERINPUT}
  fi
  printf "\nSetting \$FTBENCH_HOME to ${USERINPUT}\n"
  export FTBENCH_HOME=${USERINPUT}/ftbench
  echo "export FTBENCH_HOME=${USERINPUT}/ftbench" >> ${HOME}/.bashrc
fi

if [ ! -e $FTBENCH_HOME ]; then
  printf "Creating directory ${FTBENCH_HOME}\n"
  mkdir $FTBENCH_HOME
  if [ $? != 0 ] ; then
      printf "Could not create directory ${FTBENCH_HOME}\n"
      exit 1
  fi
fi
###
# Install frametest
###
  printf "Downloading frametest\n"
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
  printf "Frametest found and is functioning, proceeding\n"
fi
###
# Copy the content from the repo to the $FTBENCH_HOME directory
###
cd - > /dev/null 
if [ ! -e scripts/ftbench.sh ] ; then
  printf "Please run install.sh the git repo directory at /tmp/ftbench; exiting\n\n"
  exit 2
fi
mkdir -p $FTBENCH_HOME/config $FTBENCH_HOME/output $FTBENCH_HOME/archive $FTBENCH_HOME/tools ${FTBENCH_HOME}/scripts 
sudo mkdir /mnt/ftbench 
sudo chown $USER /mnt/ftbench

if [ ! $? ]; then
  printf "\nCould not create the ftbench subdirs, check: $FTBENCH_HOME\n"
  exit 1
fi

cp -rp  scripts/* ${FTBENCH_HOME}/scripts
cp -rp  config/* ${FTBENCH_HOME}/config
cp -rp  tools/* ${FTBENCH_HOME}/tools
chmod -R 755 ${FTBENCH_HOME}

printf "ftbench installed in: $FTBENCH_HOME\nBe sure to mount the NFS exports at /mnt/ftbench.\n"
printf "Either log out and back in, or source the .bashrc file to set \$FTBENCH_HOME.\nCommand to source .bashrc:\n"
printf ". ~/.bashrc && echo \$FTBENCH_HOME\n\n"

exit 0 
