resource "mgc_virtual_machine_instances" "basic_instance_sudeste" {
  provider = mgc.sudeste
  name     = "basic-instance-sudeste"
  machine_type = {
    name = "cloud-bs1.xsmall"
  }
  image = {
    name = "cloud-ubuntu-22.04 LTS"
  }
  network = {
    associate_public_ip = false
    delete_public_ip    = false
  }

  tags = {
    hackathon_group = "PejotinhaDaGringa"
    created_by = "lombardi"
  }

  ssh_key_name = "lombardi"
}
