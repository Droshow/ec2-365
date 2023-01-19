#!/bin/bash
{{/* install ssm  */}}
sudo mkdir /tmp/ssm
cd /tmp/ssm
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
sudo dpkg -i amazon-ssm-agent.deb
sudo systemctl enable amazon-ssm-agent
rm amazon-ssm-agent.deb

{{/* install nginx */}}
sudo yum update -y
sudo yum install -y nginx
sudo service nginx start
echo "Hello World" > /var/www/html/index.html