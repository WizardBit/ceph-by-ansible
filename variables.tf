variable "ansible_user" {
  type    = string
  default = "ubuntu"
}

variable "osd_count" {
  type    = number
  default = 2
}

variable "osd_size" {
  type    = number
  default = 50
}

variable "osd_1_device" {
  type    = string
  default = "/dev/sdb"
}

variable "osd_2_device" {
  type    = string
  default = "/dev/sdc"
}

variable "openstack_designate" {
  type    = bool
  default = false
}

variable "openstack_domain" {
  type    = string
  default = "hrizn.lab." # keep trailing dot
}

variable "openstack_image" {
  type    = string
  default = "noble-ceph-ansible"
}

variable "openstack_flavor" {
  type    = string
  default = "staging-cpu4-ram8-disk50"
}

variable "openstack_net" {
  type    = string
  default = "net_$OS_USERNAME-pse"
}

variable "openstack_az" {
  type    = string
  default = "availability-zone-1"
}

variable "root_size" {
  type    = number
  default = 50
}

variable "openstack_security_group" {
  type    = string
  default = "default"
}

variable "openstack_ssh_keypair" {
  type    = string
  default = "lpkey"
}

variable "mons" {
  type    = list(string)
  default = ["ceph-mon-1", "ceph-mon-2", "ceph-mon-3"]
}

variable "osds" {
  type    = list(string)
  default = ["ceph-osd-1", "ceph-osd-2", "ceph-osd-3"]
}
