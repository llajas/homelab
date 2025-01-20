provider "libvirt" {
  uri = "qemu+ssh://${var.hypervisor_user}@${var.hypervisor_host}/system?keyfile=${var.keyfile}&no_verify=1"
}
