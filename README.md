# Ceph by Ansible with a touch of Terraform/OpenTofu

## What is this nonsense?

As you may already know that [ceph-ansible](https://docs.ceph.com/projects/ceph-ansible/en/latest/) which used to be the default way of deploying Ceph clusters **using native operating system Ceph packages**. is unmaintained and no longer works.

This created a void to be able to deploy [Ceph clusters](https://ceph.io/en/) using native operating system Ceph packages for lab testing, experiments and educational purposes.

This is where Ceph by Ansible comes to play! By default, it deploys a 6 node cluster including the following services:

- 3 MON
- 6 OSD (2 OSD Disks x 3 OSD Nodes)
- 3 MDS
- 1 RGW

Please note that the primary intention of this project **is not** production cluster deployments.

At the moment, the following Operating Systems are supported:

- Debian 12
- Debian 13
- Rocky Linux 9 (Or any RHEL 9 based)
- Rocky Linux 10 (Or any RHEL 10 based)
- Ubuntu 20.04 LTS
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

## Repository Structure

```
$ tree
.
├── ansible
│   ├── ceph-playbook.yml
│   └── inventory.ini.tmpl
├── main.tf
├── provider.tf
├── README.md
└── variables.tf

2 directories, 6 files
```

## How to Use?

There are two ways to consume this repository:

- *The Ansible only way*: Use the `ceph-playbook.yml` Ansible Playbook with and bring your own inventory file. An example inventory file and usage command is provided bellow:

```
[all]
mon-1 ansible_host=ceph-mon-1.domain.tld ansible_connection=ssh ansible_ssh_common_args="-o StrictHostKeyChecking=no"
mon-2 ansible_host=ceph-mon-2.domain.tld ansible_connection=ssh ansible_ssh_common_args="-o StrictHostKeyChecking=no"
mon-3 ansible_host=ceph-mon-3.domain.tld ansible_connection=ssh ansible_ssh_common_args="-o StrictHostKeyChecking=no"
osd-1 ansible_host=ceph-osd-1.domain.tld ansible_connection=ssh ansible_ssh_common_args="-o StrictHostKeyChecking=no"
osd-2 ansible_host=ceph-osd-2.domain.tld ansible_connection=ssh ansible_ssh_common_args="-o StrictHostKeyChecking=no"
osd-3 ansible_host=ceph-osd-3.domain.tld ansible_connection=ssh ansible_ssh_common_args="-o StrictHostKeyChecking=no"

[admin]
mon-1

[mon]
mon-1
mon-2
mon-3

[mgr]
mon-1
mon-2
mon-3

[mds]
mon-1
mon-2
mon-3

[osd]
osd-1 osd_disks='["/dev/sdb","/dev/sdc"]'
osd-2 osd_disks='["/dev/sdb","/dev/sdc"]'
osd-3 osd_disks='["/dev/sdb","/dev/sdc"]'

[rgw]
mon-1
```
```
ansible-playbook ansible/ceph-playbook.yml -i <inventory-file-name-here> -u ${ssh_user}
```

- *The Ansible+Terraform/OpenTofu way (Recommended)*: Use `terraform` (or `opentofu`) to do the hard lifting after adjusting the `variables.tf` file or providing overriding variables. This utilizes the [OpenStack provider](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs) to deploy required instances, then dynamically generates an inventory file in order to use Ansible for the Ceph cluster configuration.

## Dependencies and prerequisites

In order to fully benefit from this repository, you need to install Ansible ([Installation Guide](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html)) and Terraform ([Installation Guide](https://developer.hashicorp.com/terraform/install)).

This repository is also compatible with OpenTofu ([Installation Guide](https://opentofu.org/docs/intro/install/)). This means on a modern Ubuntu or Debian machine, you can simply install the required dependencies using the following command:

```
sudo apt-get update; sudo apt-get -y install ansible opentofu
```

- **Note**: Use SCSI bus if want OSD disk names to be /dev/sd* (see the `variables.tf` file). Use the following command to update existing images:

```
openstack image set --property hw_disk_bus='scsi' --property hw_scsi_model='virtio-scsi' <image-name-here>
```

In order to be able to use the OpenStack provider, you need an existing `openrc` or `clouds.yaml` file. Alternatively create a granular application credential using the following command:

```
openstack application credential create tf-app-cred \
  --description "Terraform Ceph Cluster Application Credentials" \
  --access-rules '[
    {"service":"compute","method":"POST","path":"/v2.1/servers"},
    {"service":"compute","method":"GET","path":"/v2.1/servers"},
    {"service":"compute","method":"GET","path":"/v2.1/servers/*"},
    {"service":"compute","method":"DELETE","path":"/v2.1/servers/*"},
    {"service":"compute","method":"POST","path":"/v2.1/servers/*/action"},
    {"service":"compute","method":"POST","path":"/v2.1/servers/*/os-volume_attachments/*"},
    {"service":"compute","method":"POST","path":"/v2.1/servers/*/os-volume_attachments"},
    {"service":"compute","method":"GET","path":"/v2.1/servers/*/os-volume_attachments"},
    {"service":"compute","method":"GET","path":"/v2.1/servers/*/os-volume_attachments/*"},
    {"service":"compute","method":"DELETE","path":"/v2.1/servers/*/os-volume_attachments/*"},
    {"service":"compute","method":"GET","path":"/v2.1/flavors"},
    {"service":"compute","method":"GET","path":"/v2.1/flavors/*"},
    {"service":"compute","method":"GET","path":"/v2.1/flavors/*/os-extra_specs"},
    {"service":"compute","method":"GET","path":"/v2.1/os-keypairs/*"},
    {"service":"image","method":"GET","path":"/v2/images"},
    {"service":"image","method":"GET","path":"/v2/images/*"},
    {"service":"network","method":"GET","path":"/v2.0/networks"},
    {"service":"network","method":"GET","path":"/v2.0/security-groups"},
    {"service":"network","method":"GET","path":"/v2.0/ports"},
    {"service":"network","method":"POST","path":"/v2.0/ports"},
    {"service":"network","method":"DELETE","path":"/v2.0/ports/*"},
    {"service":"volumev3","method":"GET","path":"/v3/*/volumes"},
    {"service":"volumev3","method":"POST","path":"/v3/*/volumes"},
    {"service":"volumev3","method":"GET","path":"/v3/*/volumes/*"},
    {"service":"volumev3","method":"DELETE","path":"/v3/*/volumes/*"},
    {"service":"dns","method":"POST","path":"/v2/zones/*/recordsets"},
    {"service":"dns","method":"GET","path":"/v2/zones"},
    {"service":"dns","method":"GET","path":"/v2/zones/*"},
    {"service":"dns","method":"GET","path":"/v2/zones/*/recordsets"},
    {"service":"dns","method":"GET","path":"/v2/zones/*/recordsets/*"},
    {"service":"dns","method":"DELETE","path":"/v2/zones/*/recordsets/*"}
  ]' --fit-width
```

Make a note of the application ID as well as the secret, then create a set of environment variables similar to the following:

```
export OS_AUTH_URL="https://keystone.example:5000/v3"
export OS_AUTH_TYPE="v3applicationcredential"
export OS_APPLICATION_CREDENTIAL_ID="…"
export OS_APPLICATION_CREDENTIAL_SECRET="…"
export OS_REGION_NAME="RegionOne"
export OS_INTERFACE="public"   # or internal
export OS_IDENTITY_API_VERSION="3"
```

Make sure to find the correct Keystone URL and Region name using the following command:

```
openstack endpoint list --service identity --interface public -f value -c URL -c Region
```

## Deploy

Use the following commands to start a deployment. Adjust the SSH user (ansible_user) and the desired OpenStack image name (See `variables.tf` for details):

```
tofu init
tofu plan -var ansible_user=rocky -var openstack_image=Rocky-9.7-2025-11-23 -out ceph-cluster
tofu apply ceph-cluster
```

## Inspect

```
tofu show
```

## Destroy

```
tofu destroy
```

## Feedback

Help to make this repository better! Report issues or submit feedback / feature requests
