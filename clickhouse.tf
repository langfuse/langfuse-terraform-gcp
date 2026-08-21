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
}

# cert-manager issues the TLS certificates for the ClickHouse operator's
# admission webhooks. Only required while ClickHouse runs in-cluster.
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

  # Autopilot provisions nodes on demand; first installs can exceed the
  # default 300s while the three cert-manager deployments come up.
  timeout = 600
}

# Official ClickHouse Kubernetes operator. The Langfuse Helm chart v2 renders
# ClickHouseCluster and KeeperCluster resources that this operator reconciles.
# Both CRD sets (cert-manager and the operator) must exist before the Langfuse
# chart is installed.
resource "helm_release" "clickhouse_operator" {
  count = local.deploy_clickhouse ? 1 : 0

  name             = "clickhouse-operator"
  repository       = "oci://ghcr.io/clickhouse"
  chart            = "clickhouse-operator-helm"
  version          = var.clickhouse_operator_chart_version
  namespace        = "clickhouse-operator-system"
  create_namespace = true

  # Waiting (helm provider default) matters here: the operator deployment only
  # becomes ready once cert-manager has issued its webhook certificate, and the
  # Langfuse chart requires the operator CRDs and webhook to exist.
  timeout = 600

  depends_on = [helm_release.cert_manager]
}
