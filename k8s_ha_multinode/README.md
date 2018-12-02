## High-Availability Multi-Node Kubernetes Cluster
---

```
$ cd ..k8s_ha_multinode/haproxy; build.sh; cd ..; vagrant up; ansible-playbook  kubernetes.yml
```

A **completely Dockerized** multi-node Kubernetes highly-available cluster provisioned using Vagrant/Ansible, based on Kubernetes version **1.12** 

**Note**: This is not a production-ready setup. Instead, this is intended to be a base/idea for one (if looking for custom setups, otherwise [Kubeadm][0] does job pretty well).

### How Stuff Works

#### Kubernetes

* The setup uses multi-master and multi-worker setup (and multi-etcd, of course).

* On the master-node side, everything is ordinary, as you would expect from any regular Kubernetes master.

* On the worker-node side, the master-nodes are loadbalanced using HAProxy. So the Kubelet connects to HAProxy's address instead of a specific master.

* Yes, HAProxy runs on each of the worker-nodes instead of master. This is because if the master goes down, it also takes down loadbalancer with it (not an ideal scenario).

* CNI: [Weave Net][1]

* DNS: [Core DNS][2]

#### Vagrant

* Vagrant is simply a convenient way of automatically spinning up a cluster. You can easily configure the instances in `Vagrantfile`.

* Uses Virtualbox.

* Default instance-count:
```
ETCD: 1
Kube-Master: 1
Kube-Worker: 1
```

* The setup is based on a custom packed **CoreOS** based Vagrant-image from point 1.

* Just run `vagarnt up`, and it will automatically provison env

* run Ansible and setup a local Kubernetes cluster.

### Run Ansible and setup a local Kubernetes cluster.

Setup inventory
```
all:
  vars:
    ansible_python_interpreter: /opt/bin/python

  children:

    etcd:
      hosts:
        etcd-01:
          ansible_ssh_host: 172.17.8.101
          ansible_user: core
          ansible_ssh_common_args: -o StrictHostKeyChecking=no
          ansible_ssh_private_key_file: ./.vagrant/machines/etcd-01/virtualbox/private_key


    kubernetes:
      children:

        kubernetes-masters:
          hosts:
            kube-master-01:
               ansible_ssh_host: 172.17.8.102
               ansible_user: core
               ansible_ssh_common_args: -o StrictHostKeyChecking=no
               ansible_ssh_private_key_file: ./.vagrant/machines/kube-master-01/virtualbox/private_key

        kubernetes-workers:
          hosts:
            kube-worker-01:
               ansible_ssh_host: 172.17.8.103
               ansible_user: core
               ansible_ssh_common_args: -o StrictHostKeyChecking=no
               ansible_ssh_private_key_file: ./.vagrant/machines/kube-worker-01/virtualbox/private_key
```
$ ansible-playbook  kubernetes.yml

### Additional addons setup:

```
davar@home ~/LABS/CoreOS-packer-vagrant-ansible-k8s/k8s_ha_multinode/roles/kube-addons/tasks $ diff main.yml main.yml.addons 
34,36c34
<   command: 'kubectl apply -f "{{ item.src }}"'
<   with_filetree: "{{ kube_addons_dir }}"
<   when: item.state == "file"
---
>   command: 'kubectl apply -f "{{ kube_addons_dir }}"'
58c56
<     kubectl config --kubeconfig={{ item.config }} set-cluster {{ item.cluster }}
---
>     kubectl config --kubeconfig={{ item.config }} set-cluster {{ item.cluster }} --insecure-skip-tls-verify=true

or Manual

vagrant ssh kube-worker-01
core@kube-worker-01 ~ $ cd /etc/kubernetes/addons/
core@kube-worker-01 /etc/kubernetes/addons $ kubectl create -f .

Test HA:

sudo kubectl config --kubeconfig=/etc/kubernetes/configs/kubeconfig-kubelet.yaml  set-cluster local --insecure-skip-tls-verify=true --server=https://172.17.8.103:6443
sudo kubectl config --kubeconfig=/etc/kubernetes/configs/kubeconfig-proxy.yaml  set-cluster local --insecure-skip-tls-verify=true --server=https://172.17.8.103:6443
sudo kubectl config --kubeconfig=/home/core/.kube/config set-cluster default-cluster --insecure-skip-tls-verify=true --server=https://172.17.8.103:6443

$ sudo systemctl restart kubelet

core@kube-worker-01 /etc/kubernetes/addons $ kubectl get pods -o wide --sort-by="{.spec.nodeName}" --all-namespaces
NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE   IP             NODE           NOMINATED NODE
kube-system   kube-scheduler-172.17.8.102               1/1     Running   0          42m   172.17.8.102   172.17.8.102   <none>
kube-system   kube-apiserver-172.17.8.102               1/1     Running   0          42m   172.17.8.102   172.17.8.102   <none>
kube-system   kube-controller-manager-172.17.8.102      1/1     Running   0          42m   172.17.8.102   172.17.8.102   <none>
kube-system   kube-proxy-172.17.8.102                   1/1     Running   0          42m   172.17.8.102   172.17.8.102   <none>
kube-system   weave-net-c2q6k                           2/2     Running   0          42m   172.17.8.102   172.17.8.102   <none>
kube-system   coredns-primary-f489746ff-ndsjq           1/1     Running   0          26m   10.44.0.2      172.17.8.103   <none>
kube-system   kube-addon-manager-172.17.8.103           1/1     Running   0          15m   172.17.8.103   172.17.8.103   <none>
kube-system   kube-proxy-172.17.8.103                   1/1     Running   0          15m   172.17.8.103   172.17.8.103   <none>
kube-system   haproxy-kube-worker-01-5f866584b5-2f29c   1/1     Running   0          26m   172.17.8.103   172.17.8.103   <none>
kube-system   kubernetes-dashboard-659798bd99-7x6br     1/1     Running   0          26m   10.44.0.1      172.17.8.103   <none>
kube-system   weave-net-4mtxh                           2/2     Running   0          39m   172.17.8.103   172.17.8.103   <none>

core@kube-worker-01 /etc/kubernetes/addons $ kubectl get all --all-namespaces                                      
NAMESPACE     NAME                                          READY   STATUS    RESTARTS   AGE
kube-system   pod/coredns-primary-f489746ff-zpws9           1/1     Running   0          85m
kube-system   pod/haproxy-kube-worker-01-7c985bbb98-5mh2x   1/1     Running   0          18m
kube-system   pod/kube-addon-manager-172.17.8.103           1/1     Running   0          84m
kube-system   pod/kube-apiserver-172.17.8.102               1/1     Running   0          4h59m
kube-system   pod/kube-controller-manager-172.17.8.102      1/1     Running   0          4h59m
kube-system   pod/kube-proxy-172.17.8.102                   1/1     Running   0          4h59m
kube-system   pod/kube-proxy-172.17.8.103                   1/1     Running   0          84m
kube-system   pod/kube-scheduler-172.17.8.102               1/1     Running   0          4h59m
kube-system   pod/kubernetes-dashboard-659798bd99-npwtr     1/1     Running   0          85m
kube-system   pod/weave-net-4mtxh                           2/2     Running   0          4h56m
kube-system   pod/weave-net-c2q6k                           2/2     Running   0          4h59m

NAMESPACE     NAME                           TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
default       service/kubernetes             ClusterIP   10.3.0.1     <none>        443/TCP                  5h
kube-system   service/coredns-primary        ClusterIP   10.3.0.10    <none>        53/UDP,53/TCP,9153/TCP   4h48m
kube-system   service/kubernetes-dashboard   ClusterIP   10.3.0.247   <none>        443/TCP                  4h48m

NAMESPACE     NAME                       DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
kube-system   daemonset.apps/weave-net   2         2         2       2            2           <none>          4h59m

NAMESPACE     NAME                                     DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kube-system   deployment.apps/coredns-primary          1         1         1            1           4h48m
kube-system   deployment.apps/haproxy-kube-worker-01   1         1         1            1           18m
kube-system   deployment.apps/kubernetes-dashboard     1         1         1            1           4h48m

NAMESPACE     NAME                                                DESIRED   CURRENT   READY   AGE
kube-system   replicaset.apps/coredns-primary-f489746ff           1         1         1       4h48m
kube-system   replicaset.apps/haproxy-kube-worker-01-7c985bbb98   1         1         1       18m
kube-system   replicaset.apps/kubernetes-dashboard-659798bd99     1         1         1       4h48m

```

#### TODO:

* HAProxy hosts are not dynamic, need to manully add to config and restart HAProxy.
* Improve Security.
Suggestions welcomed.

### Ansible Notes

* When adding/removing instances, be sure to also update the Ansible [inventory][4].

* Ansible copies its templates for manifests/configs to `/etc/kubernetes`, which will contain all Kubernetes resources, including certificates.



```



  [0]: https://kubernetes.io/docs/setup/independent/install-kubeadm/
  [1]: https://www.weave.works/oss/net/
  [2]: https://coredns.io/

