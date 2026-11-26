# TLS Certificate
resource "google_compute_managed_ssl_certificate" "this" {
  count = var.ssl_certificate_name == "" && var.ssl_certificate_body == "" ? 1 : 0
  name  = var.name

  managed {
    domains = [var.domain]
  }
}

resource "google_compute_ssl_certificate" "custom" {
  count       = var.ssl_certificate_body != "" ? 1 : 0
  name_prefix = "${var.name}-custom-"
  description = "Custom SSL certificate for Langfuse"
  private_key = var.ssl_certificate_private_key
  certificate = var.ssl_certificate_body

  lifecycle {
    create_before_destroy = true
  }
}

# Dedicated Google-managed SSL certificate for the AI gateway domain
resource "google_compute_managed_ssl_certificate" "gateway" {
  count = local.create_gateway_managed_ssl_cert ? 1 : 0
  name  = "${var.name}-gateway"

  managed {
    domains = [local.gateway_domain]
  }
}

# Frontend config for HTTPs redirect
resource "kubernetes_manifest" "https_redirect" {
  manifest = {
    "apiVersion" = "networking.gke.io/v1beta1"
    "kind"       = "FrontendConfig"
    "metadata" = {
      "name"      = "https-redirect"
      "namespace" = kubernetes_namespace.langfuse.metadata[0].name
    }
    "spec" = {
      "redirectToHttps" = {
        enabled          = "true"
        responseCodeName = "PERMANENT_REDIRECT"
      }
    }
  }
}

# BackendConfig for the AI gateway Service: raises the default 30s GKE load
# balancer backend timeout to 620s (for streams up to 600s) and probes /ready.
resource "kubernetes_manifest" "gateway_backend_config" {
  count = var.enable_ai_gateway ? 1 : 0

  manifest = {
    "apiVersion" = "cloud.google.com/v1"
    "kind"       = "BackendConfig"
    "metadata" = {
      "name"      = "langfuse-gateway"
      "namespace" = kubernetes_namespace.langfuse.metadata[0].name
    }
    "spec" = {
      "timeoutSec" = 620
      "healthCheck" = {
        "requestPath" = "/ready"
        "type"        = "HTTP"
      }
    }
  }
}
