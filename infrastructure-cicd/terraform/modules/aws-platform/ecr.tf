module "ecr" {
  source = "../ecr"

  repository_name = var.app_name
  scan_on_push    = true
}
