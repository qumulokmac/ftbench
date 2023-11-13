# ftbench
Benchmarking framework for Video Editorial benchmarking in the Media/Entertainment industry

---
Qumulo ftbench is a framework designed performing storage benchmark testing for Media and Entertainment video editorial workflows.

> The tool leverages [frametest](https://support.dvsus.com/hc/en-us/articles/212925466-How-to-use-frametest), a longstanding tool used in the video editorial industry to determine storage adequacy for reading and writing video from storage. It is a basic 32-bit application, so there are additional compatibility drivers needed (See prerequisites below). For more information about frametest, see the Rohde & Schwarz knowledge base article, [here]([https://support.dvsus.com/hc/en-us/articles/212925466-How-to-use-frametest](https://support.dvsus.com/hc/en-us/articles/212925466-How-to-use-frametest)).

---
**Table of Contents**

1. [Initial Configuration](#initial-configuration)
2. [Prerequisites](#prerequisites)
3. [Requirements](#requirements)
4. [Steps to follow](#follow) 
   - [Step 1: Create the service account](#step1)
   - [Step 2: Clone this github repository](#step2)
   - [Step 3: Run the ftbench install.sh script](#step3)
   - [Step 4: Understanding $FTBENCH_HOME](#step4)
   - [Step 5: Configure ftbench](#step5)
   - [Step 6: Copy frametest to worker hosts](#step6)
   - [Step 7: Mount the NFS exports](#step7)
   - [Step 8: Configuring Job Definitions](#step8)
4. [Included utilities](#utilities)
5. [Running ftbench](#runningftbench)
6. [Output](#output)
7. [Analyzing the results](#analyzing)

<a id="initial-configuration"></a>
## Initial Configuration

This section explains the initial configuration of Qumulo ftbench.

<a id="prerequisites"></a>
### Prerequisites

Ftbench is a set of bash scripts, requiring **bash 4.1 or higher**. It has been tested on Alma Linux 8.7, Centos 8.5 and Ubuntu 20.04, but should work fine on current Linux based distros. It has been tested up to 1024 concurrent streams as of Nov 2023.

<a id="requirements"></a>
### Requirements
1. **Hard requirement**. For frametest to work, *you must install the following package* to enable cross-compilation of programs. See [this]( https://devicetests.com/understanding-gcc-multilib-ubuntu) Ubuntu article to learn more about cross-compilation.
   - Centos: `sudo yum install glibc.i686`
   - Ubuntu: `sudo apt-get install gcc-multilib`
1. A **single "Controller"** Linux host is required to manage jobs and distribute processes to the worker hosts for concurrent stream testing.
   - The controller host does not need much processing power, so a general purpose VM is fine.
   
1. **Four or more "Worker" Linux hosts** which will run the jobs dispatched from the controller host.
   - The worker hosts should be storage-optimized hosts with many CPU/vCPU's and sufficient RAM for the level of testing you wish to perform. 
   - One CPU core per stream is recommended.
   - _For example, if you will be running 512 streams for your max test, you will need 512 available CPU cores across all the worker hosts._
3. **Password-less SSH** needs to be configured on all hosts: from the controller host to each worker host at a minimum.
   - Here is an [article](https://www.redhat.com/sysadmin/passwordless-ssh) from redhat that can walk you through it.
   - **Net:net**, the service account user needs to be able to ssh from the control host to each worker host to launch the frametest jobs.
4. Additional packages:
   - *Centos:* 
   `sudo yum -y install git jq nfs-utils python3.9 pssh wget`
   
   - *Ubuntu:* 
   `sudo apt -y install git jq nfs-common python3.9 pssh wget`

> Optional packages that are useful for network validation and tuning:
   >  [iperf3]( https://iperf.fr/)
   >  [mtr](https://traceroute-online.com/mtr/)
   >  [nmap](https://nmap.org/)

**Note:** Since Qumulo is a scale-out architecture, you will want to have enough hosts to mount each of the nodes of the Qumulo cluster you are testing. 

<a id="follow"></a>
<a id="step1"></a>
### Step 1: Create the service account

You may want to create a seperate user account for running the ftbench service account. If so, create the account and use it to install the software and running jobs. 

   - The **UID must be the same** across all of the worker hosts.

Example command to add an account:

`sudo useradd -d /home/ftbench -u 1337 -c "ftbench service account" -s /bin/bash ftbench`

<a id="step2"></a>
### Step 2: Clone this github repository

```
cd /tmp
git clone https://github.com/qumulokmac/ftbench.git
cd /tmp/ftbench
```

<a id="step3"></a>
### Step 3: Run the ftbench install.sh script

Change directory into the git repository you cloned and run the install.sh script.

```
cd /tmp/ftbench
chmod 755 install.sh
bash ./install.sh

```
<a id="step4"></a>
### Step 4: Understanding \$FTBENCH_HOME

The install.sh script set \$FTBENCH_HOME for you, and added it to your .bashrc for persistence.

1. The \$FTBENCH_HOME directory contains the scripts, tools, config, output, and archive directories. 
2. The output and/or archive directories store logs for each job and the CSV files created.
   - Note: The output directory can grow quite large as it store logs and output from all worker hosts.
   - Plan for available capacity of **65MB per ftbench job**.
   - An ftbench job is a combination of codec, resolution, number of streams, number of worker hosts, etc. See the job definition section below.

      Eg: Testing for 20 codecs, with 3 different resolutions, and 8 different 'stream counts' results in 160 different job definitions. This would require ~10GB of capacity.
   
<a id="step5"></a>
### Step 5: Configure ftbench

- **workers.conf**: Add the names, fully qualified domain names (FQDN), or IP addresses for each worker host to the configuration file: $FTBENCH_HOME/config/workers.conf
  - Each entry must be resolvable by the control host.
  - _Note: Do not add the control host to the config as it would take on a worker role and be loaded down running jobs._

```
$ cat workers.conf
worker01.qumulo.net
worker02.qumulo.net
worker03.qumulo.net
worker04.qumulo.net
```

   - **REMINDER:** Ensure you have password-less SSH configured before running ftbench.sh with all of the defined worker hosts in the \$FTEST\_HOME/config/workers.conf file. 
   - This includes adding the public key to the authorized_keys file, otherwise ftbench will be prompted to accept the public key.
   - Here's a tip: 

```
cat ${HOME}/.ssh/id_rsa.pub >> ${HOME}/.ssh/authorized_keys
chmod 700 ${HOME}/.ssh
chmod 600 ${HOME}/.ssh/*
```

- **jobs.conf:** :Add the job definitions to the configuration file: `$FTBENCH_HOME/config/jobs.conf`
  - See the Job Definitions section for more details on how to configure each test.

#### Jobs Configuration file format 

`operation|framesize|numframes|numthreads|fps|zsize|numhosts|streams|codecname`

Example: 

```
$ cat jobs.conf
write|408|7200|3|24|0|1|1|h264HD
read|408|7200|3|24|408|1|1|h264HD
```

<a id="step6"></a>
### Step 6: Copy frametest to worker hosts

Now that you have configured the workers.conffile and installed pssh, you can copy the frametest executable to all worker hosts with the below commands.
 
**Run these two commands:**

```
pscp.pssh -h ${FTBENCH_HOME}/config/workers.conf /usr/local/bin/frametest /tmp

pssh -h ${FTBENCH_HOME}/config/workers.conf 'sudo cp -p /tmp/frametest /usr/local/bin/frametest'
```

<a id="step7"></a>
### Step 7: Mount the NFS exports

You can mount the NFS export with any optional parameters you want to test with, however the NFS export **must be mounted at `/mnt/ftbench`**.

**IMPORTANT**:

  - Ensure that the service account user can write to the mounted directory and create sub-directories!

Here is an example of mounting an NFS export and tests:

```
sudo mount -o tcp,vers=3,nconnect=16 qumulo01.qumulo.net:/ nfsexport01 /mnt/ftbench
sudo chown `whoami` /mnt/ftbench
mkdir -p /mnt/ftbench/test
touch /mnt/ftbench/test/hello.world
```

This can be performed **at scale** using parallel ssh (pssh):

```
pssh -h ${FTBENCH_HOME}/config/workers.conf 'sudo mkdir -p /mnt/ftbench'
pssh -h ${FTBENCH_HOME}/config/workers.conf 'sudo mount -o tcp,vers=3,nconnect=16 qumulo01.qumulo.net:/nfsexport01 /mnt/ftbench'
pssh -h ${FTBENCH_HOME}/config/workers.conf 'sudo chown `whoami` /mnt/ftbench'
pssh -h ${FTBENCH_HOME}/config/workers.conf 'mkdir -p /mnt/ftbench/test' touch /mnt/ftbench/test/hello.world
```

> Note: When testing qumulo file systems be sure that **each host has mounted a different qumulo node**, either by using the round-robin DNS configuration, static IP addresses, or unique FQDN's.

<a id="step8"></a>
### Step 8. Configuring Job Definitions
Each job is defined as combination of the following:

| Field | Description |
| --- | --- |
| framesize (KB) | Frame Size in KB |
| numframes | Number of frames to read or write (default = 1800) |
| numthreads | Number of threads for multithreading I/O |
| fps | FPS or Framerate |
| zsize | Specifies a custom 'size' for read or write test in KB. This should be set to match the framesize in most situations. |
| numworkers | Number of worker hosts to run the streams on |
| streams | Number of streams for this particular test |
| pattern | An identifier used for this test. No spaces. |

   - There is a [example config spreadsheet](https://github.com/qumulokmac/ftbench/blob/main/examples/example-frametest-sizing.xlsx) in the exampes directory to help you get started, but you will want to create your own based on your needs. 
   
   - **DO NOT** _use spaces, dashes, or any other whitespace in the data fields_. Keep it simple, as field level data validation hasn't been added yet. Garbage in, garbage out.

<a id="utilities"></a>
### Included utilities

There are several helper scripts in the `$FTBENCH_HOME\tools` directory:

1. **check-ft.sh**:
   - This script will check if frametest processes are still running on the workers
1. **ftbench-matrix.sh**:
   - This script will produce a CSV final report of all dropped frames for the read and write jobs for the tests submitted.
1. **ftbench-report.sh**:
   - This script will produce a CSV report with all of the read and write output for all submitted tests.
1. **pulldata.sh**:
   - This script pulls all of the data from the output directories on all worker hosts to the output directory on the controller host.
1. **reset.sh**:
   - This script will kill the currently running job ftbench process, and all of the frametest processes running on worker hosts. It will also archive the output in the archive folder on the controller host. Note: This is a **"emergency use only"** script!

<a id="runningftbench"></a>
### Running ftbench

Once you have defined your job definitions in the `${FTBENCH_HOME}/config/jobs.conf` file, execute the main script **`${FTBENCH_HOME}/scripts/ftbench`**. 

-   You can use the Linux `screen` command in case you are diconnected, or launch the script in the background with nohup, as in the example below: 

- `nohup ${FTBENCH_HOME}/scripts/ftbench.sh & > ${FTBENCH_HOME}/ftbench.out &`

You can monitor the ftbench output without concern of interuppting it using the Linux utility `tail`, command below: 

`tail -f ${FTBENCH_HOME}/ftbench.out `

<a id="output"></a>
### Output

The output files are named with a specific convention used with ftbench internally, especially when when reporting. The fields are separated with a dash '-', thus the do-not-use-dashes comment in the section above.

#### File naming convention:

DATE-RANDOM-framesize-numframes-numthreads-fps-zsize-numhosts-numstreams-streamindex-codecname-operation


Example: Field level translation for "ft-20231109181137-15501-703-7200-1-24-703-4-64-18-h264UHD_write.csv"

| **Field #** | **Key** | **Value** |
| --- | --- | --- |
| Field 1 | Date | Nov 9th, 2023, at 6:11:37PM GTC |
| Field 2 | Random | Used internally by ftbench as a unique identifier |
| Field 3 | Framesize | 703 |
| Field 4 | Number of frames | 7200 |
| Field 5 | Number of threads | 1 |
| Field 6 | FPS | 24 |
| Field 7 | Z-size | 703 |
| Field 8 | Number of workers | 4 |
| Field 9 | Number of streams | 64 |
| Field 10 | Stream index | Used internally in ftbench to keep track of each forked process |
| Field 11 | Codec | h264UHD |
| Field 12 | Operation | Write (This frametest test performed write operations) |


> The raw output from frametest is in CSV format, except for the header, with looks like:
> 
```
Date,09-Nov-2023
Time,18:41:39
Version,4.22
OS,Linux 4.18.0-348.7.1.el8_5.x86_64 #1 SMP Wed Dec 22 13:25:12 UTC 2021
Hostname,vdbench-slave
TestPath,"/mnt/ftbenchl32s/frametest-23864/48906319-c4d3-437c-ba0f-68100b673c0b"
Parameters," -w704 -n7200 -t1 -f24 -q24 "
FrameRate,23.98,fps
Bandwidth,16.49,MB/s
DroppedFrames,0
```

<a id="analyzing"></a>
### Analyzing the results

Once you get the data from ftbench it needs to be analyzed. Currently, this is being done by spreadsheet manipulation. If the tool continues to get traction it will be ported into a database and analyzed with tools such as [Microsoft's Power BI](https://powerbi.microsoft.com/).

Here is an example spreadsheet used to calculate the input variables for ftbench: 

There is a [example config spreadsheet](https://github.com/qumulokmac/ftbench/blob/main/examples/example-frametest-sizing.xlsx) in the exampes subdirectory.

---

Closing comments:

- YMWV
- If you would like to contribute to enhancements, reach out to [kmac@qumulo.com](mailto:kmac@qumulo.com). I am always looking for crowd-sourced helpers!
- There is not a MS Windows variant yet, but it wouldn't be too much of a lift to port it. Volunteers?
