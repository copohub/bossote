provider "aws" {
  region = "us-east-1"
}
resource "aws_vpc" "terravpc" {
  cidr_block = "172.31.0.0/16"
}

resource "aws_subnet" "uno" {
  vpc_id     = aws_vpc.terravpc.id
  cidr_block = "172.31.0.0/20"
  tags = {
    Name = "uno"
  }
}

resource "aws_subnet" "dos" {
  vpc_id     = aws_vpc.terravpc.id
  cidr_block = "172.31.32.0/20"
  tags = {
    Name = "dos"
  }
}

resource "aws_security_group" "app_secgrp" {
  name        = "app_secgrp"
  description = "Security Group APP Services"
  vpc_id      = aws_vpc.terravpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mongodb_secgrp" {
  name        = "mongodb_secgrp"
  description = "Security group for MongoDB instance"
  vpc_id      = aws_vpc.terravpc.id

  ingress {
    from_port   = 27017
    to_port     = 27017
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
}

resource "aws_instance" "mongodb_instance" {
  ami                      = var.ami
  instance_type            = var.instance_type
  vpc_security_group_ids   = [aws_security_group.mongodb_secgrp.id]
  subnet_id                = aws_subnet.uno.id

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get install gnupg curl
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
    echo "deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org
    sudo systemctl start mongod
    sudo systemctl status mongod
    sudo systemctl enable mongod
    sudo ufw allow 27017
    sudo sed -i "s/\(bindIp: .*\)/bindIp: 0.0.0.0/" /etc/mongod.conf
    sudo systemctl restart mongod
    sleep 30
  EOF

  key_name = var.key_name

  tags = {
    Name = var.tag_name_mongo
  }
}

resource "aws_instance" "nodejs_instance1" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids   = [aws_security_group.app_secgrp.id]
  #vpc_security_group_ids = [aws_security_group.nodejs_secgrp.id]
  #subnet_id        = "subnet-0c5f3116a708e81d8"
  subnet_id     = "subnet-0a40f637b55588c8d"
  associate_public_ip_address = true
  # NODEJS
  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y curl
    curl -sL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
    sudo npm install pm2@latest -g
    app_dir="/home/ubuntu/app"
    app_file="$app_dir/index.js"
    mkdir -p "$app_dir"
    cat > "$app_file" <<EOL
    const express = require('express');
    const mongoose = require('mongoose');
    const app = express();
    mongoose.connect('mongodb://${aws_instance.mongodb_instance.private_ip}:27017/todolist', { useNewUrlParser: true, useUnifiedTopology: true });
    const todoSchema = new mongoose.Schema({ task: String });
    const Todo = mongoose.model('Todo', todoSchema);
    app.post('/newtodo', async (req, res) => {
      const newTodo = new Todo({ task: 'Sample Todo' });
      await newTodo.save();
      res.send('Todo added successfully');
    });
    app.get('/', async (req, res) => {
      const todos = await Todo.find();
      res.json(todos);
    });
    app.listen(3000, () => {
      console.log('Server running on port 3000');
    });
    EOL
    pm2 start "$app_file" --name indexjs
    pm2 save
    sudo pm2 startup
  EOF

  key_name = var.key_name

  tags = {
    Name = var.tag_name_nodejs
  }

  # Use the remote-exec provisioner to run commands on the instance
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.key_path)
    timeout     = "2m"
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "echo '${file("./nginx")}' > /home/ubuntu/nginx",
      "sudo apt install -y nginx",
      "sudo mv /home/ubuntu/nginx /etc/nginx/sites-available/nginx",
      "cd /etc/nginx/sites-available/",
      "sudo ln -s /etc/nginx/sites-available/nginx /etc/nginx/sites-enabled/nginx",
      "sudo systemctl restart nginx"
    ]
  }
}