#!/bin/bash

# 以下假设 hostname 为 okd.io ,部分yaml绑定了hostname,所以不要乱改名哦.
oc new-project local-storage
oc project local-storage
oc create serviceaccount local-storage-admin
oc adm policy add-scc-to-user privileged -z local-storage-admin

mkdir -p /data/local-storage/hdd
chcon -R unconfined_u:object_r:svirt_sandbox_file_t:s0 /data/local-storage
oc create -f ./local-volume-config.yaml
oc create -f ./local-storage-provisioner-template.yaml

oc new-app -p CONFIGMAP=local-volume-config \
  -p SERVICE_ACCOUNT=local-storage-admin \
  -p NAMESPACE=local-storage \
  -p PROVISIONER_IMAGE=quay.io/external_storage/local-volume-provisioner:v2.3.0 \
  local-storage-provisioner
  
oc create -f ./storage-class-hdd.yaml

# 创建多个空的pv,给未来的程序使用,建议多建N个,免得不够,后面创建一个pvc,就自动消耗一个pv.
for ((integer = 1; integer <= 10; integer++))
do
  mkdir -p /data/local-storage/hdd/vol$integer
  oc process -f pv-template.yaml -p PV_NAME=vol$integer | oc create -n test1 -f -
done
chcon -R unconfined_u:object_r:svirt_sandbox_file_t:s0 /data/local-storage/hdd/



#下面是测试,验证是否可以用.

# 以下为test1 project的测试
oc new-project  test1


# 创建mysql
oc process openshift//mysql-persistent \
    -p DATABASE_SERVICE_NAME=mysqldb \
    -p MYSQL_USER=yewuuser \
    -p MYSQL_PASSWORD=yyyyyy \
    -p MYSQL_ROOT_PASSWORD=xxxxxxxxx \
    -p MYSQL_DATABASE=yewudb \
    -p VOLUME_CAPACITY=1Gi \
  | oc create -n test1 -f -

