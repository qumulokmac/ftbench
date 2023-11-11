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
4. [Step 1: Create the service account](#step1)
5. [Step 2: Clone this github repository](#step2)
6. [Step 3: Set up the environment](#step3)
7. [Step 4: Download and install frametest](#step4)
8. [Step 5: Install ftbench](#step5)
9. [Step 6: Configure ftbench](#step6)
10. [Step 7: Copy frametest to worker hosts](#step7)
11. [Step 8: Mount the NFS exports](#step8)
12. [Step 9. Configure the Job Definitions](#step9)
13. [Included utilities](#utilities)
14. [Running ftbench](#runningftbench)
15. [Output](#output)
16. [Analyzing the results](#analyzing)

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
1. A single "Controller" Linux host is required to manage jobs and distribute processes to the worker hosts for concurrent stream testing.
   - The controller host does not need much processing power, so a general purpose VM is fine.
   
1. Four or more "Worker" Linux hosts which will run the jobs dispatched from the controller host.
   - The worker hosts should be storage-optimized hosts with many CPU/vCPU's and sufficient RAM for the level of testing you wish to perform. 
   - One CPU core per stream is recommended.
   - For example, if you will be running 512 streams for your max test, you will need 512 available CPU cores across all the worker hosts.
```Note: Since Qumulo is a scale-out architecture, you will want to have enough hosts to mount each of the nodes of the Qumulo cluster you are testing. The tests will run on a single worker host, but that would not real-world streams from different clients.```
3. Password-less SSH needs to be configured on all of the hosts, from the controller host to each worker host at a minimum.
   - There are many ways to configure password-less SSH, each with their pros and cons, therefore the details for setting this up has been left to the reader.
   - If you are unfamiliar with this, use your favorite internet search engine and search for "configuring Linux ssh password-less ". You will find dozens of articles.
   - **Net:net**, the service account user needs to be able to ssh from the control host to each worker host to launch the frametest jobs.
4. Additional packages:
   - *Centos:* 
   `sudo yum -y install git jq nfs-utils python3.9 pssh wget`
   
   - *Ubuntu:* 
   `sudo apt -y install git jq nfs-utils python3.9 pssh wget`

Optional packages that are useful for network validation and tuning:
   >  - [iperf3]( https://iperf.fr/)
   >  - [mtr](https://traceroute-online.com/mtr/)
   >  - [nmap]([https://nmap.org/])

<a id="step1"></a>
### Step 1: Create the service account

Create a user to be used as the ftbench service account. This is the account you will be installing the software and running the jobs with. The UID needs to be the same across all of the hosts.

Example:

`sudo useradd -d /home/ftbench -u 1337 -c "ftbench service account" -s /bin/bash ftbench`

<a id="step2"></a>
### Step 2: Clone this github repository

`git clone https://github.com/qumulokmac/ftbench.git`

<a id="step3"></a>
### Step 3: Set up the environment

1. Set the environmental variable `$FTEST_HOME` to the install directory. For example, this command sets it to "`/home/qumulo`". 
`export FTEST_HOME=/home/qumulo`

1. This directory will store the scripts, tools, output, and archive directories. The output and/or archive directories store logs for each job and the CSV files created.

- Note: The output directory can grow quite large as it store logs and output from all worker hosts.
- Plan for available capacity of **65MB per ftbench job**.

    1. An ftbench job is a combination of codec, resolution, number of streams, number of worker hosts, etc. See the job definition section below.
    2. Eg: Testing for 20 codecs, with 3 different resolutions, and 8 different 'stream counts' results in 160 different job definitions. This would require ~10GB of capacity.
   
**Add the setting to the .bashrc so it is persistent.**

`echo 'export FTEST_HOME=/home/qumulo' >> ~/.bashrc`

<a id="step4"></a>
### Step 4: Download and install frametest

The frametest executable can be download manually in a browser, or you can use the following commands on the control host if it has network access. If you download manually, be sure to copy it to the `/usr/local/bin` directory with executable permissions.

```
cd /tmp
wget -P /tmp -q http://www.dvsus.com/gold/san/frametest/lin/frametest
chown 755 /tmp/frametest
sudo cp /tmp/frametest /usr/local/bin
```
<a id="step5"></a>
### Step 5: Install ftbench

Change directory into the git repository you cloned and run the install.sh script.

<a id="step6"></a>
### Step 6: Configure ftbench

- **workers.conf** : Add the names, fully qualified domain names (FQDN), or IP addresses for each worker host to the configuration file: $FTEST\_HOME/config/workers.conf
  - Each entry must be resolvable by the control host.
  - _Note: Do not add the control host to the config as it would take on a worker role and be loaded down running jobs._

- **tests.json:** Add the job definitions to the configuration file: $FTEST_HOME/config/jobs.conf
  - See the Job Definitions section for more details on how to configure each test.

Examples below:
```
[qumulo@ftb-controller config]$ head workers.conf
worker01.qumulo.net
worker02.qumulo.net
worker03.qumulo.net
worker04.qumulo.net
worker05.qumulo.net
worker06.qumulo.net
worker07.qumulo.net
worker08.qumulo.net
worker09.qumulo.net
worker10.qumulo.net
[qumulo@ftb-controller config]$ head -n20 tests.json
{
  "jobs": [
    {
      "framesize": "786",
      "numframes": "4",
      "fps": "1",
      "zsize": "24",
      "numhosts": "786",
      "streams": "128",
      "codecname": "ProResHQ422HD"
    },
    {
      "framesize": "3682",
      "numframes": "4",
      "fps": "1",
      "zsize": "24",
      "numhosts": "3682",
      "streams": "128",
      "codecname": "ProResHQ4228K"
    },
[qumulo@ftb-controller config]$
```

<a id="step7"></a>
### Step 7: Copy frametest to worker hosts

Now that you have configured the workers.conffile and installed pssh, copying the frametest executable to all worker hosts is simple. Run these two commands:

```
pscp.pssh -h ${FTEST_HOME}/config/hosts.conf /usr/local/bin/frametest /tmp

pssh -h ${FTEST_HOME}/config/hosts.conf 'sudo cp -p /tmp/frametest /usr/local/bin/frametest'
```

<a id="step8"></a>
### Step 8: Mount the NFS exports

You can mount the NFS export with whichever options you want to test with, however it needs to be mounted at `/mnt/ftbench`.

**IMPORTANT**:

  - Ensure that the service account user can write to the mounted directory and create sub-directories!

Here is an example of mounting an NFS export and tests:

```
sudo mount -o tcp,vers=3,nconnect=16 qumulo01.qumulo.net:/ nfsexport01 /mnt/ftbench
sudo chown `whoami` /mnt/ftbench
mkdir -p /mnt/ftbench/test
touch /mnt/ftbench/test/hello.world
```

This can also be performed **at scale** using pssh:

```
pssh -h ${FTEST_HOME}/config/hosts.conf 'sudo mkdir -p /mnt/ftbench'
pssh -h ${FTEST_HOME}/config/hosts.conf 'sudo mount -o tcp,vers=3,nconnect=16 qumulo01.qumulo.net:/nfsexport01 /mnt/ftbench'
pssh -h ${FTEST_HOME}/config/hosts.conf 'sudo chown `whoami` /mnt/ftbench'
pssh -h ${FTEST_HOME}/config/hosts.conf 'mkdir -p /mnt/ftbench/test' touch /mnt/ftbench/test/hello.world
```

> Note: When testing qumulo file systems be sure that **each host has mounted a different qumulo node**, either by using the round-robin DNS configuration, static IP addresses, or unique FQDN's.

<a id="step9"></a>
### Step 9. Configure the Job Definitions

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


Example input table:

**Insert pic here**

- There are example configuration files in the repository, but you will want to create your own based on your needs. Use the examples as reference.

**TIP:** Use a spreadsheet to come up with your specific formulas/values, and then export the fields to a CSV file. Then use the `jq` snippit below to convert the CSV to JSON. _Your welcome._

```JSON
jq -Rsn '
  { "jobs":
   [inputs
   | . / "\n"
   | (.[] | select(length > 0) | . / ",") as $input
   | { "framesize": $input[0],
       "numframes": $input[1],
       "fps": $input[2],
       "zsize": $input[3],
       "numhosts": $input[4],
       "numframes": $input[5],
       "streams": $input[6],
       "codecname": $input[7]
     }
     ]
   }
   ' < jobs.csv
```
- **DO NOT** _use spaces, dashes, or any other whitespace_ in the data fields. Keep it simple, as field level data validation hasn't been added yet. Garbage in, garbage out.

<a id="utilities"></a>
### Included utilities

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

Once you have defined your job definitions, execute the script `${FTEST_HOME}/scripts/ftbench`. You can use the Linux `screen` command in case you are diconnected, or launch the script in the background with nohup, as in the example below: 

`nohup ${FTEST_HOME}/scripts/ftbench.sh & > ${FTEST_HOME}/ftbench.out &`

You can monitor the ftbench output without concern of interuppting it using `tail` like below: 

`tail -f ${FTEST_HOME}/ftbench.out `

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

,file,open,io,close,queue
min,3.676,0.215,3.250,0.001,0
avg,25.897,19.845,6.048,0.004,0.4
max,263.373,219.821,175.775,0.160,8

num,start,open,io,close,frametime,queue
0,41.946,47.254,52.736,52.745,41.686,0
1,83.459,90.905,96.698,96.700,83.392,0

```
<a id="analyzing"></a>
### Analyzing the results

Once you get the data from ftbench it needs to be analyzed. Currently, this is being done by spreadsheet manipulation. If the tool continues to get traction it will be ported into a database and analyzed with tools such as [Microsoft's Power BI](https://powerbi.microsoft.com/).

---

Closing comments:

- YMWV
- If you would like to contribute to enhancements, reach out to [kmac@qumulo.com](mailto:kmac@qumulo.com). I am always looking for crowd-sourced helpers!
- There is not a MS Windows variant yet, but it wouldn't be too much of a lift to port it. Volunteers?
