#!/bin/bash
#sudo ./30_Install_CSI_CNI_MetalLB.sh 3.26.1 4.4.0 0.13.10 172.16.0.8/29


# Check the number of arguments
##
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 CalicoVersion CsiNfsVersion MetallbVersion"
    exit 1
fi
##

CALICO_VERSION=$1
CSINFS_VERSION=$2
METALLB_VERSION=$3
METALLB_SUBNET=$4

echo -e "\033[32m Download Calico Manifest \033[0m"
##
wget -O calico.yaml https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml > /dev/null
##

echo -e "\033[32m Install Calico Manifest \033[0m"
##
kubectl apply -f calico.yaml
##

echo -e "\033[32m Download CSI NFS \033[0m"
##
wget -O install-driver.sh https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/v${CSINFS_VERSION}/deploy/install-driver.sh
chmod 0755 install-driver.sh
##

echo -e "\033[32m Install CSI NFS \033[0m"
##
./install-driver.sh
##

echo -e "\033[32m Create CSI NFS Storage Class \033[0m"
##
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: csi-nfs
provisioner: nfs.csi.k8s.io
parameters:
  server: 172.16.0.98
  share: /var/nfs/general/
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - nconnect=8
  - nfsvers=4.1
EOF
##

echo -e "\033[32m Install Metal Load Balancer \033[0m"
##
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml
##

echo -e "\033[32m Get No. of replicas to wait for \033[0m"
##
EXPECTED_REPLICAS=$(kubectl get rs -n metallb-system -o json | jq -r '.items[] | select(.metadata.name | startswith("controller")) | .spec.replicas')
##

echo -e "\033[32m Wait for MetalLB Replicas before executing config \033[0m"
##
RETRIES=50
while [[ $RETRIES -gt 0 ]]; do
    READY_REPLICAS=$(kubectl get rs -n metallb-system -o json | jq -r '.items[] | select(.metadata.name | startswith("controller")) | .status.readyReplicas')

    if [[ "$READY_REPLICAS" == "$EXPECTED_REPLICAS" ]]; then
        break
    fi
    echo -e "Waiting for MetalLB expected replicas (${EXPECTED_REPLICAS}) to equal ready replicas (${READY_REPLICAS})"
    sleep 10
    RETRIES=$((RETRIES-1))
done
echo "Status: ${READY_REPLICAS} replicas are ready"
##

echo -e "\033[32m Configuring MetalLB \033[0m"
##
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - ${METALLB_SUBNET}

---

apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
EOF
##
