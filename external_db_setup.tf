#
# For CircleCI to run efficiently we want a rather large postgreSQL RDS database
#
# For the size we need to consult the sizing documentation. This excerpt pertains to the PostgreSQL size
#
#
#
#
# | Users      | replicas | vCPUs | Memory | Disk Space |  NIC speed  |
# |       <50  |     2    |    8  |   16GB |    100GB   |     1Gbps   |
# |    50-250  |     2    |    8  |   16GB |    200GB   |     1Gbps   |
# |  250-1000  |     3    |    8  |   32GB |    500GB   |    10Gbps   |
# | 1000-5000  |     3    |    8  |  128GB |   1000GB   |    10Gbps   |
# |      5000+ |     3    |    8  |  128GB |   1000GB   |    10Gbps   |
#

#
# Using 'name' instead or 'arn' so that the code does not have to change as accounts change
# It does depend upon the name being the same in all accounts
#
data "aws_secretsmanager_secret" "rds_secret" {
  name = "CircleCI_RDS_Secret"
}

data "aws_secretsmanager_secret_version" "stage-version" {
  secret_id = "${data.aws_secretsmanager_secret.rds_secret.id}"
}

#
# Not sure if leaving these as locals is correct
# But putting them in "vars" doesn't help unless I want to pass in values
# which would require the module that calls this to know about
#

locals {
  postgres-engine   = "postgres"
  postgres_version  = "9.5.18"
  postgres_instance = "db.m4.xlarge"
  postgres_db_name  = "circleci"
  postgres-user     = "postgres"
  postgres-passwd   = jsondecode (data.aws_secretsmanager_secret_version.stage-version.secret_string)["password"]
  postgres-group    = "default.postgres9.5"
}

resource "aws_db_subnet_group" "dbsubnet" {
  name       = "main"
  subnet_ids = var.aws_private_subnet_list
}

resource "aws_db_instance" "cci_postgres" {
  allocated_storage      =  100
  max_allocated_storage  =  500
  iops                   = 1000
  engine                 = local.postgres-engine
  engine_version         = local.postgres_version 
  instance_class         = local.postgres_instance 
  name                   = local.postgres_db_name 
  storage_encrypted      = true
  username               = local.postgres-user
  password               = local.postgres-passwd
  parameter_group_name   = local.postgres-group
  db_subnet_group_name   = aws_db_subnet_group.dbsubnet.name
  skip_final_snapshot    = true
}

#
# For the MongoDB The sizing document contains:
#
#
#| Users     | replicas | vCPUs | Memory | Disk Space |  NIC speed   |
#|      <50  |     3    |    8  |   32GB |    100GB   |    1Gbps     |
#|   50-250  |     3    |   12  |   64GB |    200GB   |    1Gbps     |
#| 1000-5000 |     3    |   20  |  256GB |   1000GB   |   10Gbps     |
#|     5000+ |     3    |   24  |  512GB |   2000GB   |   10Gbps     |

#
# Create primary instance
#

#
# Create replica sets 
# make dependant upon primary instance
#


