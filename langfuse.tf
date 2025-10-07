locals {
  langfuse_values   = <<EOT
langfuse:
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
%{ for env in var.additional_env ~}
    - name: ${env.name}
%{ if env.value != null ~}
      value: ${jsonencode(env.value)}
%{ endif ~}
%{ if env.valueFrom != null ~}
      valueFrom:
%{ if env.valueFrom.secretKeyRef != null ~}
        secretKeyRef:
          name: ${env.valueFrom.secretKeyRef.name}
          key: ${env.valueFrom.secretKeyRef.key}
%{ endif ~}
%{ if env.valueFrom.configMapKeyRef != null ~}
        configMapKeyRef:
          name: ${env.valueFrom.configMapKeyRef.name}
          key: ${env.valueFrom.configMapKeyRef.key}
%{ endif ~}
%{ endif ~}
%{ endfor ~}
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
clickhouse:
  auth:
    existingSecret: ${kubernetes_secret.langfuse.metadata[0].name}
    existingSecretKey: clickhouse-password
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
  ingress_values    = <<EOT
langfuse:
  ingress:
    enabled: true
    className: gce  # Ignored in GCP but required from K8s
    annotations:
      kubernetes.io/ingress.class: gce
      ingress.gcp.kubernetes.io/pre-shared-cert: ${var.name}
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
    "clickhouse-password" = random_password.clickhouse_password.result
    "encryption_key"      = var.use_encryption_key ? random_bytes.encryption_key[0].hex : ""
  }
}

resource "helm_release" "langfuse" {
  name       = "langfuse"
  repository = "https://langfuse.github.io/langfuse-k8s"
  version    = var.langfuse_chart_version
  chart      = "langfuse"
  namespace  = kubernetes_namespace.langfuse.metadata[0].name

  values = [
    local.langfuse_values,
    local.ingress_values,
    local.encryption_values,
  ]

  depends_on = [
    kubernetes_secret.langfuse,
    google_service_account.langfuse,
  ]

  timeout = 1800 # Increase timeout to 15 minutes
}
