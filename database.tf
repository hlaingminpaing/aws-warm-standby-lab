resource "aws_rds_global_cluster" "global" {
  provider                  = aws.primary
  global_cluster_identifier = "warm-standby-global"
  engine                    = "aurora-mysql"
  engine_version            = "8.0.mysql_aurora.3.04.1"
  database_name             = "appdb"
  storage_encrypted         = true
}

# --- PRIMARY REGION DATABASE ---
resource "aws_db_subnet_group" "primary" {
  provider   = aws.primary
  name       = "primary-db-subnets"
  subnet_ids = module.vpc_primary.private_subnets
}

resource "aws_rds_cluster" "primary" {
  provider                  = aws.primary
  cluster_identifier        = "primary-cluster"
  engine                    = aws_rds_global_cluster.global.engine
  engine_version            = aws_rds_global_cluster.global.engine_version
  global_cluster_identifier = aws_rds_global_cluster.global.id
  db_subnet_group_name      = aws_db_subnet_group.primary.name
  master_username           = "admin"
  master_password           = var.db_master_password
  skip_final_snapshot       = true
}

resource "aws_rds_cluster_instance" "primary" {
  provider           = aws.primary
  count              = 1 # Active region has more capacity
  identifier         = "primary-instance-${count.index}"
  cluster_identifier = aws_rds_cluster.primary.id
  instance_class     = "db.t4g.medium"
  engine             = aws_rds_cluster.primary.engine
  engine_version     = aws_rds_cluster.primary.engine_version
}


# --- STANDBY REGION DATABASE ---
resource "aws_db_subnet_group" "standby" {
  provider   = aws.standby
  name       = "standby-db-subnets"
  subnet_ids = module.vpc_standby.private_subnets
}

resource "aws_rds_cluster" "standby" {
  provider                  = aws.standby
  cluster_identifier        = "standby-cluster"
  engine                    = aws_rds_global_cluster.global.engine
  engine_version            = aws_rds_global_cluster.global.engine_version
  global_cluster_identifier = aws_rds_global_cluster.global.id
  db_subnet_group_name      = aws_db_subnet_group.standby.name
  skip_final_snapshot       = true
  depends_on                = [aws_rds_cluster_instance.primary]
}

resource "aws_rds_cluster_instance" "standby" {
  provider           = aws.standby
  count              = 1 # Standby region has minimal capacity
  identifier         = "standby-instance-${count.index}"
  cluster_identifier = aws_rds_cluster.standby.id
  instance_class     = "db.t4g.medium"
  engine             = aws_rds_cluster.standby.engine
  engine_version     = aws_rds_cluster.standby.engine_version
}
