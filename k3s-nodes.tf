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
  description = "Allow SSH, 6433 k3s and ping traffic to instance"

  ingress { # allow ssh from anywhere
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {  # allow connect to port 6443 from anywhere
    from_port   = 0
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # allow ping from everywhere
    from_port   = 1
    to_port     = 1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { # allow all outgoing traffic, all protocols
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

  private_ip = "172.31.41.100"
  
  # allow all incomming SSH traffic
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
      "K3S_SERVER_IP=${self.private_ip} K3S_SETUP_SECRET=${var.K3S_SETUP_SECRET} /usr/local/bin/docker-compose -f /tmp/k3s-docker-compose.yml up -d",
      "mkdir -p ~/.kube",
      "sleep 20; cp /tmp/kubeconfig.yaml ~/.kube/config",
      "kubectl get nodes"
    ]
  }
}


resource "aws_instance" "k3s_node" {
  ami           = "ami-010fae13a16763bb4" # Amazon Linux AMI 2018.03.0 (HVM), 64bit, SSD Volume Type 
  instance_type = "t2.micro"
  key_name = aws_key_pair.deployer_ssh.key_name # use the above key pair
  count = 1
  depends_on = [aws_instance.k3s_master]
  private_ip = "172.31.41.110"


  # allow all incomming SSH traffic
  # change later to access only from master, but that requies ssh keys to be uploaded to master
  vpc_security_group_ids      = ["${aws_security_group.instance.id}"]
  associate_public_ip_address = true
  
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
      "K3S_SERVER_IP=${aws_instance.k3s_master.private_ip} K3S_SETUP_SECRET=${var.K3S_SETUP_SECRET} /usr/local/bin/docker-compose -f /tmp/k3s-docker-compose.yml up -d node"
    ]
  }

}


output "master_pub_ips" {
  value = ["${aws_instance.k3s_master.*.public_ip}"]
}

output "instance_pub_ips" {
  value = ["${aws_instance.k3s_node.*.public_ip}"]
}

output "master_prv_ips" {
  value = ["${aws_instance.k3s_master.*.private_ip}"]
}

output "instance_prv_ips" {
  value = ["${aws_instance.k3s_node.*.private_ip}"]
}
