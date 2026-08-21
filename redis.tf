resource "google_redis_instance" "this" {
  name                    = var.name
  tier                    = var.cache_tier
  memory_size_gb          = var.cache_memory_size_gb
  region                  = data.google_client_config.current.region
  authorized_network      = google_compute_network.this.id
  connect_mode            = "PRIVATE_SERVICE_ACCESS"
  transit_encryption_mode = "SERVER_AUTHENTICATION"
  display_name            = "${local.tag_name} Redis Instance"

  auth_enabled = true

  redis_configs = {
    "maxmemory-policy" = "noeviction"
  }

  depends_on = [google_service_networking_connection.private_service_connection]
}
