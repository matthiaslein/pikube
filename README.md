# pikube

Docomentation for Ubuntu on Raspberry Pi is at:
https://wiki.ubuntu.com/ARM/RaspberryPi
https://ubuntu.com/download/raspberry-pi

Running kubernetes on raspberry pi

1. Clone this repository
1. Install ansible
1. Run the local setup script
1. Install the ssh key that will be used for deployments locally

curl -LO https://github.com/hypriot/flash/releases/download/2.7.0/flash
chmod +x flash
sudo mv flash /usr/local/bin/flash

sudo flash --device /dev/disk2 --force --file ~/dev/pikube/configuration/network-config --userdata ~/dev/pikube/configuration/user-data-pikube-01 ~/Downloads/ubuntu-20.04-preinstalled-server-arm64+raspi.img.xz

sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/pikube-ca.crt --cert=/etc/etcd/pikube-etcd.crt --key=/etc/etcd/pikube-etcd.key member list

sudo etcdctl --endpoints=https://192.168.178.80:2379,https://192.168.178.81:2379,https://192.168.178.82:2379 --cacert=/etc/etcd/pikube-ca.crt --cert=/etc/etcd/pikube-etcd.crt --key=/etc/etcd/pikube-etcd.key endpoint health

kubectl run -i -t busybox-01 --image=busybox --restart=Never

kubectl apply -f https://k8s.io/examples/admin/dns/dnsutils.yaml
kubectl exec -ti dnsutils -- nslookup kubernetes.default
kubectl exec -ti dnsutils -- cat /etc/resolv.conf

kubectl get svc --all-namespaces

kubectl get nodes -o jsonpath='{range .items[*]} {.metadata.name}{"  "}{.spec.podCIDR}{"\n"}{end}'
