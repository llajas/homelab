variable "virtual_nodes" {
  description = "Details of virtual nodes"
  type = map(object({
    name              = string
    memory            = number
    vcpu              = number
    mac               = string
    ip                = string
    network_interface = string
    disk_size         = number
  }))
}

resource "libvirt_domain" "virtual_nodes" {
  for_each = var.virtual_nodes

  name   = each.value.name
  memory = each.value.memory
  vcpu   = each.value.vcpu
  qemu_agent = false

  network_interface {
    bridge    = each.value.network_interface
    hostname  = each.value.name
    mac       = each.value.mac
    addresses = [each.value.ip]
  }

  disk {
    volume_id = libvirt_volume.vm_disk.id
  }

  firmware = "/usr/share/qemu/ovmf-x64/OVMF_CODE-pure-efi.fd"

  nvram {
    file = "/etc/libvirt/qemu/nvram/${each.value.name}_VARS-pure-efi.fd"
    template = "/usr/share/qemu/ovmf-x64/OVMF_VARS-pure-efi.fd"
  }
}