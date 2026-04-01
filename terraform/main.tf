resource "aws_vpc" "main" {

  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.environment}-vpc"
  }
}


resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-igw"
  }

}


resource "aws_subnet" "main_subnet" {

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-subnet"
  }

}


resource "aws_route_table" "public_rt" {

  vpc_id = aws_vpc.main.id

  route {

    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id

  }

  tags = {
    Name = "${var.environment}-public-rt"
  }

}


resource "aws_route_table_association" "public_assoc" {

  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.public_rt.id

}


resource "aws_security_group" "node_sg" {

  name   = "${var.environment}-node-sg"
  vpc_id = aws_vpc.main.id

  ingress {

    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

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

  tags = {
    Name = "${var.environment}-node-sg"
  }

}


resource "aws_iam_role" "ec2_role" {

  name = "${var.environment}-ec2-role"

  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [{

      Action = "sts:AssumeRole"
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

    }]

  })

}


resource "aws_iam_role_policy_attachment" "ec2_policy" {

  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

}


resource "aws_iam_instance_profile" "ec2_profile" {

  name = "${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name

}


resource "aws_instance" "node_server" {

  ami           = "ami-0c3389a4fa5bddaad"
  instance_type = var.instance_type

  subnet_id = aws_subnet.main_subnet.id

  vpc_security_group_ids = [
    aws_security_group.node_sg.id
  ]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y

              # Install NodeJS
              curl -sL https://rpm.nodesource.com/setup_18.x | bash -
              yum install -y nodejs git

              # Clone your repository
              cd /home/ec2-user
              git clone https://github.com/MukarramRepository/nodejs-cicd.git

              cd nodejs-cicd

              npm install

              # Start application
              nohup node app.js > app.log 2>&1 &
              EOF

  tags = {
    Name = "${var.environment}-node-app"
  }

}


resource "aws_secretsmanager_secret" "node_secret" {

  name = "${var.environment}-nodejs-app-secret"

}


resource "aws_secretsmanager_secret_version" "secret_value" {

  secret_id = aws_secretsmanager_secret.node_secret.id

  secret_string = jsonencode({
    DB_PASSWORD = "mypassword"
  })

}