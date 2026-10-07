# Amazon Linux 2023 AMI used by both EC2 tiers.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Nginx web servers run in private subnets.
# Internet traffic reaches them only through the public ALB.
resource "aws_instance" "web" {
  count = 2

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.web_instance_type
  subnet_id     = aws_subnet.web[count.index].id

  vpc_security_group_ids = [
    aws_security_group.web.id
  ]

  user_data = templatefile("${path.module}/user-data/web.sh.tftpl", {
    index_html = file("${path.module}/../app/web/index.html")

    nginx_conf = replace(
      file("${path.module}/../app/web/nginx.conf.template"),
      "$${APP_ALB_DNS}",
      aws_lb.app.dns_name
    )
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-web-${count.index + 1}"
    Tier = "web"
  }
}

# Node.js application servers run in private application subnets.
# They are reachable only through the internal application ALB.
resource "aws_instance" "app" {
  count = 2

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.app_instance_type
  subnet_id     = aws_subnet.app[count.index].id

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  user_data = templatefile("${path.module}/user-data/app.sh.tftpl", {
    package_json = file("${path.module}/../app/api/package.json")
    db_js        = file("${path.module}/../app/api/db.js")
    server_js    = file("${path.module}/../app/api/server.js")
    schema_sql   = file("${path.module}/../app/api/schema.sql")

    database_host     = aws_db_instance.database.address
    database_password = var.database_password
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-app-${count.index + 1}"
    Tier = "application"
  }
}
