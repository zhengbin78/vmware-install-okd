# 一键安装OKD单机版.

vm安装需求: 40GB以上空间,安装时关闭swap分区,关闭/home分区,仅仅保留根分区和/boot分区.网卡自动启动,建议写死IP和网关DNS等.虚拟机使用NAT方式联网.
OS版本： Centos 7.6 
安装方式： 最简模块安装

禁忌： 别装完后乱改任何参数配置,包括selinux,firewalld,yum repo等都不要动.要干净的环境.

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

