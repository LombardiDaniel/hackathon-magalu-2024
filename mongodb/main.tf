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

resource "mgc_network_vpc" "mongo_db_vpc" {
  provider = mgc.nordeste
  name        = "${var.hackathon_group}-${var.created_by}-mongodb-vpc"
  description = "${var.hackathon_group}-${var.created_by}-mongodb-vpc"
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
  name     = "${var.hackathon_group}-${var.created_by}-mongodb-node-${count.index}"
  machine_type = {
    name = var.machine_type
  }
  image = {
    name = "cloud-ubuntu-22.04 LTS"
  }
  network = {
    vpc = {
      id = mgc_network_vpc.mongo_db_vpc.network_id
      # id = "240da5c2-7000-4b5e-ac42-f58c5723b78a"
    }
    associate_public_ip = false # If true, will create a public IP
    delete_public_ip    = false
  }

  ssh_key_name = var.ssh_key_name
}

resource "mgc_virtual_machine_instances" "lb" {
  provider = mgc.nordeste
  name     = "${var.hackathon_group}-${var.created_by}-mongodb-lb"
  machine_type = {
    name = "BV1-1-10"
  }
  image = {
    name = "cloud-ubuntu-22.04 LTS"
  }
  network = {
    vpc = {
      id = mgc_network_vpc.mongo_db_vpc.network_id
      # id = "240da5c2-7000-4b5e-ac42-f58c5723b78a"
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
  instance_ips_comma_separated = join(",", mgc_virtual_machine_instances.instances[*].network.public_address)
}

resource "null_resource" "provision_lb" {
  provisioner "file" {
    source      = "scripts/init_lb.sh"
    destination = "/tmp/init_lb.sh"

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
      "chmod +x /tmp/*.sh",
      "/tmp/init_lb.sh 27017 ${mgc_virtual_machine_instances.lb.network.public_address} ${local.instance_ips_comma_separated}"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = mgc_virtual_machine_instances.lb.network.public_address
    }
  }
}



# # Route Table
# resource "aws_route_table" "my_route_table" {
#   vpc_id = aws_vpc.my_vpc.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.my_igw.id
#   }
# }

# # Associate the route table with the subnet
# resource "aws_route_table_association" "my_subnet_association" {
#   subnet_id      = aws_subnet.my_subnet_1.id
#   route_table_id = aws_route_table.my_route_table.id
# }
# # Security Group for EC2 Instance
# resource "aws_security_group" "ec2_sg" {
#   name        = "ec2_sg"
#   description = "Security group for EC2 instance"
#   vpc_id      = aws_vpc.my_vpc.id

#   ingress {
#     from_port = 22
#     to_port   = 22
#     protocol  = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   ingress {
#     from_port = 27017
#     to_port   = 27017
#     protocol  = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   egress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#    }
# }
# ### db security group
# resource aws_security_group "docdb-security-group"{
#     name        = "docdb-sg"
#     description = "Security group for documentdb"
#     vpc_id      = aws_vpc.my_vpc.id
#     ingress {
#         from_port = 27017
#         to_port = 27017
#         protocol = "tcp"
#         cidr_blocks = ["0.0.0.0/0"]
#     }
# }
# resource "aws_key_pair" "ssh_keypair" {
#   key_name   = "my-keypair"  # Replace with your desired key pair name
#   public_key = file("~/.ssh/id_rsa.pub")  # Replace with the path to your public key file
# }
# # EC2 Instance
# resource "aws_instance" "my_instance" {
#   ami             = "ami-0fc5d935ebf8bc3bc" # Ubuntu 20.04 LTS
#   instance_type   = "t2.micro"
#   key_name        = aws_key_pair.ssh_keypair.key_name
#   subnet_id       = aws_subnet.my_subnet_1.id
#   security_groups  = [aws_security_group.ec2_sg.id]
#   associate_public_ip_address = true
#   user_data = <<-EOF
#               #!/bin/bash
#               apt-get update
#               apt-get install gnupg curl
#               curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
#               gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
#               --dearmor
#               echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
#               apt-get update
#               apt-get install -y mongodb-org
#               systemctl start mongod
#               systemctl enable mongodb
#               EOF
#  tags = {
#     Name = "my-ssh-tunnel-server"

#  }
# }

# # DocumentDB Cluster
# resource "aws_docdb_cluster_instance" "mydocdb_instance" {
#   identifier           = "docdb-cluster-instance"
#   cluster_identifier   = aws_docdb_cluster.docdb_cluster.id
#   instance_class       = "db.t3.medium"  # Replace with your desired instance type
# #   publicly_accessible  = false
# }
# resource "aws_docdb_subnet_group" "subnet_group" {
#   name       = "db-subnet-group"
#   subnet_ids = [aws_subnet.subnet_us_east_1b_private.id,aws_subnet.subnet_us_east_1c_private.id]
# }
# resource "aws_docdb_cluster" "docdb_cluster" {
#   cluster_identifier   = "docdb-cluster"
#   availability_zones   = ["us-east-1a","us-east-1b","us-east-1c"]  # Replace with your desired AZs
#   engine_version       = "4.0.0"
#   master_username      = "adminuser"
#   master_password      = "password123"  # Replace with your own strong password
#   backup_retention_period = 5  # Replace with your desired retention period
#   preferred_backup_window = "07:00-09:00"  # Replace with your desired backup window
#   skip_final_snapshot   = true
#   db_subnet_group_name = aws_docdb_subnet_group.subnet_group.name
#   vpc_security_group_ids = [aws_security_group.docdb-security-group.id]
#   # Additional cluster settings can be configured here
# }