resource "aws_db_subnet_group" "db" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = aws_subnet.db[*].id
}

resource "aws_db_instance" "db" {
  identifier        = "${var.project_name}-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = "admin"
  # Password is generated and stored in Secrets Manager automatically
  manage_master_user_password = true

  multi_az               = true # automatic failover to standby in the 2nd AZ
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  backup_retention_period = 7
  skip_final_snapshot     = true # demo only; set false in production
  deletion_protection     = false
}
