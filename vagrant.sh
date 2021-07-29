#!/bin/bash

# detect running environment
user=$USER

provision=/vagrant/Vagrantfile
if [ -e $provision ]
then
  echo "Vagrantfile found..."
  echo "Setting user to vagrant..."
  user=vagrant
fi

# This script to install Kubernetes will get executed after we have provisioned the box

echo "APT::Acquire::Retries \"3\";" > /etc/apt/apt.conf.d/80-retries
echo "Acquire::https::packages.cloud.google.com::Verify-Peer \"false\";" > /etc/apt/apt.conf

# Install kubernetes
apt-get update && apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl

# kubelet requires swap off
swapoff -a

# keep swap off after reboot
cp /etc/fstab /etc/fstab.bak
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
# sed -i '/ExecStart=/a Environment="KUBELET_EXTRA_ARGS=--cgroup-driver=cgroupfs"' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
cp /etc/systemd/system/kubelet.service.d/10-kubeadm.conf /etc/systemd/system/kubelet.service.d/10-kubeadm.conf.bak
sed -i '0,/ExecStart=/ s//Environment="KUBELET_EXTRA_ARGS=--cgroup-driver=cgroupfs"\n&/' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Get the IP address that VirtualBox has given this VM
IPADDR=`ifconfig eth1 | grep -i Mask | awk '{print $2}'| cut -f2 -d:`
echo This VM has IP address $IPADDR

# Set up Kubernetes
NODENAME=$(hostname -s)
# kubeadm init --apiserver-cert-extra-sans=$IPADDR --node-name $NODENAME
kubeadm init

if [ -e $provision ]
then
# Set up admin creds for the user
  echo Copying credentials to /home/user...
  sudo --user=$user mkdir -p /home/$user/.kube
  cp -i /etc/kubernetes/admin.conf /home/$user/.kube/config
  chown $(id -u $user):$(id -g $user) /home/$user/.kube/config
  # Writing the IP address to a file in the shared folder
  echo $IPADDR > /vagrant/ip-address.txt
fi

echo ">>>>>>>>> complete initial K8S provisioning <<<<<<<<<"
echo ""
echo "  Please execute provisioning.sh to complete the rest."
echo ""
echo ">>>>>>>>> complete initial K8S provisioning <<<<<<<<<"
