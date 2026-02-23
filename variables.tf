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

variable "langfuse_chart_version" {
  description = "Version of the Langfuse Helm chart to deploy"
  type        = string
  default     = "1.5.14"
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

variable "additional_helm_values" {
  description = "Additional raw Helm values (YAML string) to merge into the Langfuse chart release. Useful for configuring resources, HPA, node selectors, tolerations, or any other chart values not exposed as module variables. Values are merged last and take precedence over module-generated values."
  type        = string
  default     = ""
}

variable "create_dns_zone" {
  description = "Whether to create a Google Cloud DNS managed zone"
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
