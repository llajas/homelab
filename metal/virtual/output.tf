output "virtual_node_ips" {
  value       = { for node, config in var.virtual_nodes : node => config.ip }
  description = "IP addresses of the virtual nodes"
}

output "virtual_node_names" {
  value       = keys(var.virtual_nodes)
  description = "Names of the virtual nodes"
}
