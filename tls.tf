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
