variable "storage_pool_path" {
  description = "Path to the storage pool"
  type        = string
  default     = "/mnt/user/domains/default_pool"
}

variable "vm_disk_size" {
  description = "Default disk size for the VMs in GB (fallback if not set in virtual_nodes)"
  type        = number
  default     = 100
}

variable "storage_pool_name" {
  description = "Name of the storage pool"
  type        = string
  default     = "default_pool"
}

resource "libvirt_pool" "default_pool" {
  name = var.storage_pool_name
  type = "dir"
  target {
    path = var.storage_pool_path
  }
}

resource "libvirt_volume" "vm_disks" {
  for_each = var.virtual_nodes

  name = "${each.value.name}.qcow2"
  pool = libvirt_pool.default_pool.name
  size = each.value.disk_size * 1024 * 1024 * 1024
}
