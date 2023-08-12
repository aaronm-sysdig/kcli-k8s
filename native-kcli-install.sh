#!/bin/bash

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

#More like constants
BASE_OS=ubuntu2204
VM_MASTER_PREFIX="${3}-master"
VM_WORKER_PREFIX="${3}-worker"
MASTER_PREFIX="master"
WORKER_PREFIX="worker"
MASTER_IP="$1"0
WORKER_IP_BASE="$1"
CLUSTER_NAME="$3"
KUBERNETES_ADMIN_USER="$4"

clear

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
  # Display help screen when no parameters are specified
  clear
  echo "Usage: $0 <Subnet Range to use> <Number of Hosts> <Cluster Name> <Kubernetes Admin Username>"
  echo "I.E $0 172.16.21 3 aamiles-cluster1 aamiles-cluster1-admin"
  echo "    Will give you a 3 host cluster (1 master and 2 workers) called aamiles-cluster1-master-1 with IP's of 172.16.0.210, 211 and 212 and cluster-admin of aamiles-cluster1-admin"
  echo ""
  exit 1
fi

if [ ! -f "${HOME}/.ssh/id_rsa" ]; then
  echo "No SSH keys found in ${HOME}/.ssh/id_rsa, please create with 'ssh-keygen -t rsa -b 4096' first"
  exit 1
fi

# Function to check if a given input is a number
is_number() {
  if echo "$1" | grep -qE '^[+-]?[0-9]+([.][0-9]+)?$'; then
    return 0 # True, it's a number
  else
    return 1 # False, it's not a number
  fi
}

# Check if both parameters are numbers
if ! is_number "$2"; then
  echo "Error: parameter must be a number."
  exit 1
fi

#Create Ansible Inventory file

# Initialize the file
echo "[kube_masters]" > hosts
echo "${MASTER_PREFIX}1.${CLUSTER_NAME}.local ansible_host=${MASTER_IP}" >> hosts

echo "" >> hosts
echo "[kube_nodes]" >> hosts

# Create entries for each worker
for ((i=1;i<$2;i++)); do
  echo "${WORKER_PREFIX}${i}.${CLUSTER_NAME}.local ansible_host=${1}${i}" >> hosts
done

echo "" >> hosts
echo "[ubuntu:children]" >> hosts
echo "kube_masters" >> hosts
echo "kube_nodes" >> hosts

rm ./kube-config
rm ./kube-config.ok

#Create Master Node
# Perform the ssh-keygen operation
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "$1"0 -q
kcli delete vm ${VM_MASTER_PREFIX}1 -y
echo kcli create vm -i ${BASE_OS} -P numcpus=${VM_MASTER_CPUS} -P memory=${VM_MASTER_MEMORY} -P disks=[${VM_MASTER_DISK_SIZE}] -P nets='[{"name":"br0","ip":"'"$1"'0","netmask":"24","gateway":"172.16.0.1","dns":"172.16.0.1,8.8.8.8"}]' ${VM_MASTER_PREFIX}1
kcli create vm -i ${BASE_OS} -P numcpus=${VM_MASTER_CPUS} -P memory=${VM_MASTER_MEMORY} -P disks=[${VM_MASTER_DISK_SIZE}] -P nets='[{"name":"br0","ip":"'"$1"'0","netmask":"24","gateway":"172.16.0.1","dns":"172.16.0.1,8.8.8.8"}]' ${VM_MASTER_PREFIX}1

#Create worker nodes
# Loop from 0 to parameter-1
for ((i=1;i<$2;i++)); do
   # Perform the ssh-keygen operation
   ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "$1$i" -q
   kcli delete vm ${VM_WORKER_PREFIX}"$i" -y
   echo kcli create vm -i ${BASE_OS} -P numcpus=${VM_WORKER_CPUS} -P memory=${VM_WORKER_MEMORY} -P disks=[${VM_WORKER_DISK_SIZE}] -P nets='[{"name":"br0","ip":"'"$1"''"$i"'","netmask":"24","gateway":"172.16.0.1","dns":"172.16.0.1,8.8.8.8"}]' ${VM_WORKER_PREFIX}"$i"
   kcli create vm -i ${BASE_OS} -P numcpus=${VM_WORKER_CPUS} -P memory=${VM_WORKER_MEMORY} -P disks=[${VM_WORKER_DISK_SIZE}] -P nets='[{"name":"br0","ip":"'"$1"''"$i"'","netmask":"24","gateway":"172.16.0.1","dns":"172.16.0.1,8.8.8.8"}]' ${VM_WORKER_PREFIX}"$i"
   WORKER_HOSTS+=" \"$1$i ${VM_WORKER_PREFIX}$i.aamiles.org\""
done

for ((i=0;i<$2;i++)); do
  echo "Waiting for SSH to start on: "$1$i"" 
  until ssh -o ConnectTimeout=2 -o BatchMode=yes -o StrictHostKeyChecking=no ubuntu@"$1$i" true &>/dev/null; do echo "  SSH Failed to "$1$i".  Retrying in 1 second"; sleep 1; done
done


# Send and execute to Master
scp -o StrictHostKeyChecking=no ./10.sh ubuntu@${MASTER_IP}:~
scp -o StrictHostKeyChecking=no ./20.sh ubuntu@${MASTER_IP}:~
scp -o StrictHostKeyChecking=no ./30.sh ubuntu@${MASTER_IP}:~

ssh -t ubuntu@${MASTER_IP} "chmod +x \${HOME}/10.sh && sudo \${HOME}/10.sh \"$5\" \"$MASTER_IP ${VM_MASTER_PREFIX}1.aamiles.org\"$WORKER_HOSTS"

OUTPUT_20=$(ssh ubuntu@${MASTER_IP} "chmod +x \${HOME}/20.sh && sudo \${HOME}/20.sh \"$5\"" | tee /dev/tty)
JOIN_COMMAND=$(echo "${OUTPUT_20}" | grep -A 1 "kubeadm join" | tr -d '\\\n\t' | sed 's/  //g')
echo "JoinCommand = "${JOIN_COMMAND}

#Execute 10 on Worker Nodes
for ((i=1;i<$2;i++)); do
   echo -e "\033[32m Bootstrapping Worker Node ${WORKER_IP_BASE}${i} \033[0m"
   scp -o StrictHostKeyChecking=no ./10.sh ubuntu@${WORKER_IP_BASE}${i}:~
   ssh -t ubuntu@${WORKER_IP_BASE}${i} "chmod +x \${HOME}/10.sh && sudo \${HOME}/10.sh \"$5\" \"$MASTER_IP ${VM_MASTER_PREFIX}1.aamiles.org\"$WORKER_HOSTS"
   ssh -t ubuntu@${WORKER_IP_BASE}${i} "sudo ${JOIN_COMMAND}"
done

echo "Executing 30 on Master - CNI, NFS & MetalLB"
ssh ubuntu@${MASTER_IP} "chmod +x \${HOME}/30.sh && sudo \${HOME}/30.sh \"${CALICO_VERSION}\" \"${CSINFS_VERSION}\" \"${METALLB_VERSION}\" \"${METALLB_SUBNET}\""
