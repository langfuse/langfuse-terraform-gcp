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
