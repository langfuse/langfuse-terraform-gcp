# Deploys Langfuse against an external ClickHouse (e.g. ClickHouse Cloud)
# instead of running ClickHouse inside the GKE cluster. With an external
# ClickHouse configured, the module does not install cert-manager, the
# ClickHouse operator, or an in-cluster ClickHouse.

variable "clickhouse_password" {
  description = "Password of the external ClickHouse user"
  type        = string
  sensitive   = true
}

module "langfuse" {
  source = "../.."

  domain = "langfuse.example.com"

  # ClickHouse Cloud connection. The defaults match ClickHouse Cloud:
  # HTTPS on port 8443 and the TLS native protocol on port 9440.
  external_clickhouse = {
    host = "https://abc123.europe-west4.gcp.clickhouse.cloud"

    # Uncomment for ClickHouse Cloud on Azure or single-node deployments:
    # cluster_enabled = false

    # For a self-managed ClickHouse without TLS instead:
    # host          = "clickhouse.internal.example.com"
    # http_port     = 8123
    # native_port   = 9000
    # migration_ssl = false
  }
  external_clickhouse_password = var.clickhouse_password
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
