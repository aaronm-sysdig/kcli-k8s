# kcli-k8s
## Introduction
Okay okay, I know there are 50 million different ways to do this but here is my take.  Using KCLI to creat libvirt VM's we can bootstrap a k8s cluster relatively quickly and painlessly.

## Installation
I will come back and fill this out with how to install KCLI (as I dont remember how I did it, I need to re-do it so as to document it

## Build
This is primarily based around `native-kcli-install.sh` which takes a number of parameters to create your domain

Example:

Usage:`./native-kcli-install.sh <Base Subnet> <Hosts> <K8s Cluster Name> <K8s Cluster Admin Username> <Kubernetes Version>`

Eg: `./native-kcli-install.sh 172.16.0.24 2 aamiles-cluster2204 aamiles-cluster2204-admin 1.25.6`

Lets break down the parameters from the example

| Parameter | Description |
|---|---|
| Base Subnet | Prefix for the subnet to use.  For example, 172.16.0.24 is going to create hosts in the 172.16.0.24x subnet.  I.E If you have 5 hosts (1 master and 4 workers) then you will have 172.16.0.240, 172.16.0.241, 172.16.0.242, 172.16.0.243 ad 172.16.0.244 | 
| Hosts | The number of hosts you wish to have (including the master).  So a value of 3 is 1 master and 2 worker nodes |
| K8s Cluster Name | As you suspect, the name of the cluster as specified in the kube config file | 
| K8s Cluster Admin Username | Again, pretty self explanatory.  The name of the k8s admin user to be created in the kube config file |
| Kubernetes Version | The K8s version to use |

## Scripts and files

| Script | Master/Worker | Description |
| --- | --- | --- |
| native-kcli-install.sh | Host | Main script.  Configures the worker scripts below and generally handles execution.  Has various configurations that can be customised |
| 10.sh | Master & Worker | This is the main node bootstrap script.  Used to configue the hosts file, user creation and APT package installation along with various linux configurations to support k8s (Containerd customisations for example |
| 20.sh | Master | Cluster bootstrapping for the master node.  Brings up the master ndoe |
| 30.sh | Master | Ancillary cluster configuration on the master.  Installs the CNI (Calico) CSI NFS and MeetalLB |
| 40.sh | Worker | Worker bootstrap.  Joins node to the cluster |

## native-kcli-install.sh Script Customisations
Since this is KCLI (libvirt) based, we can customise the type of Vm's we are using.  If you look at the top of the script you will see

```
# VM Variables to change if you want
VM_MASTER_CPUS=8
VM_MASTER_MEMORY=8192
VM_WORKER_CPUS=12
VM_WORKER_MEMORY=16384
VM_MASTER_DISK_SIZE=50 # GB
VM_WORKER_DISK_SIZE=200 #GB

# Versions to Install
KUBERNETES_VERSION="1.25.6"
CALICO_VERSION="3.26.1"
CSINFS_VERSION="4.4.0"
METALLB_VERSION="0.13.10"
METALLB_SUBNET="172.16.0.8/29"
```

These can be customised as you see fit.  #DO NOT# change the variable names but you can change the CPU, RAM and Disk requirements as you see fit.

Also versions can be changed as you find appropriate.  The ones listed here are ones that are known to work.  Change and test as your own risk of course.
