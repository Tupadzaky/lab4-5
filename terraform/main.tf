terraform {

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}
resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_security_group" "allow_all" {
  name = "allow_all_traffic"
  description = "Allow all inbound and outbound traffic"
  vpc_id = "vpc-084ace9e1b244b017"
  # Замените на ID вашего VPC

  ingress {
    description = "All traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  tags = {
    Name = "allow_all_traffic"
  }
}
resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Effect = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}
resource "aws_instance" "app_server" {
  ami = "ami-0fe472d8a85bc7b0e"
  instance_type = "t2.micro"
  key_name = "key_new6"
  security_groups = [
    aws_security_group.allow_all.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Updating system..."
sudo yum update -y
echo "Installing Docker..."
sudo yum install docker -y
echo "Starting Docker..."
sudo systemctl start docker
sudo systemctl enable docker

# Проверка, что Docker запущен
echo "Checking Docker status..."
while ! sudo systemctl is-active --quiet docker
do
  echo "Waiting for Docker to start..."
  sleep 2
done
echo "Docker is running."

echo "Pulling Docker images..."
sudo docker pull tanasiienkoanastasia/iit-lab4-5
sudo docker pull containrrr/watchtower

echo "Adding user to Docker group..."
sudo usermod -a -G docker ec2-user

echo "Running Docker containers..."
sudo docker run --rm -d --name lab4-5 -p 80:3000 tanasiienkoanastasia/iit-lab4-5
sudo docker run --rm -d \
--name watchtower \
-v /var/run/docker.sock:/var/run/docker.sock \
containrrr/watchtower \
--interval 10

echo "User data script execution finished."
EOF


  tags = {
    Name = "Lab6"
  }

}
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_role.name
}