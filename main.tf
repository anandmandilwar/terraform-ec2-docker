data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}


data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

#===================================================
# Below resource is to create public and private key
#===================================================

resource "tls_private_key" "DemoPrivateKey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.aws_public_key_name}"
  public_key = tls_private_key.DemoPrivateKey.public_key_openssh
}

resource "aws_iam_role" "ec2_role_hello_world" {
  name = "ec2_role_hello_world"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    project = "hello-world"
  }
}

resource "aws_iam_instance_profile" "ec2_profile_hello_world" {
  name = "ec2_profile_hello_world"
  role = aws_iam_role.ec2_role_hello_world.name
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"
  key_name  = aws_key_pair.generated_key.key_name
  root_block_device {
    volume_size = 8
  }

  user_data = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
  EOF

  vpc_security_group_ids = [aws_security_group.kafkaclient_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile_hello_world.name

  tags = {
    project = "hello-world"
  }

  monitoring              = true
  disable_api_termination = false
  ebs_optimized           = true
}


#=================================
# Security Group for Kafka Client
#=================================
resource "aws_security_group" "kafkaclient_sg" {
  name        = "Security Groups for Kafka Client"
  description = "Allow SSH access to Kafka Client from Cloud9 and outbound internet access"
  vpc_id      = data.aws_vpc.default.id
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "KafkaClient_sg_terraform"
  }
}

#----------------------------
# inbound for Kafka Client SG
#----------------------------
resource "aws_security_group_rule" "ssh" {
  protocol          = "TCP"
  from_port         = 22
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kafkaclient_sg.id
}

resource "aws_security_group_rule" "KafkaConnect" {
  protocol          = "TCP"
  from_port         = 8081
  to_port           = 8083
  type              = "ingress"
  source_security_group_id = aws_security_group.kafkaclient_sg.id
  security_group_id = aws_security_group.kafkaclient_sg.id
}


#-----------------------------
# Outbound for Kafka Client SG
#-----------------------------
resource "aws_security_group_rule" "internet" {
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kafkaclient_sg.id
}