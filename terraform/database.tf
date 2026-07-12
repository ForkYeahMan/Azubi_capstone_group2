# ---------------------------------------------------------------------------
# Aurora PostgreSQL Serverless v2 (scale-to-zero)
# Mirrors: database-1 / database-1-instance-1
#
# WARNING: `terraform destroy` deletes this cluster. With min capacity = 0 the
# cluster already auto-pauses when idle (near-zero cost), so you usually do NOT
# need to destroy it to save money. Prefer leaving enable_database = true and
# letting it pause. If you do destroy, keep db_skip_final_snapshot = false to
# retain a restorable snapshot.
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "aurora" {
  count      = var.enable_database ? 1 : 0
  name       = "${var.project}-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id
  tags       = { Name = "${var.project}-db-subnet-group" }
}

resource "aws_security_group" "db" {
  count       = var.enable_database ? 1 : 0
  name        = "${var.project}-db-sg"
  description = "Allow PostgreSQL from the app SG"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-db-sg" }
}

resource "aws_security_group_rule" "db_ingress" {
  count                    = var.enable_database ? 1 : 0
  security_group_id        = aws_security_group.db[0].id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  description              = "PostgreSQL from app instances"
}

resource "aws_rds_cluster" "aurora" {
  count                   = var.enable_database ? 1 : 0
  cluster_identifier      = "database-1"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "17.7"
  master_username         = var.db_master_username
  master_password         = var.db_master_password
  db_subnet_group_name    = aws_db_subnet_group.aurora[0].name
  vpc_security_group_ids  = [aws_security_group.db[0].id]
  port                    = 5432
  storage_encrypted       = false
  backup_retention_period = 1

  serverlessv2_scaling_configuration {
    min_capacity             = var.db_min_capacity
    max_capacity             = var.db_max_capacity
    seconds_until_auto_pause = 300
  }

  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "database-1-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  lifecycle {
    # master_password is set out-of-band in the live account; ignore drift and
    # avoid accidental replacement on timestamp changes.
    ignore_changes = [final_snapshot_identifier]
  }
}

resource "aws_rds_cluster_instance" "aurora" {
  count              = var.enable_database ? 1 : 0
  identifier         = "database-1-instance-1"
  cluster_identifier = aws_rds_cluster.aurora[0].id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora[0].engine
  engine_version     = aws_rds_cluster.aurora[0].engine_version
}
