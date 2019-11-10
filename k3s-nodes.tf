# auth provided in environment variables
# https://www.terraform.io/docs/providers/aws/index.html
provider "aws" {}

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

  provisioner "remote-exec" {
    inline = [
      "sudo pip install ansible",
      "ansible --help"
    ]
  }

  
}

# resource "aws_instance" "k3s_node" {
#   ami           = "ami-010fae13a16763bb4" # Amazon Linux AMI 2018.03.0 (HVM), 64bit, SSD Volume Type 
#   instance_type = "t2.micro"
#   key_name = aws_key_pair.deployer_ssh.key_name # use the above key pair
#   count = 2
#   depends_on = [aws_instance.k3s_master]
# }


output "instance_ips" {
  value = ["${aws_instance.k3s_master.*.public_ip}"]
}
