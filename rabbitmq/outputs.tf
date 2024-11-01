output "cluster_ip" {
  description = "IP of the LB of the cluster"
  value = mgc_virtual_machine_instances.lb.network.public_address
}
