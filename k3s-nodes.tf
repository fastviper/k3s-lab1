# auth provided in environment variables
# https://www.terraform.io/docs/providers/aws/index.html
provider "aws" {}

variable "region" {
  default = "eu-central-1"
}

variable "K3S_SETUP_SECRET" {
  default = "not-very-secret"
}

# SSH key pair to be used on nodes
resource "aws_key_pair" "deployer_ssh" {
  key_name = "deployer_key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "instance" {  
  name        = "instance"
  description = "Allow SSH traffic to instance"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "k3s_master" {
  ami           = "ami-010fae13a16763bb4" # Amazon Linux AMI 2018.03.0 (HVM), 64bit, SSD Volume Type 
  #ami =  ami-0badcc5b522737046 # RedHat 8
  instance_type = "t2.micro"
  
  # no VPC created, just public access
  vpc_security_group_ids      = ["${aws_security_group.instance.id}"]
  associate_public_ip_address = true

  key_name = aws_key_pair.deployer_ssh.key_name # use the above key pair
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host     = self.public_ip
  }

  provisioner "file" {
    source      = "k3s-docker-compose.yml"
    destination = "/tmp/k3s-docker-compose.yml"
  }

  provisioner "file" {
    source      = "install_k3s_master.sh"
    destination = "/tmp/install_k3s_master.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install docker",
      "sudo /etc/init.d/docker start",
      "sudo usermod -G docker,wheel ec2-user"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash /tmp/install_k3s_master.sh",
      "K3S_SERVER_IP=${self.public_ip} K3S_SETUP_SECRET=${var.K3S_SETUP_SECRET} /usr/local/bin/docker-compose -f /tmp/k3s-docker-compose.yml up -d",
      "export KUBECONFIG=/tmp/kubeconfig.yaml",
      "kubectl get nodes"
    ]
  }
}

# resource "aws_security_group" "nodes" {  
#   name        = "nodes"
#   description = "Allow SSH traffic to nodes from master"

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     security_groups = ["${aws_security_group.instance.id}"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_instance" "k3s_node" {
#   ami           = "ami-010fae13a16763bb4" # Amazon Linux AMI 2018.03.0 (HVM), 64bit, SSD Volume Type 
#   instance_type = "t2.micro"
#   key_name = aws_key_pair.deployer_ssh.key_name # use the above key pair
#   count = 2
#   depends_on = [aws_instance.k3s_master]

#   # no VPC created, public access
#   # change later to access only from master, but that requies ssh keys to be uploaded to master
#   vpc_security_group_ids      = ["${aws_security_group.instance.id}"]
#   associate_public_ip_address = true

#   key_name = aws_key_pair.deployer_ssh.key_name # use the above key pair
  
#   connection {
#     type     = "ssh"
#     user     = "ec2-user"
#     private_key = file("~/.ssh/id_rsa")
#     host     = self.public_ip
#   }

#   provisioner "file" {
#     source      = "k3s-docker-compose.yml"
#     destination = "/tmp/k3s-docker-compose.yml"
#   }

#   provisioner "file" {
#     source      = "install_k3s_master.sh"
#     destination = "/tmp/install_k3s_master.sh"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "sudo yum -y install docker",
#       "sudo /etc/init.d/docker start",
#       "sudo usermod -G docker,wheel ec2-user"
#     ]
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "sudo bash /tmp/install_k3s_master.sh",
#       "K3S_SERVER_IP=${self.public_ip} K3S_SETUP_SECRET=${var.K3S_SETUP_SECRET} /usr/local/bin/docker-compose -f /tmp/k3s-docker-compose.yml up -d node",
#       "export KUBECONFIG=/tmp/kubeconfig.yaml",
#       "kubectl get nodes"
#     ]
#   }

# }


output "master_ips" {
  value = ["${aws_instance.k3s_master.*.public_ip}"]
}

# output "instance_ips" {
#   value = ["${aws_instance.k3s_node.*.public_ip}"]
# }
