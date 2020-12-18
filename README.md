# pikube

Docomentation for Ubuntu on Raspberry Pi is at:
https://ubuntu.com/raspberry-pi
https://ubuntu.com/download/raspberry-pi
and some older documentation here:
https://wiki.ubuntu.com/ARM/RaspberryPi

Running kubernetes on raspberry pi

1. Clone this repository
1. Install ansible
1. Run the local setup script
1. Install the ssh key that will be used for deployments locally

Contributors should install:
pip3 install pre-commit
sudo apt install shellcheck

curl -LO https://github.com/hypriot/flash/releases/download/2.7.0/flash
chmod +x flash
sudo mv flash /usr/local/bin/flash

sudo flash --device /dev/disk2 --force --file ~/dev/pikube/configuration/network-config --userdata ~/dev/pikube/configuration/user-data-pikube-01 ~/dev/ubuntu-20.04.1-preinstalled-server-arm64+raspi.img.xz

sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/pikube-ca.crt --cert=/etc/etcd/pikube-etcd.crt --key=/etc/etcd/pikube-etcd.key member list

sudo etcdctl --endpoints=https://192.168.178.80:2379,https://192.168.178.81:2379,https://192.168.178.82:2379 --cacert=/etc/etcd/pikube-ca.crt --cert=/etc/etcd/pikube-etcd.crt --key=/etc/etcd/pikube-etcd.key endpoint health

kubectl run -i -t busybox-01 --image=busybox --restart=Never

kubectl apply -f https://k8s.io/examples/admin/dns/dnsutils.yaml
kubectl exec -ti dnsutils -- nslookup kubernetes.default
kubectl exec -ti dnsutils -- cat /etc/resolv.conf

kubectl get svc --all-namespaces

kubectl get nodes -o jsonpath='{range .items[*]} {.metadata.name}{"  "}{.spec.podCIDR}{"\n"}{end}'

# Deploy MetalLB load-balancer
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/metallb.yaml
## On first install only
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

# Deploy K8s dashboard with
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml

kubectl create serviceaccount dashboard-admin-sa

kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin-sa

kubectl get secrets

kubectl describe secret dashboard-admin-sa-token-?????
or
kubectl -n default describe secret $(kubectl -n kube-system get secret | awk '/^dashboard-admin-sa-token-/{print $1}') | awk '$1=="token:"{print $2}' | tail -n 1

http://127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/login
# requirements for k8s through ansible
pip3 install kubernetes openshift kubernetes-validate

# Deploy rook
# https://rook.io/docs/rook/v1.2/helm-operator.html
helm repo add rook-release https://charts.rook.io/release
kubectl create namespace rook-ceph
helm install --namespace rook-ceph rook-release/rook-ceph --generate-name

# Create Ceph cluster
kubectl create -f templates/rook-ceph-cluster.yml
kubectl -n rook-ceph get pod

# Patching CRDs if namespace is stuck in terminating
for CRD in $(kubectl get crd -n rook-ceph | awk '/ceph.rook.io/ {print $1}'); do kubectl patch crd -n rook-ceph $CRD --type merge -p '{"metadata":{"finalizers": [null]}}'; done

# zapping devices
sudo dd if=/dev/zero of=/dev/sda count=1024 bs=1048576 && sudo sgdisk --zap /dev/sda && echo w | sudo fdisk /dev/sda
# rook ceph healthchecks
https://github.com/rook/rook/blob/master/Documentation/ceph-toolbox.md

# rook ceph teardown
https://github.com/rook/rook/blob/master/Documentation/ceph-teardown.md

# create block storage
kubectl create -f templates/rook-ceph-block-storageclass.yml
