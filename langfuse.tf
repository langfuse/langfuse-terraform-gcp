locals {
  langfuse_values = <<EOT
langfuse:
  image:
    tag: ${jsonencode(var.app_version)}
  salt:
    secretKeyRef:
      name: ${kubernetes_secret.langfuse.metadata[0].name}
      key: salt
  nextauth:
    url: "https://${var.domain}"
    secret:
      secretKeyRef:
        name: ${kubernetes_secret.langfuse.metadata[0].name}
        key: nextauth-secret
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: ${google_service_account.langfuse.email}
  additionalEnv:
    - name: LANGFUSE_USE_GOOGLE_CLOUD_STORAGE
      value: "true"
%{for env in var.additional_env~}
    - name: ${env.name}
%{if env.value != null~}
      value: ${jsonencode(env.value)}
%{endif~}
%{if env.valueFrom != null~}
      valueFrom:
%{if env.valueFrom.secretKeyRef != null~}
        secretKeyRef:
          name: ${env.valueFrom.secretKeyRef.name}
          key: ${env.valueFrom.secretKeyRef.key}
%{endif~}
%{if env.valueFrom.configMapKeyRef != null~}
        configMapKeyRef:
          name: ${env.valueFrom.configMapKeyRef.name}
          key: ${env.valueFrom.configMapKeyRef.key}
%{endif~}
%{endif~}
%{endfor~}
  extraVolumeMounts:
    - name: redis-certificate
      mountPath: /var/run/secrets/
      readOnly: true
  extraVolumes:
    - name: redis-certificate
      secret:
        secretName: ${kubernetes_secret.langfuse.metadata[0].name}
        items:
          - key: redis-certificate
            path: redis-ca.crt
postgresql:
  deploy: false
  host: ${google_sql_database_instance.this.private_ip_address}
  auth:
    username: langfuse
    database: langfuse
    existingSecret: ${kubernetes_secret.langfuse.metadata[0].name}
    secretKeys:
      userPasswordKey: postgres-password
redis:
  deploy: false
  host: ${google_redis_instance.this.host}
  port: ${google_redis_instance.this.port}
  tls:
    enabled: true
    caPath: /var/run/secrets/redis-ca.crt
  auth:
    existingSecret: ${kubernetes_secret.langfuse.metadata[0].name}
    existingSecretPasswordKey: redis-password
s3:
  deploy: false
  storageProvider: "gcs"
  bucket: ${google_storage_bucket.langfuse.name}
  eventUpload:
    prefix: "events/"
  batchExport:
    prefix: "exports/"
  mediaUpload:
    prefix: "media/"
EOT

  # In-cluster ClickHouse: the Langfuse Helm chart v2 renders ClickHouseCluster
  # and KeeperCluster resources reconciled by the ClickHouse operator (see
  # clickhouse.tf).
  clickhouse_internal_values = !local.deploy_clickhouse ? "" : <<EOT
clickhouse:
  deploy: true
  auth:
    existingSecret: ${kubernetes_secret.langfuse.metadata[0].name}
    existingSecretKey: clickhouse-password
  cluster:
    replicas: ${var.clickhouse_replicas}
    storage:
      size: ${var.clickhouse_storage_size}
      className: ${var.clickhouse_storage_class}
    resources:
      requests:
        cpu: ${jsonencode(var.clickhouse_resources.cpu)}
        memory: ${jsonencode(var.clickhouse_resources.memory)}
      limits:
        cpu: ${jsonencode(var.clickhouse_resources.cpu)}
        memory: ${jsonencode(var.clickhouse_resources.memory)}
  keeper:
    replicas: ${var.clickhouse_keeper_replicas}
    storage:
      size: ${var.clickhouse_keeper_storage_size}
      className: ${var.clickhouse_storage_class}
EOT

  # External ClickHouse: skip the in-cluster deployment and point Langfuse at
  # the provided instance.
  clickhouse_external_values = local.deploy_clickhouse ? "" : <<EOT
clickhouse:
  deploy: false
  host: ${jsonencode(var.external_clickhouse.host)}
  httpPort: ${var.external_clickhouse.http_port}
  nativePort: ${var.external_clickhouse.native_port}
  database: ${jsonencode(var.external_clickhouse.database)}
  cluster:
    enabled: ${var.external_clickhouse.cluster_enabled}
  auth:
    username: ${jsonencode(var.external_clickhouse.username)}
    existingSecret: ${kubernetes_secret.langfuse.metadata[0].name}
    existingSecretKey: clickhouse-password
  migration:
    ssl: ${var.external_clickhouse.migration_ssl}
EOT

  clickhouse_values = local.deploy_clickhouse ? local.clickhouse_internal_values : local.clickhouse_external_values

  ingress_values    = <<EOT
langfuse:
  ingress:
    enabled: true
    className: gce  # Ignored in GCP but required from K8s
    annotations:
      kubernetes.io/ingress.class: gce
%{if var.provision_static_ip~}
      kubernetes.io/ingress.global-static-ip-name: ${google_compute_global_address.ingress[0].name}
%{endif~}
      ingress.gcp.kubernetes.io/pre-shared-cert: ${var.ssl_certificate_name != "" ? var.ssl_certificate_name : (var.ssl_certificate_body != "" ? google_compute_ssl_certificate.custom[0].name : google_compute_managed_ssl_certificate.this[0].name)}
      networking.gke.io/v1beta1.FrontendConfig: https-redirect
    hosts:
    - host: ${var.domain}
      paths:
      - path: /
        pathType: Prefix
  securityContext:
    allowPrivilegeEscalation: false
EOT
  encryption_values = !var.use_encryption_key ? "" : <<EOT
langfuse:
  encryptionKey:
    secretKeyRef:
      name: ${kubernetes_secret.langfuse.metadata[0].name}
      key: encryption_key
EOT

  # Dedicated GKE Ingress for the AI gateway so web keeps its default load
  # balancer timeout. The attached BackendConfig sets a 620s backend timeout
  # (for streams up to 600s) and /ready health checks. Memorystore uses a
  # private Google-managed CA, so mount it via SSL_CERT_DIR alongside the UBI9
  # system CA bundle in SSL_CERT_FILE so the Rust gateway trusts both
  # Memorystore (rediss://) and public LLM provider endpoints.
  gateway_values = !var.enable_ai_gateway ? "" : <<EOT
langfuse:
  gateway:
    enabled: true
    pod:
      additionalEnv:
        - name: SSL_CERT_FILE
          value: /etc/pki/tls/certs/ca-bundle.crt
        - name: SSL_CERT_DIR
          value: /var/run/secrets/redis-ca
      extraVolumeMounts:
        - name: redis-certificate
          mountPath: /var/run/secrets/redis-ca
          readOnly: true
      extraVolumes:
        - name: redis-certificate
          secret:
            secretName: ${kubernetes_secret.langfuse.metadata[0].name}
            items:
              - key: redis-certificate
                path: redis-ca.crt
    service:
      annotations:
        cloud.google.com/backend-config: '{"default": "langfuse-gateway"}'
    ingress:
      enabled: true
      className: gce
      annotations:
        kubernetes.io/ingress.class: gce
%{if var.provision_static_ip~}
        kubernetes.io/ingress.global-static-ip-name: ${google_compute_global_address.gateway_ingress[0].name}
%{endif~}
        ingress.gcp.kubernetes.io/pre-shared-cert: ${local.gateway_ssl_certificate_name}
        networking.gke.io/v1beta1.FrontendConfig: https-redirect
      hosts:
        - ${jsonencode(local.gateway_domain)}
EOT
}

# Service account for workload identity
resource "google_service_account" "langfuse" {
  account_id   = var.name
  display_name = local.tag_name
}

resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.langfuse.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${data.google_client_config.current.project}.svc.id.goog[${kubernetes_namespace.langfuse.metadata[0].name}/langfuse]"
  ]
}

resource "google_service_account_iam_member" "langfuse_token_creator" {
  service_account_id = google_service_account.langfuse.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.langfuse.email}"
}

resource "kubernetes_namespace" "langfuse" {
  metadata {
    name = var.kubernetes_namespace
  }
}

resource "random_bytes" "salt" {
  # Should be at least 256 bits (32 bytes): https://langfuse.com/self-hosting/configuration#core-infrastructure-settings ~> SALT
  length = 32
}

resource "random_bytes" "nextauth_secret" {
  # Should be at least 256 bits (32 bytes): https://langfuse.com/self-hosting/configuration#core-infrastructure-settings ~> NEXTAUTH_SECRET
  length = 32
}

resource "random_bytes" "encryption_key" {
  count = var.use_encryption_key ? 1 : 0
  # Must be exactly 256 bits (32 bytes): https://langfuse.com/self-hosting/configuration#core-infrastructure-settings ~> ENCRYPTION_KEY
  length = 32
}

resource "kubernetes_secret" "langfuse" {
  metadata {
    name      = "langfuse"
    namespace = kubernetes_namespace.langfuse.metadata[0].name
  }

  data = {
    "redis-password"      = google_redis_instance.this.auth_string
    "redis-certificate"   = google_redis_instance.this.server_ca_certs[0].cert
    "postgres-password"   = random_password.postgres_password.result
    "salt"                = random_bytes.salt.base64
    "nextauth-secret"     = random_bytes.nextauth_secret.base64
    "clickhouse-password" = local.deploy_clickhouse ? random_password.clickhouse_password.result : var.external_clickhouse_password
    "encryption_key"      = var.use_encryption_key ? random_bytes.encryption_key[0].hex : ""
  }
}

resource "helm_release" "langfuse" {
  name       = "langfuse"
  repository = "https://langfuse.github.io/langfuse-k8s"
  version    = var.langfuse_chart_version
  chart      = "langfuse"
  namespace  = kubernetes_namespace.langfuse.metadata[0].name

  values = concat([
    local.langfuse_values,
    local.clickhouse_values,
    local.ingress_values,
    local.gateway_values,
    local.encryption_values,
  ], var.additional_helm_values)

  depends_on = [
    kubernetes_secret.langfuse,
    google_service_account.langfuse,
    helm_release.clickhouse_operator,
    kubernetes_manifest.gateway_backend_config,
  ]

  lifecycle {
    precondition {
      condition     = var.external_clickhouse == null || var.external_clickhouse_password != ""
      error_message = "external_clickhouse_password must be set when external_clickhouse is configured."
    }

    precondition {
      condition = !var.enable_ai_gateway ? true : (
        try(tonumber(regex("^(\\d+)\\.(\\d+)", var.langfuse_chart_version)[0]), 99) > 2 ||
        (try(tonumber(regex("^(\\d+)\\.(\\d+)", var.langfuse_chart_version)[0]), 99) == 2 &&
        try(tonumber(regex("^(\\d+)\\.(\\d+)", var.langfuse_chart_version)[1]), 99) >= 3)
      )
      error_message = "The AI gateway needs langfuse_chart_version >= 2.3, which wires Redis for spend limits into langfuse.gateway.*. Helm ignores unknown values silently, so an older chart would deploy without gateway Redis or without the gateway."
    }

    precondition {
      condition     = !var.enable_ai_gateway ? true : lower(local.gateway_domain) != lower(var.domain)
      error_message = "gateway_domain must be different from domain."
    }

    precondition {
      condition     = !var.enable_ai_gateway || !var.create_dns_zone ? true : endswith(lower(local.gateway_domain), ".${lower(var.domain)}")
      error_message = "gateway_domain must be a subdomain of domain when create_dns_zone is true, because the module creates DNS records in the Cloud DNS zone for domain. Set create_dns_zone = false to use a different domain."
    }
  }

  timeout = 1800 # Increase timeout to 15 minutes
}
