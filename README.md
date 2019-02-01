# 一键安装OKD单机版.

vm安装需求: 40GB以上空间,关闭swap分区,关闭/home分区,仅仅保留根分区和/boot分区.网卡自动启动,建议写死IP和网关DNS等.

```
# install vmware tools
yum update -y
yum -y install open-vm-tools git
reboot
#
git clone https://github.com/zhengbin78/vmware-install-okd.git
cd vmware-install-okd

export USERNAME="admin"
export PASSWORD="admin"
export IP=${IP:="$(ip route get 114.114.114.114 | awk '{print $NF; exit}')"}
export DOMAIN="${IP}.nip.io" 
export DISK="" 

./install-openshift.sh
