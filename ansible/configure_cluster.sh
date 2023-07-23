#!/bin/bash

# run ansible playbook
envName="$1"
sshUser="$(whoami)"
sudo ansible-playbook -i ./ansible/inventories/k8s_"${envName}".ini -u "${sshUser}" ./ansible/configure_cluster.yml --connection=local
