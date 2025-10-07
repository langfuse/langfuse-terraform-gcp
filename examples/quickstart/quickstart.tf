module "langfuse" {
  source = "../.."

  domain = "langfuse.example.com"

  # Optional use a different name for your installation
  # e.g. when using the module multiple times on the same GCP account
  name = "langfuse"

  # Optional: Configure the Subnetwork
  subnetwork_cidr = "10.0.0.0/16"

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
  langfuse_chart_version = "1.5.5"
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
