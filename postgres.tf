resource "google_sql_database_instance" "this" {
  name             = var.name
  region           = data.google_client_config.current.region
  database_version = "POSTGRES_15"

  settings {
    tier                        = var.database_instance_tier
    edition                     = var.database_instance_edition
    availability_type           = var.database_instance_availability_type
    deletion_protection_enabled = var.deletion_protection # Applies setting on GCP level

    backup_configuration {
      enabled                        = var.database_backup_enabled
      point_in_time_recovery_enabled = var.database_pitr_enabled
      # Pin the retention explicitly: the valid range depends on the edition
      # (1-7 days on ENTERPRISE, 1-35 on ENTERPRISE_PLUS), and relying on
      # API-side defaults produced out-of-range values on ENTERPRISE.
      transaction_log_retention_days = var.database_pitr_enabled ? coalesce(var.database_transaction_log_retention_days, var.database_instance_edition == "ENTERPRISE_PLUS" ? 14 : 7) : null
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

  lifecycle {
    precondition {
      condition     = var.database_instance_edition != "ENTERPRISE_PLUS" || startswith(var.database_instance_tier, "db-perf-optimized-")
      error_message = "Cloud SQL edition ENTERPRISE_PLUS only supports db-perf-optimized-* machine types. Use database_instance_edition = \"ENTERPRISE\" with custom tiers such as db-custom-2-4096."
    }
    precondition {
      condition     = var.database_instance_edition == "ENTERPRISE_PLUS" || !startswith(var.database_instance_tier, "db-perf-optimized-")
      error_message = "db-perf-optimized-* machine types require database_instance_edition = \"ENTERPRISE_PLUS\"."
    }
    precondition {
      condition     = var.database_transaction_log_retention_days == null || var.database_instance_edition == "ENTERPRISE_PLUS" || var.database_transaction_log_retention_days <= 7
      error_message = "Cloud SQL edition ENTERPRISE supports a transaction log retention of at most 7 days. Lower database_transaction_log_retention_days or use ENTERPRISE_PLUS."
    }
  }
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
