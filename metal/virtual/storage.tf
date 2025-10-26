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

  depends_on = [libvirt_pool.default_pool]
}
