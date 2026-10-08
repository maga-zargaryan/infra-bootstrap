locals {
  iam_arn_prefix = "arn:${local.partition}:iam::${local.account_id}"
  zone_arn       = "arn:${local.partition}:route53:::hostedzone/${var.route53_zone_id}"

  # IAM names each repository may create. Every role it creates must carry the permissions boundary.
  deploy_iam = {
    platform = { prefix = "java-platform-network-", pass_to = ["vpc-flow-logs.amazonaws.com"] }
    ami      = { prefix = "java-ami-", pass_to = ["ec2.amazonaws.com", "imagebuilder.amazonaws.com"] }
    workload = { prefix = "java-workload-", pass_to = ["ec2.amazonaws.com"] }
  }

  service_linked_roles = [
    "autoscaling.amazonaws.com",
    "elasticfilesystem.amazonaws.com",
    "elasticloadbalancing.amazonaws.com",
    "imagebuilder.amazonaws.com",
    "rds.amazonaws.com",
  ]
}

# Caps every role created by CI: no IAM, Organizations or audit tampering, whatever policy is attached.
data "aws_iam_policy_document" "workload_boundary" {
  statement {
    sid       = "AllowServiceActions"
    actions   = ["*"]
    resources = ["*"]
  }

  statement {
    sid    = "DenyPrivilegeEscalation"
    effect = "Deny"
    actions = [
      "iam:*",
      "organizations:*",
      "account:*",
      "sts:AssumeRole",
      "cloudtrail:DeleteTrail",
      "cloudtrail:StopLogging",
      "cloudtrail:UpdateTrail",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "workload_boundary" {
  name        = "java-platform-permissions-boundary"
  description = "Permissions boundary required on every IAM role created by the platform pipelines."
  policy      = data.aws_iam_policy_document.workload_boundary.json
}

data "aws_iam_policy_document" "deploy_iam" {
  for_each = local.deploy_iam

  statement {
    sid = "ManageBoundedRoles"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePermissionsBoundary",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
    ]
    resources = ["${local.iam_arn_prefix}:role/${each.value.prefix}*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.workload_boundary.arn]
    }
  }

  statement {
    sid = "ManageOwnRoles"
    actions = [
      "iam:DeleteRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy",
    ]
    resources = ["${local.iam_arn_prefix}:role/${each.value.prefix}*"]
  }

  statement {
    sid = "ManageOwnInstanceProfiles"
    actions = [
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
    ]
    resources = ["${local.iam_arn_prefix}:instance-profile/${each.value.prefix}*"]
  }

  statement {
    sid = "ManageOwnPolicies"
    actions = [
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = ["${local.iam_arn_prefix}:policy/${each.value.prefix}*"]
  }

  statement {
    sid       = "PassOwnRoles"
    actions   = ["iam:PassRole"]
    resources = ["${local.iam_arn_prefix}:role/${each.value.prefix}*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = each.value.pass_to
    }
  }

  statement {
    sid       = "CreateServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = local.service_linked_roles
    }
  }
}

data "aws_iam_policy_document" "deploy_platform" {
  source_policy_documents = [data.aws_iam_policy_document.deploy_iam["platform"].json]

  statement {
    sid = "Networking"
    actions = [
      "ec2:*Vpc*",
      "ec2:*Subnet*",
      "ec2:*RouteTable*",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:ReplaceRoute",
      "ec2:*InternetGateway*",
      "ec2:*SecurityGroup*",
      "ec2:*NetworkAcl*",
      "ec2:*FlowLogs",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["*"]
  }

  statement {
    sid = "KeyManagement"
    actions = [
      "kms:CreateKey",
      "kms:CreateAlias",
      "kms:UpdateAlias",
      "kms:DeleteAlias",
      "kms:EnableKeyRotation",
      "kms:DisableKeyRotation",
      "kms:UpdateKeyDescription",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
    ]
    resources = ["*"]
  }

  statement {
    sid = "Certificates"
    actions = [
      "acm:RequestCertificate",
      "acm:DeleteCertificate",
      "acm:AddTagsToCertificate",
      "acm:RemoveTagsFromCertificate",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DnsRecords"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [local.zone_arn]
  }

  statement {
    sid = "DatabaseSubnetGroups"
    actions = [
      "rds:CreateDBSubnetGroup",
      "rds:ModifyDBSubnetGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource",
    ]
    resources = ["arn:${local.partition}:rds:${var.aws_region}:${local.account_id}:subgrp:java-platform-*"]
  }

  statement {
    sid = "PublishParameters"
    actions = [
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:DeleteParameters",
      "ssm:AddTagsToResource",
      "ssm:RemoveTagsFromResource",
    ]
    resources = ["arn:${local.partition}:ssm:${var.aws_region}:${local.account_id}:parameter/java-platform/*"]
  }

  statement {
    sid = "FlowLogGroups"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:AssociateKmsKey",
      "logs:DisassociateKmsKey",
      "logs:TagResource",
      "logs:UntagResource",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
    ]
    resources = ["arn:${local.partition}:logs:${var.aws_region}:${local.account_id}:log-group:/java-platform/*"]
  }
}

data "aws_iam_policy_document" "deploy_ami" {
  source_policy_documents = [data.aws_iam_policy_document.deploy_iam["ami"].json]

  statement {
    sid       = "ImageBuilder"
    actions   = ["imagebuilder:*"]
    resources = ["*"]
  }

  # Teardown: AMIs are only deregistered when tagged as platform images.
  statement {
    sid       = "AmiCleanup"
    actions   = ["ec2:DeregisterImage"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = ["java-platform"]
    }
  }

  statement {
    sid       = "AmiSnapshotCleanup"
    actions   = ["ec2:DeleteSnapshot"]
    resources = ["arn:${local.partition}:ec2:${var.aws_region}::snapshot/*"]
  }
}

data "aws_iam_policy_document" "deploy_workload" {
  source_policy_documents = [data.aws_iam_policy_document.deploy_iam["workload"].json]

  statement {
    sid = "Compute"
    actions = [
      "autoscaling:*",
      "elasticloadbalancing:*",
      "ec2:*LaunchTemplate*",
      "ec2:RunInstances",
      "ec2:*SecurityGroup*",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["*"]
  }

  statement {
    sid = "DataStores"
    actions = [
      "rds:*",
      "elasticfilesystem:*",
      "backup:*",
      "backup-storage:MountCapsule",
    ]
    resources = ["*"]
  }

  # EFS automatic backups run under the account's AWS Backup default role.
  statement {
    sid       = "PassBackupRole"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.backup_default.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["backup.amazonaws.com"]
    }
  }

  # RDS stores and rotates the managed master password in Secrets Manager on the caller's behalf.
  statement {
    sid = "ManagedDatabaseSecret"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:TagResource",
      "secretsmanager:RotateSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecret",
    ]
    resources = ["arn:${local.partition}:secretsmanager:${var.aws_region}:${local.account_id}:secret:rds!*"]
  }

  statement {
    sid = "UsePlatformKeys"
    actions = [
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]
    resources = ["*"]

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "kms:ResourceAliases"
      values   = ["alias/java-platform-*"]
    }
  }

  statement {
    sid       = "WebFirewall"
    actions   = ["wafv2:*"]
    resources = ["*"]
  }

  # Runtime settings the app AMI reads at boot (DB host, secret ARN, EFS IDs, ...).
  statement {
    sid = "AppRuntimeParameters"
    actions = [
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:DeleteParameters",
      "ssm:AddTagsToResource",
      "ssm:RemoveTagsFromResource",
    ]
    resources = ["arn:${local.partition}:ssm:${var.aws_region}:${local.account_id}:parameter/java-platform/*/app/*"]
  }

  statement {
    sid       = "DnsRecords"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [local.zone_arn]
  }

  statement {
    sid = "Observability"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:AssociateKmsKey",
      "logs:DisassociateKmsKey",
      "logs:TagResource",
      "logs:UntagResource",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
      "logs:CreateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:PutResourcePolicy",
      "logs:DeleteResourcePolicy",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
      "sns:Unsubscribe",
      "sns:TagResource",
      "sns:UntagResource",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AccessLogBuckets"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:PutBucket*",
      "s3:DeleteBucketPolicy",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
    ]
    resources = ["arn:${local.partition}:s3:::java-workload-*"]
  }

  # Emptying non-production log buckets on teardown.
  statement {
    sid       = "AccessLogObjects"
    actions   = ["s3:DeleteObject", "s3:DeleteObjectVersion"]
    resources = ["arn:${local.partition}:s3:::java-workload-*/*"]
  }
}

locals {
  deploy_policy_json = {
    platform = data.aws_iam_policy_document.deploy_platform.json
    ami      = data.aws_iam_policy_document.deploy_ami.json
    workload = data.aws_iam_policy_document.deploy_workload.json
  }
}

resource "aws_iam_policy" "deploy" {
  for_each = local.deploy_policy_json

  name        = "github-actions-deploy-${each.key}"
  description = "Write permissions for the ${var.repositories[each.key].name} deployment pipeline."
  policy      = each.value
}
