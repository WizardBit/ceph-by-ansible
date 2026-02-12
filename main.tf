data "openstack_images_image_v2" "img" {
  name        = var.openstack_image
  most_recent = true
}

data "openstack_compute_flavor_v2" "flv" {
  name = var.openstack_flavor
}

data "openstack_networking_network_v2" "net" {
  name = var.openstack_net
}

data "openstack_networking_secgroup_v2" "sg" {
  name = var.openstack_security_group
}

data "openstack_compute_keypair_v2" "kp" {
  name = var.openstack_ssh_keypair
}

data "openstack_dns_zone_v2" "zone" {
  count = var.openstack_designate ? 1 : 0
  name = var.openstack_domain
}

locals {
  all_nodes = concat(var.mons, var.osds)
  mons = [for n in var.mons : openstack_compute_instance_v2.node[n]]
  osds = [for n in var.osds : openstack_compute_instance_v2.node[n]]

  osd_volume_pairs = flatten([
    for host in var.osds : [
      for idx in range(1, var.osd_count + 1) : {
        host = host
        idx  = idx
        name = "${host}-vol-${idx}"
      }
    ]
  ])

  inventory_ini = templatefile("${path.module}/ansible/inventory.ini.tmpl", {
    ansible_user = var.ansible_user
    domain = var.openstack_domain
    mons = local.mons
    osds = local.osds
    osd_1_device = var.osd_1_device
    osd_2_device = var.osd_2_device
  })
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/ansible/inventory.ini"
  content  = local.inventory_ini
}

###############################################################################
# Boot-from-volume instances
###############################################################################
resource "openstack_compute_instance_v2" "node" {
  for_each = toset(local.all_nodes)

  name              = each.value
  availability_zone = var.openstack_az
  flavor_id         = data.openstack_compute_flavor_v2.flv.id
  key_pair          = data.openstack_compute_keypair_v2.kp.name
  security_groups   = [data.openstack_networking_secgroup_v2.sg.name]

  network {
    uuid = data.openstack_networking_network_v2.net.id
  }

  block_device {
    uuid                  = data.openstack_images_image_v2.img.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = var.root_size
    boot_index            = 0
    delete_on_termination = true
  }
}

###############################################################################
# DNS A records for each instance
###############################################################################
resource "openstack_dns_recordset_v2" "a" {
  for_each = var.openstack_designate ? openstack_compute_instance_v2.node : {}

  zone_id = data.openstack_dns_zone_v2.zone[0].id
  name    = "${each.key}.${var.openstack_domain}"
  type    = "A"
  ttl     = 300

  records = [each.value.access_ip_v4 != "" ? each.value.access_ip_v4 : each.value.network[0].fixed_ip_v4]
  depends_on = [openstack_compute_instance_v2.node]
}

###############################################################################
# Data volumes for OSDs and attachments
###############################################################################
resource "openstack_blockstorage_volume_v3" "osd_data" {
  for_each = { for v in local.osd_volume_pairs : v.name => v }

  name              = each.key
  size              = var.osd_size
  volume_type       = "Ceph_NVMe"
  availability_zone = var.openstack_az
}

resource "openstack_compute_volume_attach_v2" "osd_attach" {
  for_each = { for v in local.osd_volume_pairs : v.name => v }

  instance_id = openstack_compute_instance_v2.node[each.value.host].id
  volume_id   = openstack_blockstorage_volume_v3.osd_data[each.key].id
}

###############################################################################
# Outputs
###############################################################################
output "instances" {
  value = {
    for name, inst in openstack_compute_instance_v2.node :
    name => {
      id    = inst.id
      ip_v4 = (inst.access_ip_v4 != "" ? inst.access_ip_v4 : inst.network[0].fixed_ip_v4)
      az    = inst.availability_zone
    }
  }
}

output "osd_volumes" {
  value = {
    for name, vol in openstack_blockstorage_volume_v3.osd_data :
    name => {
      id   = vol.id
      host = split("-vol-", name)[0]
      size = vol.size
      type = vol.volume_type
    }
  }
}

###############################################################################
# Execute Ansible
###############################################################################
resource "null_resource" "run_ansible" {
  depends_on = [local_file.ansible_inventory]

  provisioner "local-exec" {
    environment = {
      ANSIBLE_FORCE_COLOR = "1"
      ANSIBLE_STDOUT_CALLBACK = "yaml"
      PYTHONUNBUFFERED = "1"
    }

    command = <<EOT
      for i in $(seq 1 12); do
        echo -ne "\033[1;34mWaiting for instances to boot ● ● ●\033[0m"
        sleep 5
      done
      echo -e " \033[1;32mReady for next steps\033[0m"

      ansible-playbook \
        -i ${local_file.ansible_inventory.filename} \
        ${path.module}/ansible/ceph-playbook.yml
    EOT
  }
}
