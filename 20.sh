#!/bin/bash
#sudo ./20_kubeInit.sh 1.25.6

DIR_NAME=$(dirname "$0")

# echo -e "  " \033[0m"
# Initialize the cluster
echo -e "\033[32m Initializing Cluster on k8s version "${1}" \033[0m"
kubeadm_init_output=$(kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version $1 2>&1)

# Check for "kubeadm join" in the output and save to the appropriate file
if echo "$kubeadm_init_output" | grep -q "kubeadm join"; then
    echo -e " Kube Join command also written to "${DIR_NAME}/kube_join_command.txt" \033[0m"
    echo -e "stdout:\n$kubeadm_init_output\n" | tee ${DIR_NAME}/kube_join_command.txt
else
    echo -e "Initialization error:\n$kubeadm_init_output\n" 
    exit 1
fi


# Create .kube directory and admin kube config
if [ ! -f ${DIR_NAME}/kube_join_command.txt ]; then
	echo -e "Init Failed"
	exit 1
else
	echo ${DIR_NAME}/cluster_initialized.txt
fi

echo -e "\033[32m copying KubeConfig to kube and current users kube config "${1}" \033[0m"

mkdir -p /home/ubuntu/.kube
chown ubuntu:ubuntu /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chmod 0755 /home/ubuntu/.kube/config

mkdir -p /home/kube/.kube
chown kube:kube /home/kube/.kube
cp /etc/kubernetes/admin.conf /home/kube/.kube/config
chmod 0755 /home/kube/.kube/config

mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
