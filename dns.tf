# Create Cloud DNS zone
resource "google_dns_managed_zone" "this" {
  count       = var.create_dns_zone ? 1 : 0
  name        = replace(var.domain, ".", "-")
  dns_name    = "${var.domain}."
  description = "DNS zone for Langfuse domain"
}

# Get the load balancer IP
data "kubernetes_ingress_v1" "langfuse" {
  metadata {
    name      = "langfuse"
    namespace = kubernetes_namespace.langfuse.metadata[0].name
  }

  depends_on = [
    helm_release.langfuse
  ]
}

# Create DNS A record for the load balancer
resource "google_dns_record_set" "this" {
  count        = var.create_dns_zone ? 1 : 0
  name         = google_dns_managed_zone.this[0].dns_name
  managed_zone = google_dns_managed_zone.this[0].name
  type         = "A"
  ttl          = 300

  rrdatas = [data.kubernetes_ingress_v1.langfuse.status.0.load_balancer.0.ingress.0.ip]
}

# Get the AI gateway load balancer IP (only needed when no static IP is provisioned)
data "kubernetes_ingress_v1" "langfuse_gateway" {
  count = var.enable_ai_gateway && !var.provision_static_ip ? 1 : 0

  metadata {
    name      = "langfuse-gateway"
    namespace = kubernetes_namespace.langfuse.metadata[0].name
  }

  depends_on = [
    helm_release.langfuse
  ]
}

# Create DNS A record for the AI gateway load balancer
resource "google_dns_record_set" "gateway" {
  count        = var.enable_ai_gateway && var.create_dns_zone ? 1 : 0
  name         = "${local.gateway_domain}."
  managed_zone = google_dns_managed_zone.this[0].name
  type         = "A"
  ttl          = 300

  rrdatas = [
    var.provision_static_ip ? google_compute_global_address.gateway_ingress[0].address : data.kubernetes_ingress_v1.langfuse_gateway[0].status.0.load_balancer.0.ingress.0.ip
  ]
}
