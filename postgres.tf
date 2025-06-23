resource "google_sql_database_instance" "this" {
  name             = var.name
  region           = data.google_client_config.current.region
  database_version = "POSTGRES_15"
  encryption_key_name = var.customer_managed_encryption_key

  settings {
    tier                        = var.database_instance_tier
    edition                     = var.database_instance_edition
    availability_type           = var.database_instance_availability_type
    deletion_protection_enabled = var.deletion_protection # Applies setting on GCP level

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.this.self_link
      enable_private_path_for_google_cloud_services = true
      ssl_mode                                      = "ENCRYPTED_ONLY"
    }
  }

  depends_on = [google_service_networking_connection.private_service_connection]

  deletion_protection = var.deletion_protection # Applies setting on Terraform level
}

resource "google_sql_database" "langfuse" {
  name     = "langfuse"
  instance = google_sql_database_instance.this.name
}

resource "google_sql_user" "langfuse" {
  name     = "langfuse"
  instance = google_sql_database_instance.this.name
  password = random_password.postgres_password.result
}

# Random passwords for database credentials
resource "random_password" "postgres_password" {
  length      = 64
  special     = false
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
}
