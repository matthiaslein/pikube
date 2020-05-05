# pikube

Docomentation for Ubuntu on Raspberry Pi is at:
https://wiki.ubuntu.com/ARM/RaspberryPi
https://ubuntu.com/download/raspberry-pi

Running kubernetes on raspberry pi

1. Clone this repository
1. Install ansible
1. Run the local setup script
1. Install the ssh key that will be used for deployments locally

sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/pikube-ca.crt --cert=/etc/etcd/pikube-etcd.crt --key=/etc/etcd/pikube-etcd.key member list

sudo etcdctl --endpoints=https://192.168.178.80:2379,https://192.168.178.81:2379,https://192.168.178.82:2379 --cacert=/etc/etcd/pikube-ca.crt --cert=/etc/etcd/pikube-etcd.crt --key=/etc/etcd/pikube-etcd.key endpoint health

kubectl run -i -t busybox-01 --image=busybox --restart=Never

kubectl apply -f dnsutils.yml
kubectl exec -ti dnsutils -- nslookup kubernetes.default
kubectl exec -ti dnsutils -- cat /etc/resolv.conf

