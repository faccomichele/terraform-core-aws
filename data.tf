# Data source for current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
