#!/bin/bash

## Install ansible
sudo apt install ansible -y
sudo ansible-galaxy collection install kubernetes.core
