#!/bin/bash
sudo apt update
sudo apt -y install xfsprogs
sudo mkfs -t xfs /dev/nvme1n1
sudo mkdir -p /vol
sudo echo '/dev/nvme1n1 /vol xfs defaults 0 0' >> /etc/fstab
sudo mount -a