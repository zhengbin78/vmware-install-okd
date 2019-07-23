#!/bin/bash

export INTERACTIVE=${INTERACTIVE:="true"}
export PVS=${INTERACTIVE:="true"}
#警告:只有公有云主机才可以这么干.私有主机需要手动输入IP地址,建议固定虚拟机IP.
export USERNAME=${USERNAME:="$(whoami)"}
export PASSWORD=${PASSWORD:=password}
export IP=${IP:="$(ip route get 114.114.114.114 | awk '{print $NF; exit}')"}
export DOMAIN="${IP}.nip.io" 
# export DOMAIN=${DOMAIN:="$(curl -s ipinfo.io/ip).nip.io"}
export API_PORT=${API_PORT:="8443"}


## 互动模式设定值.
if [ "$INTERACTIVE" = "true" ]; then
	read -rp "Domain to use: ($DOMAIN): " choice;
	if [ "$choice" != "" ] ; then
		export DOMAIN="$choice";
	fi

	read -rp "Username: ($USERNAME): " choice;
	if [ "$choice" != "" ] ; then
		export USERNAME="$choice";
	fi

	read -rp "Password: ($PASSWORD): " choice;
	if [ "$choice" != "" ] ; then
		export PASSWORD="$choice";
	fi

	read -rp "IP: ($IP): " choice;
	if [ "$choice" != "" ] ; then
		export IP="$choice";
	fi

	read -rp "API Port: ($API_PORT): " choice;
	if [ "$choice" != "" ] ; then
		export API_PORT="$choice";
	fi 


fi

echo "******"
echo "* Your domain is $DOMAIN "
echo "* Your IP is $IP "
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "* OpenShift version: $VERSION "
echo "******"



sed -i -e "s/mirrorlist/#mirrorlist/g" /etc/yum.repos.d/CentOS-Base.repo
sed -i -e "s/#baseurl/baseurl/g" /etc/yum.repos.d/CentOS-Base.repo
sed -i -e "s/mirror.centos.org/mirrors.163.com/g" /etc/yum.repos.d/CentOS-Base.repo


yum clean all
yum install -y lrzsz telnet wget bash-completion net-tools httpd-tools java-1.8.0-openjdk-headless lsof zip unzip bind-utils yum-utils  bridge-utils pyOpenSSL kexec-tools sos psacct   docker   python-passlib 

# Disable the EPEL repository globally so that is not accidentally used during later steps of the installation
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo

systemctl | grep "NetworkManager.*running" 
if [ $? -eq 1 ]; then
	systemctl start NetworkManager
	systemctl enable NetworkManager
fi

# install the packages for Ansible
curl -o ansible-2.6.16-1.el7.ans.noarch.rpm https://releases.ansible.com/ansible/rpm/release/epel-7-x86_64/ansible-2.6.16-1.el7.ans.noarch.rpm
yum -y --enablerepo=epel install ansible-2.6.16-1.el7.ans.noarch.rpm

cd ~
wget https://github.com/openshift/openshift-ansible/archive/openshift-ansible-3.11.115-1.tar.gz
tar -xzf openshift-ansible-3.11.115-1.tar.gz
mv  openshift-ansible-openshift-ansible-3.11.115-1 openshift-ansible
sed -i 's/mirror.centos.org/mirrors.163.com/g' ~/openshift-ansible/roles/openshift_repos/templates/CentOS-OpenShift-Origin311.repo.j2
sed -i 's/mirror.centos.org/mirrors.163.com/g' ~/openshift-ansible/roles/openshift_repos/templates/CentOS-OpenShift-Origin.repo.j2


hostnamectl    set-hostname okd
export HOSTNAME="okd"

cat <<EOD > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
${IP}       $(hostname) console console.${DOMAIN}  
EOD


if [ -z $DISK ]; then 
	echo "Not setting the Docker storage."
else
	cp /etc/sysconfig/docker-storage-setup /etc/sysconfig/docker-storage-setup.bk

	echo DEVS=$DISK > /etc/sysconfig/docker-storage-setup
	echo VG=DOCKER >> /etc/sysconfig/docker-storage-setup
	echo SETUP_LVM_THIN_POOL=yes >> /etc/sysconfig/docker-storage-setup
	echo DATA_SIZE="100%FREE" >> /etc/sysconfig/docker-storage-setup

	systemctl stop docker

	rm -rf /var/lib/docker
	wipefs --all $DISK
	docker-storage-setup
fi


echo { \"registry-mirrors\": [\"https://bo30b6ic.mirror.aliyuncs.com/\"] } > /etc/docker/daemon.json
systemctl restart docker
systemctl enable docker

if [ ! -f ~/.ssh/id_rsa ]; then
	ssh-keygen -q -f ~/.ssh/id_rsa -N ""
	cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
	ssh -o StrictHostKeyChecking=no root@$HOSTNAME "pwd" < /dev/null
fi

#正常情况下还是别装这2个了.太慢,而且METRICS淘汰了.
export METRICS="False"
export LOGGING="False"

memory=$(cat /proc/meminfo | grep MemTotal | sed "s/MemTotal:[ ]*\([0-9]*\) kB/\1/")

if [ "$memory" -lt "8194304" ]; then
	export METRICS="False"
fi

if [ "$memory" -lt "20777216" ]; then
	export LOGGING="False"
fi


mkdir -p /etc/origin/master/
touch /etc/origin/master/htpasswd

# 替换 清单
envsubst < ~/vmware-install-okd/inventory3.11.ini > ~/vmware-install-okd/inventory

ansible-playbook -i ~/vmware-install-okd/inventory ~/openshift-ansible/playbooks/prerequisites.yml
ansible-playbook -i ~/vmware-install-okd/inventory ~/openshift-ansible/playbooks/deploy_cluster.yml

htpasswd -b /etc/origin/master/htpasswd ${USERNAME} ${PASSWORD}
oc adm policy add-cluster-role-to-user cluster-admin ${USERNAME}



# 以下新开窗口提前执行为佳,否则安装很慢.

# docker pull docker.io/openshift/origin-pod:v3.11.0
# docker pull docker.io/openshift/origin-node:v3.11.0
# docker pull quay.io/coreos/etcd:v3.2.22
# docker pull docker.io/openshift/origin-control-plane:v3.11.0
# docker pull docker.io/openshift/origin-deployer:v3.11.0
# docker pull docker.io/openshift/origin-haproxy-router:v3.11.0
# docker pull docker.io/openshift/origin-docker-registry:v3.11.0
# docker pull docker.io/cockpit/kubernetes:latest
# docker pull quay.io/coreos/cluster-monitoring-operator:v0.1.1
# docker pull quay.io/coreos/prometheus-operator:v0.23.2
# docker pull docker.io/openshift/origin-web-console:v3.11.0
# docker pull docker.io/grafana/grafana:5.2.1
# docker pull docker.io/openshift/oauth-proxy:v1.1.0
# docker pull docker.io/openshift/origin-console:v3.11.0
# docker pull docker.io/openshift/prometheus:v2.3.2
# docker pull quay.io/coreos/prometheus-config-reloader:v0.23.2
# docker pull docker.io/openshift/origin-service-catalog:v3.11.0
# docker pull quay.io/coreos/configmap-reload:v0.0.1
# docker pull docker.io/openshift/prometheus-alertmanager:v0.15.2
# docker pull docker.io/openshift/prometheus-node-exporter:v0.16.0
# docker pull quay.io/coreos/kube-rbac-proxy:v0.3.1
# docker pull docker.io/ansibleplaybookbundle/origin-ansible-service-broker:latest
# docker pull docker.io/openshift/origin-template-service-broker:v3.11.0
# docker pull quay.io/coreos/kube-state-metrics:v1.3.1
# docker pull quay.io/external_storage/local-volume-provisioner:v2.3.0

if [ "$PVS" = "true" ]; then
  cd ~/vmware-install-okd
  ./local-storage.sh
fi

echo "******"
echo "* Your console is https://console.$DOMAIN:$API_PORT"
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "*"
echo "* Login using:"
echo "*"
echo "$ oc login -u ${USERNAME} -p ${PASSWORD} https://console.$DOMAIN:$API_PORT/"
echo "******"

oc login -u ${USERNAME} -p ${PASSWORD} https://console.$DOMAIN:$API_PORT/
