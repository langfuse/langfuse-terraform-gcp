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

variable "langfuse_chart_version" {
  description = "Version of the Langfuse Helm chart to deploy"
  type        = string
  default     = "1.2.15"
}

variable "additional_env" {
  description = "Additional environment variables to add to the Langfuse container. Supports both direct values and Kubernetes valueFrom references (secrets, configMaps, fieldRef, resourceFieldRef)."
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
        optional = optional(bool)
      }))
      # Reference to a ConfigMap key
      configMapKeyRef = optional(object({
        name = string
        key  = string
        optional = optional(bool)
      }))
      # Reference to a field in the Pod spec
      fieldRef = optional(object({
        fieldPath = string
        apiVersion = optional(string)
      }))
      # Reference to a resource field
      resourceFieldRef = optional(object({
        resource = string
        containerName = optional(string)
        divisor = optional(string)
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

  validation {
    condition = alltrue([
      for env in var.additional_env :
      env.valueFrom == null || (
        length([
          for ref in [env.valueFrom.secretKeyRef, env.valueFrom.configMapKeyRef, env.valueFrom.fieldRef, env.valueFrom.resourceFieldRef] :
          ref if ref != null
        ]) == 1
      )
    ])
    error_message = "When using 'valueFrom', exactly one of secretKeyRef, configMapKeyRef, fieldRef, or resourceFieldRef must be specified."
  }
}

variable "customer_managed_encryption_key" {
  description = "The Cloud KMS key name to use for customer-managed encryption across all supported resources (Cloud Storage, Cloud SQL, Redis, GKE). Format: projects/[PROJECT_ID]/locations/[LOCATION]/keyRings/[RING_NAME]/cryptoKeys/[KEY_NAME]. If not provided, Google-managed encryption keys will be used."
  type        = string
  default     = null
}

variable "storage_class_name" {
  description = "Name of the Kubernetes storage class to use for ClickHouse persistent volumes. When using customer-managed encryption keys, you should create a custom storage class with CMEK configuration and provide its name here. If not provided, the cluster's default storage class will be used."
  type        = string
  default     = null
}
