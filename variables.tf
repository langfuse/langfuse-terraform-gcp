variable "name" {
  description = "Name to use for or prefix resources with"
  type        = string
  default     = "langfuse"
}

variable "domain" {
  description = "Domain name used to host langfuse on (e.g., langfuse.company.com)"
  type        = string
}

variable "use_encryption_key" {
  description = "Whether or not to use an Encryption key for LLM API credential and integration credential store"
  type        = bool
  default     = true
}

variable "kubernetes_namespace" {
  description = "Namespace to deploy langfuse to"
  type        = string
  default     = "langfuse"
}

variable "subnetwork_cidr" {
  description = "CIDR block for Subnetwork"
  type        = string
  default     = "10.0.0.0/16"
}

variable "database_instance_tier" {
  description = "The machine type to use for the database instance"
  type        = string
  default     = "db-perf-optimized-N-2"
}

variable "database_instance_edition" {
  description = "The edition of the database instance"
  type        = string
  default     = "ENTERPRISE_PLUS"
}

variable "database_instance_availability_type" {
  description = "The availability type to use for the database instance"
  type        = string
  default     = "REGIONAL"
}

variable "database_backup_enabled" {
  description = "Whether to enable Cloud SQL automated backups"
  type        = bool
  default     = true
}

variable "database_pitr_enabled" {
  description = "Whether to enable Cloud SQL point-in-time recovery"
  type        = bool
  default     = true
}

variable "cache_tier" {
  description = "The service tier of the instance"
  type        = string
  default     = "STANDARD_HA"
}

variable "cache_memory_size_gb" {
  description = "Redis memory size in GB"
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Whether or not to enable deletion_protection on data sensitive resources"
  type        = bool
  default     = true
}

variable "clickhouse_replicas" {
  description = "Number of ClickHouse replicas (single shard). The default of 3 provides a highly available setup. Only used when ClickHouse is deployed in-cluster."
  type        = number
  default     = 3

  validation {
    condition     = var.clickhouse_replicas >= 1
    error_message = "clickhouse_replicas must be at least 1."
  }
}

variable "clickhouse_keeper_replicas" {
  description = "Number of ClickHouse Keeper replicas. Must be an odd number to maintain quorum. Only used when ClickHouse is deployed in-cluster."
  type        = number
  default     = 3

  validation {
    condition     = contains([1, 3, 5], var.clickhouse_keeper_replicas)
    error_message = "clickhouse_keeper_replicas must be 1, 3 or 5."
  }
}

variable "clickhouse_storage_size" {
  description = "Size of the persistent volume of each ClickHouse replica"
  type        = string
  default     = "100Gi"
}

variable "clickhouse_keeper_storage_size" {
  description = "Size of the persistent volume of each ClickHouse Keeper replica"
  type        = string
  default     = "10Gi"
}

variable "clickhouse_storage_class" {
  description = "StorageClass used for the ClickHouse and ClickHouse Keeper volumes"
  type        = string
  default     = "premium-rwo"
}

variable "clickhouse_resources" {
  description = "Resource requests for each ClickHouse replica. On GKE Autopilot the limits default to the requests."
  type = object({
    cpu    = optional(string, "2")
    memory = optional(string, "8Gi")
  })
  default = {}
}

variable "clickhouse_operator_chart_version" {
  description = "Version of the ClickHouse operator and ClickHouse cluster Helm charts (kept in lockstep)"
  type        = string
  default     = "0.0.7"
}

variable "cert_manager_chart_version" {
  description = "Version of the cert-manager Helm chart. cert-manager issues the certificates for the ClickHouse operator admission webhooks."
  type        = string
  default     = "v1.21.0"
}

variable "external_clickhouse" {
  description = "Use an external ClickHouse deployment (e.g. ClickHouse Cloud) instead of deploying ClickHouse into the GKE cluster. Set external_clickhouse_password as well. Prefix the host with https:// to connect via HTTPS. The defaults match ClickHouse Cloud; set cluster_enabled = false for ClickHouse Cloud on Azure or single-node deployments."
  type = object({
    host            = string
    http_port       = optional(number, 8443)
    native_port     = optional(number, 9440)
    username        = optional(string, "default")
    database        = optional(string, "default")
    cluster_enabled = optional(bool, true)
    migration_ssl   = optional(bool, true)
  })
  default = null
}

variable "external_clickhouse_password" {
  description = "Password for the external ClickHouse user. Required when external_clickhouse is set."
  type        = string
  default     = ""
  sensitive   = true
}

variable "langfuse_chart_version" {
  description = "Version of the Langfuse Helm chart to deploy"
  type        = string
  default     = "1.5.14"
}

variable "additional_helm_values" {
  description = "Additional Helm values to pass to the Langfuse Helm chart. Each entry is a YAML-encoded string that will be merged with the default values."
  type        = list(string)
  default     = []
}

variable "additional_env" {
  description = "Additional environment variables to add to the Langfuse container. Supports both direct values and Kubernetes valueFrom references (secrets, configMaps)."
  type = list(object({
    name = string
    # Direct value (mutually exclusive with valueFrom)
    value = optional(string)
    # Kubernetes valueFrom reference (mutually exclusive with value)
    valueFrom = optional(object({
      # Reference to a Secret key
      secretKeyRef = optional(object({
        name = string
        key  = string
      }))
      # Reference to a ConfigMap key
      configMapKeyRef = optional(object({
        name = string
        key  = string
      }))
    }))
  }))
  default = []

  validation {
    condition = alltrue([
      for env in var.additional_env :
      (env.value != null && env.valueFrom == null) || (env.value == null && env.valueFrom != null)
    ])
    error_message = "Each environment variable must have either 'value' or 'valueFrom' specified, but not both."
  }
}

variable "create_dns_zone" {
  description = "Whether to create a Google Cloud DNS managed zone. Set to `false` if you manage DNS externally."
  type        = bool
  default     = true
}

variable "ssl_certificate_name" {
  description = "Name of an existing SSL certificate to use. If not provided, a managed certificate will be created."
  type        = string
  default     = ""
}

variable "ssl_certificate_body" {
  description = "Content of the SSL certificate (public key)"
  type        = string
  default     = ""
}

variable "ssl_certificate_private_key" {
  description = "Content of the SSL certificate private key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "provision_static_ip" {
  description = "Whether to provision a static global IP for the Ingress. Set to true if you need a stable IP for DNS configuration before deployment."
  type        = bool
  default     = false
}
