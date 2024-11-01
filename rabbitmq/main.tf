terraform {
  required_providers {
    mgc = {
      source = "magalucloud/mgc"
      version = "0.27.1"
    }
  }
}

locals {
  # instances_private_ips = [join(",", aws_instance.example[*].id)]
  instances_private_ips = []
}

provider "mgc" {
  alias  = "nordeste"
  region = "br-ne1"
}

resource "mgc_network_vpc" "rbmq_vpc" {
  provider = mgc.nordeste
  name        = "${var.hackathon_group}-${var.created_by}-rbmq-vpc"
  description = "${var.hackathon_group}-${var.created_by}-rbmq-vpc"
}

# LER README!!
# resource "mgc_network_security_groups" "lb_security_group" {
#   provider    = mgc.nordeste
#   name = "${var.hackathon_group}-${var.created_by}-mongodb-sec-group"
# }
# resource "mgc_network_security_groups_rules" "allow_ssh" {
#   description      = "Allow incoming MongoDB traffic"
#   direction        = "ingress"
#   ethertype        = "IPv4"
#   port_range_max   = 27017
#   port_range_min   = 27017
#   protocol         = "tcp"
#   remote_ip_prefix = "0.0.0.0/0"
#   security_group_id = var.lb_security_group_id
# }

resource "mgc_virtual_machine_instances" "instances" {
  provider = mgc.nordeste
  count    = var.cluster_size
  name     = "${var.hackathon_group}-${var.created_by}-rbmq-node-${count.index}"
  machine_type = {
    name = var.machine_type
  }
  image = {
    name = "cloud-ubuntu-22.04 LTS"
  }
  network = {
    vpc = {
      id = mgc_network_vpc.rbmq_vpc.network_id
    }
    associate_public_ip = false # If true, will create a public IP
    delete_public_ip    = false
    interface = {
      security_groups = [{ "id" : var.lb_security_group_id }]
    }
  }

  ssh_key_name = var.ssh_key_name
}

resource "mgc_virtual_machine_instances" "lb" {
  provider = mgc.nordeste
  name     = "${var.hackathon_group}-${var.created_by}-rbmq-lb"
  machine_type = {
    name = "BV1-1-10"
  }
  image = {
    name = "cloud-ubuntu-22.04 LTS"
  }
  network = {
    vpc = {
      id = mgc_network_vpc.rbmq_vpc.network_id
    }
    associate_public_ip = true
    delete_public_ip    = true
    interface = {
      security_groups = [{ "id" : var.lb_security_group_id }]
    }
  }

  ssh_key_name = var.ssh_key_name
}

locals {
  instance_ips_comma_separated = join(",", mgc_virtual_machine_instances.instances[*].network.private_address)
}

# output "oi" {
#   value = mgc_virtual_machine_instances.instances[*]
# }

resource "null_resource" "provision_lb" {
  provisioner "remote-exec" {
    inline = [
      "mkdir /tmp/scripts",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = mgc_virtual_machine_instances.lb.network.public_address
    }
  }

  provisioner "file" {
    source      = "scripts/"
    destination = "/tmp/scripts/"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = mgc_virtual_machine_instances.lb.network.public_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      # "sudo apt-get update",
      # "sudo su -c \"curl -sSL https://get.docker.com/ | sh\"",
      "chmod +x /tmp/scripts/*.sh",
      # "/tmp/scripts/init_lb_cilium.sh 27017 ${mgc_virtual_machine_instances.lb.network.public_address} ${local.instance_ips_comma_separated}",
      "/tmp/scripts/init_lb_haproxy.sh 5672 ${mgc_virtual_machine_instances.lb.network.public_address} ${local.instance_ips_comma_separated}",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = mgc_virtual_machine_instances.lb.network.public_address
    }
  }
}

# locals {
#   # cookie=$(openssl rand -hex 32)
#   instance_etc_hosts = join("\n", "${mgc_virtual_machine_instances.instances[*].network.private_address} ${mgc_virtual_machine_instances.instances[*].name}")
# }

# output "oi" {
#   value = local.instance_etc_hosts
# }

locals {
  etc_hosts = <<EOT
  %{ for i in mgc_virtual_machine_instances.instances[*] ~}
  ${i.network.private_address} ${i.name}
  %{ endfor ~}
  EOT
}


resource "null_resource" "provision_rbmq" {
  count = length(mgc_virtual_machine_instances.instances)
  provisioner "remote-exec" {
    inline = [
      "mkdir /tmp/scripts",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = mgc_virtual_machine_instances.instances[count.index].network.ipv6
    }
  }

  provisioner "file" {
    source      = "scripts/"
    destination = "/tmp/scripts/"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = mgc_virtual_machine_instances.instances[count.index].network.ipv6
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/scripts/*.sh",
      "/tmp/scripts/init_rabbit_mq.sh",
      "sleep 10"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = mgc_virtual_machine_instances.instances[count.index].network.ipv6
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/scripts/*.sh",
      "sudo mv /tmp/scripts/templates/rabbitmq.conf /etc/rabbitmq/rabbitmq.conf",
      "sudo mv /tmp/scripts/templates/.erlang.cookie /var/lib/rabbitmq/.erlang.cookie",
      "sudo echo -e ${local.etc_hosts} >> /etc/hosts",
      "sudo service rabbitmq-server enable --now"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = mgc_virtual_machine_instances.instances[count.index].network.ipv6
    }
  }
}

