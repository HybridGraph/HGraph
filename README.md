**News!!!**   
**[10/30/2019]** A new paper is accepted by IEEE TKDE!!!
**[12/10/2018]** We change the project name from **HybridGraph** to **HGraph** for short!!!  
**[11/20/2018]** Priority scheduling for `BPull` is now available.   
**[10/20/2018]** More example graph algorithms are packaged.   
**[09/09/2018]** A general switching framework is added.  
**[05/11/2017]** Lightweight fault-tolerance is added.  
**[04/05/2017]** Some engineering optimizations are added for better performance.  
**[02/17/2017]** Some APIs are changed.  
**[12/25/2016]** Code cleanup.  
**[05/15/2016]** HybridGraph is online.  

# HGraph
HGraph(HybridGraph) is a Pregel-like system which merges Pulling/Pushing for I/O-Efficient distributed and iterative graph computing.

## 1. Introduction
Billion-scale graphs are rapidly growing in size in many applications. That has been driving much of the research on enhancing the performance of distributed graph systems, including graph partitioning, network communication, and the convergence. `HGraph` focuses on performing graph analysis on a cluster I/O-efficiently, since the memory resource of a given computer cluster can be easily exhausted. 
Specially, HGraph employs a `hybrid` solution to support switching between push and pull adaptively to obtain optimal performance in different scenarios. 

The HGraph project started at Northeastern University (China) in 2011. HGraph is a Java framework implemented on top of Apache Hama 0.2.0-incubating. Features of HGraph are listed as below.   

* ___Block-centric pull mechanism (BPull):___ I/O accesses are shifted from receiver sides where messages are written/read by Push to sender sides where graph data are read by Pull. The cost of random reads regarding vertices in existing pull-based approaches is considerable. Thus, a novel block-centric pull technique is used to optimize the I/O-efficiency, as well as reducing the communication cost caused by sending pull requests.  
* ___VE-BLOCK storage:___ A disk-resident block-centric graph structure is designed for efficient data accesses in `BPull`. Graph data are separated into vertices and edges. Vertices are divided into several `VBlocks`. Accordingly, edges are partitioned into multiple `EBlocks`. Messages are pulled in `VBlocks`.    
* ___Hybrid engine:___ By analyzing behaviors of different algorithms, two seamless switching mechanisms as well as prominent performance prediction methods are proposed to guarantee the efficiency when switching between `Push` and `BPull`.   
* ___Lightweight fault-tolerance:___ By utilizing the features of `BPull` and the swiching mechanism, a new fault-tolerant framework is proposed to preform an efficient confined recovery without logging messages. It strikes a good balance between recovery efficiency and failure-free performance.  
* ___Priority scheduling:___ When using `BPull`, users can specify the parallelism of pull-responding to limit the resource consumption. HGraph can smartly schedule the responding order to minimize the responding time.   
* ___Algorithms library:___ PageRank, Shortest Path, Connected Components, Label Propagation, Maximal Independent Sets, and Bipartite Matching.    

## 2. Quick Start
This section describes how to configurate, compile and then deploy HGraph on a cluster consisting of three physical machines running Red Hat Enterprise Linux 6.4 32/64 bit (one master and two slaves/workers, called `master`, `slave1`, and `slave2`). Before that, Apache Hadoop should be installed on the cluster, which is beyond the scope of this document. 

### 2.1 Requirements
* Apache hadoop-0.20.2 (distributed storage service)  
* Sun Java JDK 1.6.x or higher version  
Without loss of generality, suppose that HGraph is installed in `~/HGraph` and Java is installed in `/usr/java/jdk1.6.0_23`.

### 2.2 Deploying HGraph   
#### downloading files on `master`  
`cd ~/`  
`git clone https://github.com/HybridGraph/HGraph.git`  
`chmod 777 -R HGraph/`

#### configuration on `master`  
First, edit `/etc/profile` by typing `sudo vi /etc/profile` and then add the following information:  
`export HGraph_HOME=~/HGraph`   
`export HGraph_CONF_DIR=$HGraph_HOME/conf`  
`export PATH=$PATH:$HGraph_HOME/bin`  
After that, type `source /etc/profile` in the command line to make changes take effect.  

Second, edit configuration files in `HGraph_HOME/conf` as follows:  
* __termite-env.sh:__ setting up the Java path.  
`export JAVA_HOME=/usr/java/jdk1.6.0_23`  
* __termite-site.xml:__ configurating the HGraph engine.  
The details are shown in [termite-site.xml](https://github.com/HybridGraph/HGraph/blob/master/conf/termite-site.xml).  
In particular, our current implementation uses the read/write throughput of disk reported by the disk benchmarking tool [fio-2.0.13](http://pkgs.fedoraproject.org/repo/pkgs/fio/fio-2.0.13.tar.gz/), and the network throughput reported by the network benchmarking tool [iperf-2.0.5](http://pkgs.fedoraproject.org/repo/pkgs/iperf/iperf-2.0.5.tar.gz/).  
1) random read/write  
`fio -filename=/tmp/data -direct=1 -iodepth 1 -thread -rw=randrw -rwmixread=50 -ioengine=psync -bs=16k -size=10G -numjobs=30 -runtime=360 -group_reporting -name=test`  
2) sequential read/write  
`fio -filename=/tmp/data -direct=1 -iodepth 1 -thread -rw=rw -rwmixread=50 -ioengine=psync -bs=16k -size=10G -numjobs=30 -runtime=360 -group_reporting -name=test`  
3) network  
server: `iperf -s -f M -w 48K`  
client: `iperf -c hadoop03 -f M -w 48K`  
* __workers:__ settting up workers of HGraph.  
`slave1`  
`slave2`  

#### deploying  
Copy configurated files on `master` to `slave1` and `slave2`.  
`scp -r ~/HGraph slave1:.`  
`scp -r ~/HGraph slave2:.`  

### 2.3 Starting HGraph  
Type the following commands on `master` to start HGraph.  
* __starting HDFS:__  
`start-dfs.sh`  
* __starting HGraph after NameNode has left safemode:__  
`start-termite.sh`  
* __stopping HGraph:__  
`stop-termite.sh`  

### 2.4 Running a Single Source Shortest Path (SSSP) job on `master`  
First, create an input file under input/random_graph on HDFS. Input file should be in format of:  
`source_vertex_id \t target_vertex_id_1:target_vertex_id_2:...`  
An example is given in [random_graph](https://github.com/HybridGraph/dataset/blob/master/random_graph). You can download it and put it onto your HDFS:  
`hadoop dfs -mkdir input`  
`hadoop dfs -put random_graph input/`  
Currently, HGraph uses Range (a simple variant of [Range](https://apache.googlesource.com/giraph/+/old-move-to-tlp/src/main/java/org/apache/giraph/graph/partition/RangePartitionerFactory.java) used in Giraph) to partition input graph, in order to preserve the locality of raw graph. As a negative result of that, vertex ids must be numbered consecutively.  

Second, submit the SSSP job with different models for the example graph [random_graph](https://github.com/HybridGraph/dataset/blob/master/random_graph):  
* __SSSP (using b-pull):__  
`termite jar $HGraph_HOME/termite-examples-0.1.jar sssp.pull input output 2 50 100000 5 10000 2`  
About arguments:  
[1] input directory on HDFS  
[2] output directory on HDFS  
[3] the number of child processes (tasks)  
[4] the maximum number of supersteps  
[5] the total number of vertices  
[6] the number of VBlocks per task  
[7] the sending threshold  
[8] the source vertex id  
* __SSSP (using hybrid):__  
`termite jar $HGraph_HOME/termite-examples-0.1.jar sssp.hybrid input output 2 50 100000 5 10000 10000 10000 2 2`  
About arguments:  
[1] input directory on HDFS  
[2] output directory on HDFS  
[3] the number of child processes (tasks)  
[4] the maximum number of supersteps  
[5] the total number of vertices  
[6] the number of VBlocks per task  
[7] the sending threshold used by b-pull  
[8] the sending threshold used by push  
[9] the receiving buffer size per task used by push  
[10] starting style: 1--push, 2--b-pull  
[11] the source vertex id  

HGraph manages graph data on disk as default. Users can tell HGraph to keep graph data in memory through `BSPJob.setGraphDataOnDisk(false)`. Currently, the memory version only works for `BPull`. Please type `termite jar $HGraph_HOME/termite-examples-0.1.jar` to list all example algorithms. A chosen algorithm will print usage help when no  arguments is given.  

## 3  Building HGraph with Apache Ant  
Users can import source code into Eclipse as an existing Java project to modify the core engine of HGraph, and then build your  modified version. Before building, you should install Apache Ant 1.7.1 or higher version on your `master`. Suppose the modified version is located in `~/source/HGraph`.  You can build it using `~/source/HGraph/build.xml` as follows:  
`cd ~/source/HGraph`  
`ant`  
Notice that you can build a specified part of HGraph as follows:  
1) build the core engine  
`ant core.jar`  
2) build examples  
`ant examples.jar`   

By default, all parts will be built, and you can find `termite-core-0.1.jar` and `termite-examples-0.1.jar` in `~/source/HGraph/build` after a successful building. Finally, use the new `termite-core-0.1.jar` to replace the old one in `$HGraph_HOME` on the cluster (i.e., `master`, `slave1`, and `slave2`). At anytime, you should guarantee that the  `termite-core-xx.jar` file is unique in `$HGraph_HOME`. Otherwise, the starting script described in Section 2.3 may use a wrong file to start the HGraph engine.  

## 4. Programming Guide
HGraph includes some simple graph algorithms to show the usage of its APIs. These algorithms are contained in the `src/examples/hybrid/examples` package and have been packaged into the `termite-examples-0.1.jar` file. Users can implement their own algorithms by learning these examples. After that, as described in Section 3 and Section 2.4, you can build your own algorithm can then run it.  

## 6. Publications
* Zhigang Wang, Yu Gu*, Yubin Bao, Ge Yu, Jeffrey Xu Yu, Zhiqiang Wei*. [HGraph: I/O-efficient Distributed and Iterative Graph Computing by Hybrid Pushing/Pulling](https://ieeexplore.ieee.org/document/8890918), IEEE TKDE, 2019, accepted (extended version of SIGMOD'16) 

* Zhigang Wang, Lixin Gao, Yu Gu, Yubin Bao, Ge Yu. [A Fault-Tolerant Framework for Asynchronous Iterative Computations in Cloud Environments](https://ieeexplore.ieee.org/document/8300647), IEEE TPDS 2018 (extended version of SoCC'16). 

* Zhigang Wang, Lixin Gao, Yu Gu, Yubin Bao, Ge Yu. [FSP: towards flexible synchronous parallel framework for expectation-maximization based algorithms on cloud](https://dl.acm.org/citation.cfm?id=3128612), ACM SoCC 2017.

* Zhigang Wang, Yu Gu, Yubin Bao, Ge Yu, Lixin Gao. [An I/O-efficient and Adaptive Fault-tolerant Framework for Distributed Graph Computations](http://link.springer.com/article/10.1007/s10619-017-7192-2). Distributed and Parallel Databases 2017.  

* Zhigang Wang, Lixin Gao, Yu Gu, Yubin Bao, Ge Yu. [A Fault-Tolerant Framework for Asynchronous Iterative Computations in Cloud Environments](http://dl.acm.org/citation.cfm?id=2987552), ACM SoCC 2016. 

* Zhigang Wang, Yu Gu, Yubin Bao, Ge Yu, Jeffrey Xu Yu. [Hybrid Pulling/Pushing for I/O-Efficient Distributed and Iterative Graph Computing](http://dl.acm.org/citation.cfm?id=2882938). ACM SIGMOD 2016.   


## 7. Contact  
If you encounter any problem with HGraph, please feel free to contact wangzhigang@ouc.edu.cn.

