# modules/compute/main.tf

# EC2 Instance Configuration for Bastion Hosts
resource "aws_instance" "bastion" {
  count         = length(var.public_subnet_ids)
  ami           = var.bastion_ami
  instance_type = var.instance_type_bastion
  subnet_id     = var.public_subnet_ids[count.index]
  key_name      = var.key_name

  vpc_security_group_ids = [var.bastion_security_group_id]

  tags = {
    Name = "${var.bastion_name}-${count.index}"
  }
}

# EC2 Instance Configuration for Application Servers
resource "aws_instance" "app" {
  count         = length(var.private_subnet_ids)
  ami           = var.app_ami
  instance_type = var.instance_type_app
  subnet_id     = var.private_subnet_ids[count.index]
  key_name      = var.key_name

  vpc_security_group_ids = [var.app_security_group_id]

  user_data = base64encode(templatefile(var.deploy_script_path, {
    rds_address = var.rds_address
    db_username = var.db_username
    db_password = var.db_password
    docker_user = var.dockerhub_username
    docker_pass = var.dockerhub_password
    docker_compose = templatefile(var.compose_template_path, {
      rds_address = var.rds_address
      db_username = var.db_username
      db_password = var.db_password
    })
  }))

  depends_on = []

  tags = {
    Name = "${var.app_name}-${count.index}"
  }
}
