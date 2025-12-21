# IAM role for Terraform state access
resource "aws_iam_role" "terraform_state_role" {
  name_prefix        = "${var.project_name}-state-files-${terraform.workspace}-"
  assume_role_policy = <<ASSUME_POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${data.aws_caller_identity.current.account_id}"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
ASSUME_POLICY

  tags = merge(
    local.tags,
    {
      RepositoryFile = "iam.tf"
      Description    = "IAM role for accessing Terraform state files"
    }
  )
}

# IAM policy for Terraform state access
resource "aws_iam_role_policy" "terraform_state_policy" {
  name   = "terraform-state-files-policy"
  role   = aws_iam_role.terraform_state_role.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListObjectsInBucket",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "${aws_s3_bucket.terraform_state.arn}"
    },
    {
      "Sid": "AllObjectActions",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "${aws_s3_bucket.terraform_state.arn}/*"
    }
  ]
}
POLICY
}
