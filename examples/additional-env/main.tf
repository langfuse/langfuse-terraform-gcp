# Example demonstrating how to use additional environment variables
# with the Langfuse Terraform module

module "langfuse" {
  source = "../.."

  domain = "langfuse.example.com"
  name   = "langfuse"

  # Example additional environment variables demonstrating different patterns
  additional_env = [
    # Direct value example
    {
      name  = "LANGFUSE_LOG_LEVEL"
      value = "info"
    },
    # Secret reference example
    {
      name = "DATABASE_PASSWORD"
      valueFrom = {
        secretKeyRef = {
          name = "my-database-secret"
          key  = "password"
        }
      }
    },
    # ConfigMap reference example
    {
      name = "LANGFUSE_LOG_FORMAT"
      valueFrom = {
        configMapKeyRef = {
          name = "app-config"
          key  = "log-format"
        }
      }
    },
  ]
}

# Example Secret that could be referenced by the environment variables
resource "kubernetes_secret" "my_database_secret" {
  metadata {
    name      = "my-database-secret"
    namespace = "langfuse"
  }

  data = {
    password = base64encode("super-secret-password")
  }
}

# Example ConfigMap that could be referenced by the environment variables
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "app-config"
    namespace = "langfuse"
  }

  data = {
    "log-format": "json"
  }
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
