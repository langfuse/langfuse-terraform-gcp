# Random password for ClickHouse
resource "random_password" "clickhouse_password" {
  length      = 64
  special     = false
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
}

locals {
  # Deploy ClickHouse into the GKE cluster unless an external one is configured
  deploy_clickhouse = var.external_clickhouse == null

  # Name of the ClickHouseCluster resource. The operator exposes the cluster
  # through a headless service named <name>-clickhouse-headless.
  clickhouse_cluster_name = "langfuse"

  clickhouse_host            = local.deploy_clickhouse ? "${local.clickhouse_cluster_name}-clickhouse-headless" : var.external_clickhouse.host
  clickhouse_http_port       = local.deploy_clickhouse ? 8123 : var.external_clickhouse.http_port
  clickhouse_native_port     = local.deploy_clickhouse ? 9000 : var.external_clickhouse.native_port
  clickhouse_username        = local.deploy_clickhouse ? "default" : var.external_clickhouse.username
  clickhouse_database        = local.deploy_clickhouse ? "default" : var.external_clickhouse.database
  clickhouse_cluster_enabled = local.deploy_clickhouse ? true : var.external_clickhouse.cluster_enabled
  clickhouse_migration_ssl   = local.deploy_clickhouse ? false : var.external_clickhouse.migration_ssl
}

# cert-manager issues the TLS certificates for the ClickHouse operator's
# admission webhooks
resource "helm_release" "cert_manager" {
  count = local.deploy_clickhouse ? 1 : 0

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = "cert-manager"
  create_namespace = true

  # Explicit resource requests to avoid the GKE Autopilot defaults of
  # 500m CPU / 2Gi memory per container
  values = [<<EOT
crds:
  enabled: true
resources:
  requests:
    cpu: 50m
    memory: 128Mi
webhook:
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
cainjector:
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
EOT
  ]
}

# Official ClickHouse Kubernetes operator
resource "helm_release" "clickhouse_operator" {
  count = local.deploy_clickhouse ? 1 : 0

  name             = "clickhouse-operator"
  repository       = "oci://ghcr.io/clickhouse"
  chart            = "clickhouse-operator-helm"
  version          = var.clickhouse_operator_chart_version
  namespace        = "clickhouse-operator-system"
  create_namespace = true

  depends_on = [helm_release.cert_manager]
}

# ClickHouse and ClickHouse Keeper, rendered as ClickHouseCluster and
# KeeperCluster resources and reconciled by the operator. The cluster chart
# version is kept in lockstep with the operator chart version. The operator
# names the ClickHouse cluster "default" in remote_servers, which matches the
# cluster name expected by the Langfuse migrations.
resource "helm_release" "clickhouse" {
  count = local.deploy_clickhouse ? 1 : 0

  name       = "clickhouse"
  repository = "oci://ghcr.io/clickhouse"
  chart      = "clickhouse-cluster-helm"
  version    = var.clickhouse_operator_chart_version
  namespace  = kubernetes_namespace.langfuse.metadata[0].name

  values = [<<EOT
clickhouse:
  meta:
    name: ${local.clickhouse_cluster_name}
  spec:
    replicas: ${var.clickhouse_replicas}
    dataVolumeClaimSpec:
      accessModes:
        - ReadWriteOnce
      storageClassName: ${var.clickhouse_storage_class}
      resources:
        requests:
          storage: ${var.clickhouse_storage_size}
    containerTemplate:
      resources:
        requests:
          cpu: ${var.clickhouse_resources.cpu}
          memory: ${var.clickhouse_resources.memory}
    podTemplate:
      topologyZoneKey: topology.kubernetes.io/zone
      nodeHostnameKey: kubernetes.io/hostname
    settings:
      defaultUserPassword:
        secret:
          name: ${kubernetes_secret.langfuse.metadata[0].name}
          key: clickhouse-password
keeper:
  meta:
    name: ${local.clickhouse_cluster_name}
  spec:
    replicas: ${var.clickhouse_keeper_replicas}
    dataVolumeClaimSpec:
      accessModes:
        - ReadWriteOnce
      storageClassName: ${var.clickhouse_storage_class}
      resources:
        requests:
          storage: ${var.clickhouse_keeper_storage_size}
    containerTemplate:
      resources:
        requests:
          cpu: 250m
          memory: 1Gi
    podTemplate:
      topologyZoneKey: topology.kubernetes.io/zone
      nodeHostnameKey: kubernetes.io/hostname
EOT
  ]

  depends_on = [
    helm_release.clickhouse_operator,
    kubernetes_secret.langfuse,
  ]
}
