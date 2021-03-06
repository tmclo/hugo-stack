terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  shared_credentials_file = file("~/.aws/creds")
}

resource "aws_key_pair" "my_key" {
  key_name = "tf_key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_vpc" "hugo" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "hugo-subnet" {
  vpc_id     = aws_vpc.hugo.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "Main"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.hugo.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "hugo-route-table" {
  vpc_id = aws_vpc.hugo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
      ipv6_cidr_block = "::/0"
      gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "hugo route table"
  }
}

resource "aws_route_table_association" "assoc" {
  subnet_id      = aws_subnet.hugo-subnet.id
  route_table_id = aws_route_table.hugo-route-table.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow HTTP(s) inbound traffic"
  vpc_id      = aws_vpc.hugo.id

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

  ## Allow traffic between nodes in the VPC
  ingress {
      description = "All traffic between nodes in VPC"
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = [ "10.0.0.0/8" ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

## Create managers

resource "aws_instance" "docker1" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "a1.medium"
  availability_zone = "eu-west-1a"
  associate_public_ip_address = true
  subnet_id = aws_subnet.hugo-subnet.id
  vpc_security_group_ids = [ aws_security_group.allow_web.id ]
  key_name = aws_key_pair.my_key.key_name

  provisioner "local-exec" {
    command = "echo ${aws_instance.docker1.public_ip} >> ./ips"
  }

  tags = {
    Name = "Docker1-swarm"
  }
}

## Create workers

resource "aws_instance" "docker2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "a1.medium"
  availability_zone = "eu-west-1a"
  associate_public_ip_address = true
  subnet_id = aws_subnet.hugo-subnet.id
  vpc_security_group_ids = [ aws_security_group.allow_web.id ]
  key_name = aws_key_pair.my_key.key_name

  provisioner "local-exec" {
    command = "echo ${aws_instance.docker2.public_ip} >> ./ips"
  }

  tags = {
    Name = "Docker2-swarm"
  }
}

## Create Block Volume for web storage
resource "aws_ebs_volume" "hugostorage" {
  availability_zone = "eu-west-1a"
  size              = 20
  type              = "io1"
  multi_attach_enabled = true
  iops              = 1000

  tags = {
    Name = "Hugo Storage"
  }
}

resource "aws_volume_attachment" "ebs_att1" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.hugostorage.id
  instance_id = aws_instance.docker1.id

  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file("~/.ssh/id_ed25519")
    host     = aws_instance.docker1.public_ip
  }

  provisioner "file" {
    source      = "scripts/ebs-mount.sh"
    destination = "/tmp/ebs-mount.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/ebs-mount.sh",
      "sudo /tmp/ebs-mount.sh",
    ]
  }
}

resource "aws_volume_attachment" "ebs_att2" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.hugostorage.id
  instance_id = aws_instance.docker2.id

  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file("~/.ssh/id_ed25519")
    host     = aws_instance.docker2.public_ip
  }

  provisioner "file" {
    source      = "scripts/ebs-mount.sh"
    destination = "/tmp/ebs-mount.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/ebs-mount.sh",
      "sudo /tmp/ebs-mount.sh",
    ]
  }
}

output "docker1-ip" {
  value = "${aws_instance.docker1.public_ip}"
}

output "docker2-ip" {
  value = "${aws_instance.docker2.public_ip}"
}
