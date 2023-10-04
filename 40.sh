#!/bin/bash

#Output Kube Config
CONFIG_LOCATION=/home/ubuntu/.kube/config
KUBERNETES_ADMIN_USER=$1
CLUSTER_NAME=$2

if [ -f ${CONFIG_LOCATION} ]; then
  echo "Installation Complete - Here is your Kube Config file (hint: use VI to paste to ensure CR/LF's are right)"
  echo
  cat ${CONFIG_LOCATION} | sed 's/\\n/\n/g' | sed "s/kubernetes-admin/${KUBERNETES_ADMIN_USER}/g" | sed "s/cluster: kubernetes/cluster: ${CLUSTER_NAME}/g" | sed "s/name: kubernetes/name: ${CLUSTER_NAME}/g" | sed "s/\@kubernetes/\@${CLUSTER_NAME}/g" > kube-config.ok
  cat kube-config.ok
  echo
  echo "DONE!"
  exit 0
else
  echo "Installation failed... refer above (hopefully)"
  exit 1
fi
