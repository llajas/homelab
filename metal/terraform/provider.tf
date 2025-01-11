variable "libvirt_uri" {
  description = "URI for the Libvirt provider"
  type        = string
  default     = "qemu+ssh://root@10.8.0.8/system?keyfile=/home/red/.ssh/id_rsa&no_verify=1"
}

provider "libvirt" {
  uri = var.libvirt_uri
}