locals {
  retention_enabled = var.retention_days != null
}

resource "kubernetes_job_v1" "clickhouse_retention" {
  count = local.retention_enabled && local.deploy_clickhouse ? 1 : 0

  metadata {
    name      = "${var.name}-clickhouse-retention"
    namespace = kubernetes_namespace.langfuse.metadata[0].name
  }

  spec {
    backoff_limit = 3

    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"

        container {
          name  = "apply-ttl"
          image = var.retention_clickhouse_image

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }

          env {
            name  = "RETENTION_DAYS"
            value = tostring(var.retention_days)
          }
          env {
            name  = "V4_TABLES"
            value = tonumber(split(".", var.app_version)[0]) >= 4 ? "1" : "0"
          }
          env {
            name = "CLICKHOUSE_PASSWORD"
            value_from {
              secret_key_ref {
                name     = kubernetes_secret.langfuse.metadata[0].name
                key      = "clickhouse-password"
                optional = false
              }
            }
          }

          command = ["bash", "-c", <<-EOT
            set -eu
            ch() { clickhouse-client --host langfuse-clickhouse-headless --user default --password "$CLICKHOUSE_PASSWORD" "$@"; }
            n=0
            for i in $(seq 1 60); do
              n=$(ch --query "SELECT count() FROM system.tables WHERE database = currentDatabase() AND name IN ('traces', 'observations', 'scores', 'blob_storage_file_log')" || echo 0)
              [ "$n" = "4" ] && break
              echo "waiting for ClickHouse tables ($n/4)"; sleep 10
            done
            [ "$n" = "4" ] || { echo "tables not found" >&2; exit 1; }
            ch --query "ALTER TABLE traces               MODIFY TTL toDateTime(timestamp)  + toIntervalDay($RETENTION_DAYS)"
            ch --query "ALTER TABLE observations         MODIFY TTL toDateTime(start_time) + toIntervalDay($RETENTION_DAYS)"
            ch --query "ALTER TABLE scores               MODIFY TTL toDateTime(timestamp)  + toIntervalDay($RETENTION_DAYS)"
            ch --query "ALTER TABLE blob_storage_file_log MODIFY TTL toDateTime(created_at) + toIntervalDay($RETENTION_DAYS)"
            if [ "$V4_TABLES" = "1" ]; then
              for t in events_core events_full; do
                for i in $(seq 1 60); do
                  [ "$(ch --query "EXISTS TABLE $t")" = "1" ] && break
                  echo "waiting for $t"; sleep 10
                done
                ch --query "ALTER TABLE $t MODIFY TTL toDateTime(start_time) + toIntervalDay($RETENTION_DAYS)"
              done
            fi
          EOT
          ]
        }
      }
    }
  }

  wait_for_completion = true
  timeouts {
    create = "15m"
    update = "15m"
  }

  depends_on = [helm_release.langfuse]

  # GKE Autopilot adds these fields on admission; without ignoring them every plan wants to replace the Job.
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      spec[0].template[0].spec[0].security_context,
      spec[0].template[0].spec[0].toleration,
      spec[0].template[0].spec[0].container[0].security_context,
      spec[0].template[0].spec[0].container[0].resources,
    ]
  }
}


resource "kubernetes_cron_job_v1" "postgres_retention" {
  count = local.retention_enabled ? 1 : 0

  metadata {
    name      = "${var.name}-postgres-retention"
    namespace = kubernetes_namespace.langfuse.metadata[0].name
  }

  spec {
    schedule                      = var.retention_postgres_schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 3

    job_template {
      metadata {}
      spec {
        backoff_limit = 2

        template {
          metadata {}
          spec {
            restart_policy = "OnFailure"

            container {
              name  = "delete-expired"
              image = var.retention_postgres_image

              resources {
                requests = {
                  cpu    = "100m"
                  memory = "256Mi"
                }
              }

              env {
                name  = "PGHOST"
                value = google_sql_database_instance.this.private_ip_address
              }
              env {
                name  = "PGUSER"
                value = "langfuse"
              }
              env {
                name  = "PGDATABASE"
                value = "langfuse"
              }
              env {
                name  = "PGSSLMODE"
                value = "require"
              }
              env {
                name = "PGPASSWORD"
                value_from {
                  secret_key_ref {
                    name     = kubernetes_secret.langfuse.metadata[0].name
                    key      = "postgres-password"
                    optional = false
                  }
                }
              }
              env {
                name  = "ROW_RETENTION_DAYS"
                value = tostring(var.retention_days - 1)
              }

              command = ["sh", "-c", <<-EOT
                set -eu
                psql -v ON_ERROR_STOP=1 --single-transaction -v days="$ROW_RETENTION_DAYS" <<'SQL'
                DELETE FROM observation_media WHERE created_at < now() - (:days * interval '1 day');
                DELETE FROM trace_media       WHERE created_at < now() - (:days * interval '1 day');
                DELETE FROM media             WHERE created_at < now() - (:days * interval '1 day');
                DELETE FROM trace_sessions    WHERE created_at < now() - (:days * interval '1 day');
                SQL
              EOT
              ]
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.langfuse]

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      spec[0].job_template[0].spec[0].template[0].spec[0].security_context,
      spec[0].job_template[0].spec[0].template[0].spec[0].toleration,
      spec[0].job_template[0].spec[0].template[0].spec[0].container[0].security_context,
      spec[0].job_template[0].spec[0].template[0].spec[0].container[0].resources,
    ]
  }
}
