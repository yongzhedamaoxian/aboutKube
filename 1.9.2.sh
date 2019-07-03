#!/bin/bash

#以下命令在root身份下运行
#KUBERNETES_VERSION用于配置集群及kubelet kubeadm kubectl版本

KUBERNETES_VERSIONS=1.9.2



VERSIONS=${KUBERNETES_VERSIONS}*

systemctl stop firewalld
systemctl disable firewalld
swapoff -a

setenforce 0

sed -i 's/download_updates = yes/download_updates = no/' /etc/yum/yum-cron.conf

sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

#校验 grep download_updates /etc/yum/yum-cron.conf
#校验 grep SELINUX=disabled /etc/selinux/config


#参考网址 https://www.cnblogs.com/zejin2008/p/7102485.html
modprobe br_netfilter

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl -p /etc/sysctl.d/k8s.conf

#安装docker
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

##yum list docker-ce --showduplicates | sort -r 选择合适版本

yum install -y --setopt=obsoletes=0 \
  docker-ce-17.03.2.ce-1.el7.centos \
  docker-ce-selinux-17.03.2.ce-1.el7.centos

systemctl start docker
systemctl enable docker

iptables -P FORWARD ACCEPT



#设置yum拉取包地址
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF



#安装kubelet 会安装cni以及socat依赖，等同于 yum install -y kubernetes-cni-0.6.0.x86_64 socat-1.7.3.2-2.el7.x86_64
yum install -y kubectl-${VERSIONS}
yum install -y kubelet-${VERSIONS}
yum install -y kubeadm-${VERSIONS}


#设置kubelet驱动与docker保持一致
sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl daemon-reload
systemctl start kubelet
systemctl enable kubelet

kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=${KUBERNETES_VERSIONS}
####kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version=1.9.2


#export KUBECONFIG=/etc/kubernetes/admin.conf


###to start using your cluster, you need to run the following as a regular user:

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#sudo chown $(id -u):$(id -g) $HOME/.kube/config
###You should now deploy a pod network to the cluster.
#Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
#  https://kubernetes.io/docs/concepts/cluster-administration/addons/
#Then you can join any number of worker nodes by running the following on each as root:

#kubeadm join --token 2bbcd1.6b21cda4a53b183c 10.128.0.52:6443 --discovery-token-ca-cert-hash sha256:71e21c75b126affaa2af9b31a59e54b53f35acce043a0addbcd9918bd45fae1e
###




#安装网络插件

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml


#组件版本
#kubeadm 1.9.0-00
#kubelet 1.9.0-00
#kubernetes-cni 0.6.0-00


kubectl taint nodes --all node-role.kubernetes.io/master-