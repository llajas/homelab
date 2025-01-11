variable "storage_pool_path" {
  description = "Path to the storage pool"
  type        = string
  default     = "/mnt/user/domains/default_pool"
}

variable "vm_disk_size" {
  description = "Disk size for the VM in GB"
  type        = number
  default     = 100
}

resource "libvirt_pool" "default_pool" {
  name = "default_pool"
  type = "dir"
  target {
    path = var.storage_pool_path
  }
}

resource "libvirt_volume" "vm_disk" {
  name = "${var.vm_name}.qcow2"
  pool = libvirt_pool.default_pool.name
  size = var.vm_disk_size * 1024 * 1024 * 1024
}