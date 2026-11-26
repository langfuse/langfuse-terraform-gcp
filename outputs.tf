output "cluster_name" {
  description = "GKE Cluster Name to use for a Kubernetes terraform provider"
  value       = google_container_cluster.this.name
}

output "cluster_host" {
  description = "GKE Cluster host to use for a Kubernetes terraform provider"
  value       = "https://${google_container_cluster.this.endpoint}"
}

output "cluster_ca_certificate" {
  description = "GKE Cluster CA certificate to use for a Kubernetes terraform provider"
  value       = base64decode(google_container_cluster.this.master_auth[0].cluster_ca_certificate)
  sensitive   = true
}

output "cluster_token" {
  description = "GKE Cluster Token to use for a Kubernetes terraform provider"
  value       = data.google_client_config.current.access_token
  sensitive   = true
}

output "ingress_ip" {
  description = "The static global IP address reserved for the Ingress"
  value       = var.provision_static_ip ? google_compute_global_address.ingress[0].address : null
}

output "gateway_url" {
  description = "Public HTTPS URL of the Langfuse AI gateway. Null when the AI gateway is disabled."
  value       = var.enable_ai_gateway ? "https://${local.gateway_domain}" : null
}

output "gateway_ingress_ip" {
  description = "External IP address of the AI gateway Ingress (the reserved static IP when provision_static_ip is true, otherwise the load balancer IP). Null when the AI gateway is disabled."
  value       = var.enable_ai_gateway ? (var.provision_static_ip ? google_compute_global_address.gateway_ingress[0].address : try(data.kubernetes_ingress_v1.langfuse_gateway[0].status[0].load_balancer[0].ingress[0].ip, null)) : null
}
