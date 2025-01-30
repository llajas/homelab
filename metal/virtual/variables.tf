# Libvirt Provider Variables
variable "hypervisor_user" {
  description = "Username for the hypervisor connection"
  type        = string
}

variable "hypervisor_host" {
  description = "Hostname or IP of the hypervisor"
  type        = string
}

variable "keyfile" {
  description = "Path to the SSH private key for the hypervisor"
  type        = string
}

# Network configuration
variable "bridge_interface" {
  description = "Bridge interface for network connection"
  type        = string
}

# Storage Variables
variable "storage_pool_path" {
  description = "Path to the storage pool"
  type        = string
  default     = "/mnt/user/domains/homelab_pool"
}

variable "storage_pool_name" {
  description = "Name of the storage pool"
  type        = string
  default     = "homelab_pool"
}

variable "vm_disk_size" {
  description = "Default disk size for the VMs in GB (fallback if not set in virtual_nodes)"
  type        = number
  default     = 100
}

# Virtual Nodes Variables
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
    has_gpu           = bool
  }))
}
