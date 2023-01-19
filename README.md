# ec2-365
In this tutorial simple EC2 instance is created using ami linux-amazon. It is deployed using Terraform .
For VPC is used Babenko's module, but optionally it can be used through aws_resources. Only public subnet is created and using access through internet gateway. 
There is a security group allowing ingress for port 80, so Nginx can be accessed on this instance. 

SSM role was introduced, so there could be a connection on this EC2.

