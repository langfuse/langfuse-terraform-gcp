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
      name  = "CUSTOM_FEATURE_FLAG"
      value = "enabled"
    },
    
    # Another direct value example
    {
      name  = "LOG_LEVEL"
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
    
    # Secret reference with optional flag
    {
      name = "OPTIONAL_API_KEY"
      valueFrom = {
        secretKeyRef = {
          name     = "optional-secrets"
          key      = "api-key"
          optional = true
        }
      }
    },
    
    # ConfigMap reference example
    {
      name = "APP_CONFIG"
      valueFrom = {
        configMapKeyRef = {
          name = "app-config"
          key  = "config.json"
        }
      }
    },
    
    # Field reference example (Pod metadata)
    {
      name = "POD_NAME"
      valueFrom = {
        fieldRef = {
          fieldPath = "metadata.name"
        }
      }
    },
    
    # Field reference example (Pod IP)
    {
      name = "POD_IP"
      valueFrom = {
        fieldRef = {
          fieldPath = "status.podIP"
        }
      }
    },
    
    # Resource field reference example (CPU limit)
    {
      name = "CPU_LIMIT"
      valueFrom = {
        resourceFieldRef = {
          resource = "limits.cpu"
        }
      }
    },
    
    # Resource field reference example (Memory request)
    {
      name = "MEMORY_REQUEST"
      valueFrom = {
        resourceFieldRef = {
          resource      = "requests.memory"
          containerName = "langfuse"
          divisor       = "1Mi"
        }
      }
    }
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
    "config.json" = jsonencode({
      feature_flags = {
        new_ui = true
        beta_features = false
      }
      timeouts = {
        request = "30s"
        connection = "10s"
      }
    })
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
