terraform {
  backend "gcs" {
    prefix = "states"
  }
}

locals {
  gcp_project = "zac-02-d"
  dev_gcp_project = "zac-01-pp-d"
}

provider "google" {
  # Change this according to project name, and region required.
  project = local.gcp_project
  region = "us-east1"
}

resource "google_project_iam_member" "tiger-devs-container-developer" {
  project = local.gcp_project
  role               = "roles/container.developer"
  member             = "group:gcds-tiger-devs@zebra.com"
}

data "google_service_account" "zc-tiger-sa" {
  project = local.dev_gcp_project
  account_id   = "zac-tiger-sa"
}

resource "google_iap_web_iam_member" "zc-group-iap-binding" {
  project = local.gcp_project
  role = "roles/iap.httpsResourceAccessor"
  member = "serviceAccount:${data.google_service_account.zc-tiger-sa.email}"
}

#BUILD_PROJECT="zac-01-pp-d"
#
#cluster="zac-dev"
#project_id="zac-01-pp-d"
#cluster_zones="us-east1"
#region="us-east1"

module "crowdstrike" {
  source = "../../crowdstrike"
#  ar_region             = var.ar_region
#  ar_repo               = var.artifact_repository_id
  cluster               = "langfuse"
  cluster_zones         = "us-east1"
#  depends_on            = [ module.langfuse ]
  project_id            = local.gcp_project
  build_project_id      = local.dev_gcp_project
  tier                  = "dev"
  region                = "us-east1"
}

module "langfuse" {
  source = "../.."

  apex_domain_gcp_project = "cto-eva-cust-domain-poc-10"

  domain =  "lf-prod.cto-si.zebra.com"
  apex_domain = "cto-si.zebra.com"
  subdomain = "lf-prod"
  apex_domain_integration_enabled = true

  # Optional use a different name for your installation
  # e.g. when using the module multiple times on the same GCP account
  name = "langfuse"

  # Optional: Configure the Subnetwork
  subnetwork_cidr = "10.110.0.0/16"

  # Optional: Configure the Kubernetes cluster
  kubernetes_namespace = "langfuse"

  # Optional: Configure the database instances
  database_instance_tier              = "db-perf-optimized-N-2"
  database_instance_availability_type = "REGIONAL"
  database_instance_edition = "ENTERPRISE_PLUS"

  # Optional: Configure the cache
  cache_tier           = "STANDARD_HA"
  cache_memory_size_gb = 1

  # Optional: Configure the Langfuse Helm chart version
  langfuse_chart_version = "1.2.15"

  ip_range_pods                        = "10.120.0.0/16"
  ip_range_services                    = "10.130.0.0/16"
  master_ipv4_cidr_block = "10.0.0.0/28"

  initial_cluster_node_count = 3
  initial_primary_node_pool_node_count =  1
  enable_private_nodes = true

  deletion_protection = false
}

provider "kubernetes" {
  host                   = module.langfuse.cluster_host
  cluster_ca_certificate = module.langfuse.cluster_ca_certificate
  token                  = module.langfuse.cluster_token
}

provider "helm" {
  kubernetes {
    host                   = module.langfuse.cluster_host
    cluster_ca_certificate = module.langfuse.cluster_ca_certificate
    token                  = module.langfuse.cluster_token
  }
}

output "connect" {
  description = "The cluster connection string to use once Terraform apply finishes"
  value       = "gcloud container clusters get-credentials ${module.langfuse.cluster_name} --zone us-east1 --project zac-02-d"
}
