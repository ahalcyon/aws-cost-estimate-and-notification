provider "aws" {
  # Cost Explorer APIはus-east-1にしかないため、プロバイダーのリージョンを固定します。
  # Step FunctionsやSNSトピックなどのリソースが作成されるリージョンでもあります。
  region = "us-east-1"
}

module "cost_watcher" {
  source = "./module"

  recipient_email       = var.recipient_email
  batch_schedule        = var.batch_schedule
  batch_timezone        = var.batch_timezone
}
