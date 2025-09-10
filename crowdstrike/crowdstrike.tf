#variable "ar_region" { type = string }
#variable "ar_repo" { type = string }
variable "cluster" { type = string }
variable "cluster_zones" { type = string }
variable "project_id" { type = string }
variable "build_project_id" { type = string }
variable "tier" { type = string }
variable "region" { type = string }

resource "null_resource" "crowdstrike" {
  triggers  = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = <<EOT
      export cluster=${var.cluster}
      export cluster_zones=${var.cluster_zones}
      export project_id=${var.project_id}
      export tier=${var.tier}
      export region=${var.region}
      export BUILD_PROJECT=${var.build_project_id}
      bash ../../crowdstrike/crowdstrike.sh
    EOT
  }
}
