#!/bin/bash
#sudo ./10_instMaster.sh 1.25.6-00 "172.16.0.240 master1.aamiles.org" "172.16.0.241 worker1.aamiles.org"

# Check the number of arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <KUBE_VERSION> <HOST_ENTRY_1> <HOST_ENTRY_2> ..."
    exit 1
fi

KUBE_VERSION=$1

echo -e "\033[32m Setting up Hosts File  \033[0m"

shift
# Iterating over all the other parameters.
for host_entry in "$@"; do
    echo "$host_entry" | sudo tee -a /etc/hosts
done

#echo -e "\033[32m   \033[0m"

# Get the release codename
echo -e "\033[32m Capturing Ubuntu Release Name \033[0m"
release_name=$(lsb_release -c -s)

# Check if it's "jammy"
if [ "$release_name" == "jammy" ]; then
    IS_JAMMY=TRUE
else
    IS_JAMMY=FALSE
fi

echo -e "\033[32m Disable Auto Upgrades \033[0m"
##
cp /usr/share/unattended-upgrades/20auto-upgrades-disabled /etc/apt/apt.conf.d/20auto-upgrades
##

echo -e "\033[32m Disable Swap  \033[0m"
##swapoff -a
sed -i '/^\\([^#].*?\\sswap\\s\\+sw\\s\\+.*)$/s/^/# /' /etc/fstab
##

echo -e "\033[32m Setup Kube User  \033[0m"
##
sudo useradd -m -p '$6$5dqHns.IJ$FpCGaCbY9ySKo0mh.ydPo57A2kgUdjv3U8IUZXnfw8DNGQw4g0hO27XpMSIhwHvcO8QdEVucnlY9tYyTEg3CN/' -s /bin/bash -G sudo kube
##

echo -e "\033[32m Adding 'ubuntu' to sudoers \033[0m"
##
echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/ubuntu
chmod 0440 /etc/sudoers.d/ubuntu
##

echo -e "\033[32m Download Kubernetes & Docker APT keys  \033[0m"
##
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
curl -s https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository -y -n "deb http://apt.kubernetes.io/ kubernetes-xenial main"
add-apt-repository -y -n "deb https://download.docker.com/linux/ubuntu focal stable"
##

echo -e "Waiting for APT Lock to be available"
##
while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 ; do
    echo "Waiting for other software managers to finish..."
    sleep 1
done
##

echo -e "\033[32m Executing APT Update  \033[0m"
##
apt update
##

echo -e "\033[32m Installing APT packages Containerd.io, Kubelet, Kubeadm etc \033[0m"
##
apt install -y apt-transport-https \
 curl gnupg2 \
 software-properties-common \
 ca-certificates \
 containerd.io \
 nfs-common \
 jq \
 wget \
 kubelet=${KUBE_VERSION}-00 \
 kubeadm=${KUBE_VERSION}-00 \
 kubectl=${KUBE_VERSION}-00
##

echo -e "\033[32m Waiting for Containerd to start \033[0m"
##
for i in {1..10}; do
    containerd --version && break || sleep 5
done
##


echo -e "\033[32m IF we are Jammy, setup for CGroupV2  \033[0m"
##
if [ $IS_JAMMY ]; then
    containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
    sed -i 's/SystemdCgroup \= false/SystemdCgroup = true/' /etc/containerd/config.toml
    systemctl restart containerd
    systemctl enable containerd
fi
##

echo -e "\033[32m Setup ipv4 forwarding  \033[0m"
##
cat <<EOF > /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
##

echo -e "\033[32m Set and load Containerd overlay and br_netfilter modules then restart systemd  \033[0m"
##
cat <<EOF > /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay > /dev/null
modprobe br_netfilter > /dev/null
sysctl --system 2>&1
##
echo -e "\033[32m Done 10.sh, Exiting... \033[0m"
