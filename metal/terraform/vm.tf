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

  name       = each.value.name
  memory     = each.value.memory
  vcpu       = each.value.vcpu
  qemu_agent = false

  network_interface {
    bridge    = "br1.137"
    hostname  = each.value.name
    mac       = each.value.mac
    addresses = [each.value.ip]
  }

  disk {
    # Reference the dynamically created volume for this VM
    volume_id = libvirt_volume.vm_disks[each.key].id
  }

  firmware = "/usr/share/qemu/ovmf-x64/OVMF_CODE-pure-efi.fd"

  nvram {
    file     = "/etc/libvirt/qemu/nvram/${each.value.name}_VARS-pure-efi.fd"
    template = "/usr/share/qemu/ovmf-x64/OVMF_VARS-pure-efi.fd"
  }

  cpu {
    mode = "host-passthrough"
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type           = "vnc"
    listen_type    = "address"
    listen_address = "0.0.0.0"
    websocket      = -1
  }

  boot_device {
    dev = ["hd", "network"]
  }
}
