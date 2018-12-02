### 1.Create CoreOS vagrant box with python, ansible, docker-copose inside.

```
$ cd packer_coreos-ansible-python; packer build coreos.json; 
$ vagrant box add --force coreos_ansible ./builds/stable/virtualbox/coreos_ansible_stable_1800-4-0.box 

```

## CoreOS with Python, Ansible, and Docker-Compose

This is the packer configuration for building Core-OS image with pre-setup Python, Ansible, and Docker-Compose.

**Currently based on CoreOS Stable 1800.4.0.**

**Vagrant-Cloud Link**: https://app.vagrantup.com/adavarski/boxes/coreos_ansible

### About

This configuration targets **Vagrant-VirtualBox** only (at the moment).
So it generates a Vagrant box.
However, other targets such as VMWare, KVM/QEMU can be easily added.

This is the latest stable release (as per commit-date) for the Core-OS.
It uses [ActivePython][1] for Python, and installs Ansible using PIP.

By deafult, Ignition is only used to insert the Vagrant insecure key.
Since ignition is already used, **do not use Ignition again to orchestrate the OS**.
This might cause problems (suchas failure to boot). Instead, use Ansible.

### Why

This is intended to orchestrate the local environment for Vagrant-VirtualBox.

Including Ansible within the Box will allow developers to directly use Vagrant's
Ansible provisioning without having to actually install Ansible on their local.
Hence, the complete setup can be automated.

### Running the Box using Vagrant

The Vagrantfile provided at the root of repo can be used as a base Vagrantfile (its further based on [Core-OS Vagrant][2]'s Vagrantfile).

When running `vagrant up`, you might see some SSH failure messages such as:

`core-01: Warning: Connection reset. Retrying...`

This is normal. Core-OS takes a little while to boot, so Vagrant will just
have to keep retrying to SSH until th VM is booted and SSH is ready to go.
Feel free to take a look at GUI in VirtualBox to see what's happening
(also helps in debugging).

### Building the image

#### Using Makefile

* Run `make build` to build the image. This also enables debugging options by default.
This will also generate a log file with the Packer output.

* Run `make build-d` to build without debugging options.

* Check out Makefile for all targets

#### Without using Makefile

The usual Packer command: `packer build coreos.json`

### Testing the Box

A basic "test-suite" (is it even enough to be called a *Test-Suite*?) bash script
can be found in "tests" directory. The simple script simply checks if all
binaries: Python, Ansible, Docker-Compose are accessible by the system.

The tests are automatically run after evey Packer build, and the Packer build
won't succeed unless are tests are passed.

#### Running the test:

Using make: `make test`.

Manual Testing: Just execute `tests/basic_test_suite.sh`.

### FAQs

* **Do you intend to suport any other options such as VMWare, KVM/QEMU?**

No, no such plans yet. As I said earlier, it should be easy to extend this configuration
to other hypervisors. I like free stuff; VirtualBox is free, and simple.

* **Why not use Vagrantfile to setup all this?**

A pre-packaged box such as this ensures consistency and makes environment less error-prone.
Additionally, this is usually the base setup for my Vagrant these days.

 [1]: https://www.activestate.com/activepython
 [2]: https://github.com/coreos/coreos-vagrant

### Import builded box

```
vagrant box add --force coreos_ansible ./builds/stable/virtualbox/coreos_ansible_stable_1800-4-0.box 

```

#### 2.Create HA Multi-Node k8s Cluster


## High-Availability Multi-Node Kubernetes Cluster
---

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

* The setup is based on a custom packed **CoreOS** based Vagrant-image from previous packer build box.

* Just run `vagarnt up`, and it will automatically create VMs

* run  Ansible and setup a local Kubernetes cluster.


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

or Manual:

vagrant ssh kube-worker-01
core@kube-worker-01 ~ $ cd /etc/kubernetes/addons/
core@kube-worker-01 /etc/kubernetes/addons $ kubectl create -f .

Test HA:

sudo kubectl config --kubeconfig=/etc/kubernetes/configs/kubeconfig-kubelet.yaml  set-cluster local --insecure-skip-tls-verify=true --server=https://172.17.8.103:6443
sudo kubectl config --kubeconfig=/etc/kubernetes/configs/kubeconfig-proxy.yaml  set-cluster local --insecure-skip-tls-verify=true --server=https://172.17.8.103:6443
sudo kubectl config --kubeconfig=/home/core/.kube/config set-cluster default-cluster --insecure-skip-tls-verify=true --server=https://172.17.8.103:6443

$ sudo systemctl restart kubelet
```
#### TODO:

* HAProxy hosts are not dynamic, need to manully add to config and restart HAProxy.
* Improve Security.
Suggestions welcomed.

### Ansible Notes

* When adding/removing instances, be sure to also update the Ansible [inventory][4].

* Ansible copies its templates for manifests/configs to `/etc/kubernetes`, which will contain all Kubernetes resources, including certificates.

  [0]: https://kubernetes.io/docs/setup/independent/install-kubeadm/
  [1]: https://www.weave.works/oss/net/
  [2]: https://coredns.io/
