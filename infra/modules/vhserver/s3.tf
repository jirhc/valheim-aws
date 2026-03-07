#tfsec:ignore:AWS002
resource "aws_s3_bucket" "valheim" {
  bucket_prefix = local.name
}

resource "aws_s3_bucket_ownership_controls" "valheim" {
  bucket = aws_s3_bucket.valheim.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# WARNING Can cost a lot
resource "aws_s3_bucket_versioning" "valheim" {
  bucket = aws_s3_bucket.valheim.id
  versioning_configuration {
    status = "Enabled"
  }
}

## encryption
# resource "aws_s3_bucket_server_side_encryption_configuration" "valheim" {
#   bucket = aws_s3_bucket.valheim.bucket

#   rule {
#     apply_server_side_encryption_by_default {
#       # kms_master_key_id = aws_kms_key.mykey.arn
#       sse_algorithm     = "aws:kms"
#     }
#   }
# }

resource "aws_s3_bucket_policy" "valheim" {
  bucket = aws_s3_bucket.valheim.id
  policy = jsonencode({
    Version : "2012-10-17",
    Id : "PolicyForValheimBackups",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          "AWS" : aws_iam_role.valheim.arn
        },
        Action : [
          "s3:Put*",
          "s3:Get*",
          "s3:List*"
        ],
        Resource : "arn:aws:s3:::${aws_s3_bucket.valheim.id}/*"
      }
    ]
  })

  // https://github.com/hashicorp/terraform-provider-aws/issues/7628
  depends_on = [aws_s3_bucket_public_access_block.valheim]
}

resource "aws_s3_bucket_public_access_block" "valheim" {
  bucket = aws_s3_bucket.valheim.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###########################################################
## install_valheim  (plain script — no Terraform template vars)

resource "aws_s3_object" "install_valheim" {
  bucket      = aws_s3_bucket.valheim.id
  key         = "/install_valheim.sh"
  source      = "${path.module}/local/install_valheim.sh"
  source_hash = filebase64sha256("${path.module}/local/install_valheim.sh")
}

###########################################################
## bootstrap_valheim

locals {
  bootstrap_valheim = templatefile("${path.module}/local/bootstrap_valheim.sh", {
    username         = local.username
    bucket           = aws_s3_bucket.valheim.id
    use_domain       = var.domain != "" ? true : false
    world_name       = var.world_name
    server_name      = var.server_name
    server_password  = var.server_password
    server_port      = "2456"
    enable_bepinex   = var.enable_bepinex
    bepinex_version  = "5.4.23.2"
    enable_crossplay = var.enable_crossplay
  })
}

resource "aws_s3_object" "bootstrap_valheim" {
  bucket      = aws_s3_bucket.valheim.id
  key         = "/bootstrap_valheim.sh"
  content     = local.bootstrap_valheim
  source_hash = base64sha256(local.bootstrap_valheim)
}

###########################################################
## start_valheim  (plain script — no Terraform template vars)

resource "aws_s3_object" "start_valheim" {
  bucket      = aws_s3_bucket.valheim.id
  key         = "/start_valheim.sh"
  source      = "${path.module}/local/start_valheim.sh"
  source_hash = filebase64sha256("${path.module}/local/start_valheim.sh")
}

###########################################################
## backup_valheim

locals {
  backup_valheim = templatefile("${path.module}/local/backup_valheim.sh", {
    username   = local.username
    bucket     = aws_s3_bucket.valheim.id
    world_name = var.world_name
  })
}

resource "aws_s3_object" "backup_valheim" {
  bucket = aws_s3_bucket.valheim.id
  key    = "/backup_valheim.sh"
  content = local.backup_valheim
  source_hash = base64sha256(local.backup_valheim)
}

###########################################################
## crontab

locals {
  crontab = templatefile("${path.module}/local/crontab", { username = local.username })
}

resource "aws_s3_object" "crontab" {
  bucket         = aws_s3_bucket.valheim.id
  key            = "/crontab"
  content = local.crontab
  source_hash = base64sha256(local.crontab)
}

###########################################################
## valheim_service

locals {
  valheim_service = templatefile("${path.module}/local/valheim.service", { username = local.username })
}

resource "aws_s3_object" "valheim_service" {
  bucket         = aws_s3_bucket.valheim.id
  key            = "/valheim.service"
  content = local.valheim_service
  source_hash = base64sha256(local.valheim_service)
}

###########################################################
## admin_list (TO BE REMOVED???)

locals {
  admin_list = templatefile("${path.module}/local/adminlist.txt", { admins = values(var.admins) })
}

resource "aws_s3_object" "admin_list" {
  bucket         = aws_s3_bucket.valheim.id
  key            = "/adminlist.txt"
  content = local.admin_list
  source_hash = base64sha256(local.admin_list)
}

###########################################################
## update_cname_json

locals {
  update_cname_json = templatefile("${path.module}/local/update_cname.json", { fqdn = format("%s%s", "valheim.", var.domain) })
}

resource "aws_s3_object" "update_cname_json" {
  count = var.domain != "" ? 1 : 0

  bucket         = aws_s3_bucket.valheim.id
  key            = "/update_cname.json"
  content = local.update_cname_json
  source_hash = base64sha256(local.update_cname_json)
}

###########################################################
## update_cname

## DO NOT WORK WITH LOCAL DUE TO data.aws_route53_zone.selected[0].zone_id
# locals {
#   update_cname = templatefile("${path.module}/local/update_cname.sh", {
#     username   = local.username
#     aws_region = var.aws_region
#     bucket     = aws_s3_bucket.valheim.id
#     zone_id    = data.aws_route53_zone.selected[0].zone_id
#   })
# }

resource "aws_s3_object" "update_cname" {
  count = var.domain != "" ? 1 : 0

  bucket = aws_s3_bucket.valheim.id
  key    = "/update_cname.sh"
  content = templatefile("${path.module}/local/update_cname.sh", {
    username   = local.username
    aws_region = var.aws_region
    bucket     = aws_s3_bucket.valheim.id
    zone_id    = data.aws_route53_zone.selected[0].zone_id
  })
  source_hash = base64sha256(templatefile("${path.module}/local/update_cname.sh", {
    username   = local.username
    aws_region = var.aws_region
    bucket     = aws_s3_bucket.valheim.id
    zone_id    = data.aws_route53_zone.selected[0].zone_id
  }))
}

###########################################################
## world_db

resource "aws_s3_object" "world_db" {
  count          = var.initial_world_name != "" ? 1 : 0

  bucket         = aws_s3_bucket.valheim.id
  key            = "${var.initial_world_name}.db"
  source         = "${var.initial_world_path}/${var.initial_world_name}.db"
  source_hash    = filebase64sha256("${var.initial_world_path}/${var.initial_world_name}.db")
}

###########################################################
## world_fwl

resource "aws_s3_object" "world_fwl" {
  count          = var.initial_world_name != "" ? 1 : 0

  bucket         = aws_s3_bucket.valheim.id
  key            = "${var.initial_world_name}.fwl"
  source         = "${var.initial_world_path}/${var.initial_world_name}.fwl"
  source_hash    = filebase64sha256("${var.initial_world_path}/${var.initial_world_name}.fwl")
}

