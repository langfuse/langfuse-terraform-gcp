locals {
  tag_name       = lower(var.name) == "langfuse" ? "Langfuse" : "Langfuse ${var.name}"
  gateway_domain = var.gateway_domain != null ? var.gateway_domain : "gateway.${var.domain}"

  # Dedicated Google-managed SSL certificate for gateway_domain unless the
  # caller supplied gateway_ssl_certificate_name or a custom/pre-existing
  # certificate for the main host (e.g. a wildcard cert).
  create_gateway_managed_ssl_cert = var.enable_ai_gateway && var.gateway_ssl_certificate_name == "" && var.ssl_certificate_name == "" && var.ssl_certificate_body == ""
  gateway_ssl_certificate_name    = !var.enable_ai_gateway ? "" : (var.gateway_ssl_certificate_name != "" ? var.gateway_ssl_certificate_name : (var.ssl_certificate_name != "" ? var.ssl_certificate_name : (var.ssl_certificate_body != "" ? google_compute_ssl_certificate.custom[0].name : google_compute_managed_ssl_certificate.gateway[0].name)))
}
