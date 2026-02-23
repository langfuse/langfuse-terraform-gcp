![GitHub Banner](https://github.com/langfuse/langfuse-k8s/assets/2834609/2982b65d-d0bc-4954-82ff-af8da3a4fac8)

# GCP Langfuse Terraform module

> This module is a pre-release version and its interface may change. 
> Please review the changelog between each release and create a GitHub issue for any problems or feature requests.

This repository contains a Terraform module for deploying [Langfuse](https://langfuse.com/) - the open-source LLM observability platform - on GCP.
This module aims to provide a production-ready, secure, and scalable deployment using managed services whenever possible.

![gcp-architecture](https://github.com/user-attachments/assets/a8fb739f-1757-451e-9808-e77ebfa2d334)


## Deployment Guide

The following example shows a production setup with Azure AD SSO secrets managed externally (via `kubectl`) and a static IP pre-provisioned for DNS configuration. Adapt as needed for your environment.

1.  **Provision Infrastructure Basics**:
    Run `terraform apply` with `provision_static_ip = true` to create the GKE cluster and the static IP address.
    ```bash
    terraform apply -var="provision_static_ip=true"
    ```

2.  **Configure DNS**:
    Retrieve the static IP from the output and configure your DNS A-record to point to it.
    ```bash
    terraform output ingress_ip
    ```

3.  **Create External Secrets**:
    Connect to your GKE cluster and manually create the secret containing your sensitive values (e.g., SSO client secret).
    ```bash
    gcloud container clusters get-credentials <cluster_name> --region <region>
    kubectl create secret generic langfuse-secrets \
      --from-literal=auth_azure_ad_client_secret=YOUR_SECRET_VALUE \
      -n langfuse
    ```

4.  **Deploy Langfuse**:
    Run `terraform apply` again, this time passing the `additional_env` configuration to reference the external secret.
    ```hcl
    # tfvars
    additional_env = [
      {
        name = "AUTH_AZURE_AD_CLIENT_SECRET"
        valueFrom = {
          secretKeyRef = {
            name = "langfuse-secrets"
            key  = "auth_azure_ad_client_secret"
          }
        }
      }
    ]
    ```

## Usage

1. Enable required APIs on your Google Cloud Account:
- Certificate Manager API
- Cloud DNS API
- Compute Engine API
- Container File System API
- Google Cloud Memorystore for Redis API
- Kubernetes Engine API
- Network Connectivity API
- Service Networking API

2. Set up the module.

### Option A: Managed DNS (Default)

If you want the module to manage the DNS zone and Certificate (delegation required):

```hcl
module "langfuse" {
  source = "github.com/langfuse/langfuse-terraform-gcp?ref=0.3.3"
  
  domain = "langfuse.example.com"
  create_dns_zone = true # Default
  # ...
}
```

Then apply the DNS zone first and configure delegation:

```bash
terraform apply --target module.langfuse.google_dns_managed_zone.this --target module.langfuse.google_container_cluster.this
```

Get the nameservers to delegate in your registrar:
```bash
gcloud dns managed-zones describe langfuse --format="get(nameServers)"
```

### Option B: Custom DNS / External SSL

If you have your own certificate and manage DNS externally:

```hcl
module "langfuse" {
  source = "github.com/langfuse/langfuse-terraform-gcp?ref=0.3.3"

  domain = "langfuse.yourcompany.com"
  create_dns_zone = false
  
  # Pass your wildcard cert or private key here
  ssl_certificate_body        = "..."
  ssl_certificate_private_key = "..."
}
```

3. **Apply the full stack**

```bash
terraform apply
```

4. **Post-Deployment (Option B only)**:
   Find the Ingress IP and create an A record in your external DNS:
   ```bash
   kubectl get ingress -n langfuse langfuse -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```

5. Start using Langfuse by navigating to `https://<domain>` in your browser.

### Known issues

1. Getting an `ERR_SSL_VERSION_OR_CIPHER_MISMATCH` error after installation on the HTTPS endpoint.

Since Google Cloud takes a while (~20 Minutes) to provision new certificates, an invalid TLS certificate is presented for a while after initial installation of this module. Please use `gcloud compute ssl-certificates list` to check the current provisioning status. If it is still in `PROVISIONING` state this issue is expected. E.g.

```bash
$ gcloud compute ssl-certificates list
NAME      TYPE     CREATION_TIMESTAMP             EXPIRE_TIME  REGION  MANAGED_STATUS
langfuse  MANAGED  2025-04-06T03:41:54.791-07:00                       PROVISIONING
    <hostname>: PROVISIONING
```

When the certificate becomes active the ingress controller should pick it up and present a valid TLS certificate:

```bash
$ gcloud compute ssl-certificates list
NAME      TYPE     CREATION_TIMESTAMP             EXPIRE_TIME                    REGION  MANAGED_STATUS
langfuse  MANAGED  2025-04-06T03:41:54.791-07:00  2025-07-05T03:41:56.000-07:00          ACTIVE
    <hostname>: ACTIVE
```

## Features

This module creates a complete Langfuse stack with the following components:

- VPC with public and private subnets
- GKE cluster with node pools
- Cloud SQL PostgreSQL instance
- Cloud Memorystore Redis instance
- Cloud Storage bucket for storage
- TLS certificates and Cloud DNS configuration
- Required IAM roles and firewall rules
- NGINX Ingress Controller (via Helm) for ingress
- Filestore CSI Driver for persistent storage

## Additional Environment Variables

The module supports injecting custom environment variables into the Langfuse container through the `additional_env` parameter. This feature supports both direct values and Kubernetes `valueFrom` references.

```hcl
module "langfuse" {
  source = "github.com/langfuse/langfuse-terraform-gcp"

  domain = "langfuse.example.com"

  additional_env = [
    # Direct value
    {
      name  = "LOG_LEVEL"
      value = "debug"
    },

    # Secret reference
    {
      name = "API_KEY"
      valueFrom = {
        secretKeyRef = {
          name = "my-secrets"
          key  = "api-key"
        }
      }
    },

    # ConfigMap reference
    {
      name = "CONFIG_FILE"
      valueFrom = {
        configMapKeyRef = {
          name = "app-config"
          key  = "config.json"
        }
      }
    }
  ]
}
```

## Requirements

| Name        | Version |
|-------------|---------|
| terraform   | >= 1.0  |
| google      | >= 5.0  |
| google-beta | >= 5.0  |
| kubernetes  | >= 2.10 |
| helm        | >= 2.5  |

## Providers

| Name        | Version |
|-------------|---------|
| google      | >= 5.0  |
| google-beta | >= 5.0  |
| kubernetes  | >= 2.10 |
| helm        | >= 2.5  |
| random      | >= 3.0  |
| tls         | >= 3.0  |

## Resources

| Name                                        | Type     |
|---------------------------------------------|----------|
| google_container_cluster.langfuse           | resource |
| google_container_node_pool.default          | resource |
| google_sql_database_instance.postgres       | resource |
| google_sql_database.langfuse                | resource |
| google_sql_user.langfuse                    | resource |
| google_redis_instance.redis                 | resource |
| google_storage_bucket.langfuse              | resource |
| google_compute_managed_ssl_certificate.cert | resource |
| google_dns_managed_zone.zone                | resource |
| google_dns_record_set.langfuse              | resource |
| google_service_account.gke                  | resource |
| google_project_iam_member.gke               | resource |
| google_compute_firewall.gke                 | resource |
| google_compute_firewall.postgres            | resource |
| google_compute_firewall.redis               | resource |
| google_compute_network.vpc                  | resource |
| google_compute_subnetwork.subnet            | resource |
| google_kms_key_ring.langfuse                | resource |
| google_kms_crypto_key.langfuse              | resource |
| kubernetes_namespace.langfuse               | resource |
| kubernetes_secret.langfuse                  | resource |
| helm_release.ingress_nginx                  | resource |
| helm_release.cert_manager                   | resource |
| random_password.database                    | resource |
| tls_private_key.langfuse                    | resource |

## Inputs

| Name                                | Description                                                                                                                                                                                               | Type         | Default                 | Required |
|-------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------|-------------------------|:--------:|
| name                                | Name to use for or prefix resources with                                                                                                                                                                  | string       | "langfuse"              |    no    |
| domain                              | Domain name used to host langfuse on (e.g., langfuse.company.com)                                                                                                                                         | string       | n/a                     |   yes    |
| use_encryption_key                  | Whether or not to use an Encryption key for LLM API credential and integration credential store                                                                                                           | bool         | true                    |    no    |
| kubernetes_namespace                | Namespace to deploy langfuse to                                                                                                                                                                           | string       | "langfuse"              |    no    |
| subnetwork_cidr                     | CIDR block for Subnetwork                                                                                                                                                                                 | string       | "10.0.0.0/16"           |    no    |
| database_instance_tier              | The machine type to use for the database instance                                                                                                                                                         | string       | "db-perf-optimized-N-2" |    no    |
| database_instance_edition           | The edition to use for the database instance                                                                                                                                                              | string       | "ENTERPRISE_PLUS"       |    no    |
| database_instance_availability_type | The availability type to use for the database instance                                                                                                                                                    | string       | "REGIONAL"              |    no    |
| cache_tier                          | The service tier of the instance                                                                                                                                                                          | string       | "STANDARD_HA"           |    no    |
| cache_memory_size_gb                | Redis memory size in GB                                                                                                                                                                                   | number       | 1                       |    no    |
| deletion_protection                 | Whether or not to enable deletion_protection on data sensitive resources                                                                                                                                  | bool         | true                    |    no    |
| langfuse_chart_version              | Version of the Langfuse Helm chart to deploy                                                                                                                                                              | string       | "1.5.14"                |    no    |
| additional_env                      | Additional environment variables to add to the Langfuse container. Supports both direct values and Kubernetes valueFrom references (secrets, configMaps). See examples/additional-env for usage examples. | list(object) | []                      |    no    |
| provision_static_ip                 | Whether to provision a static global IP for the Ingress. Set to `true` if you need a stable IP for DNS configuration before deployment.                                                                   | bool         | false                   |    no    |
| create_dns_zone                     | Whether to create a Google Cloud DNS managed zone. Set to `false` if you manage DNS externally.                                                                                                           | bool         | true                    |    no    |
| ssl_certificate_name                | Name of an existing SSL certificate (e.g. created via `google_compute_ssl_certificate`). If provided, managed certificate creation is skipped.                                                            | string       | ""                      |    no    |
| ssl_certificate_body                | Content of the SSL certificate (public key). Used to create a `google_compute_ssl_certificate` internally.                                                                                                | string       | ""                      |    no    |
| ssl_certificate_private_key         | Content of the SSL certificate private key. Used to create a `google_compute_ssl_certificate` internally.                                                                                                 | string       | ""                      |    no    |
| database_backup_enabled             | Whether to enable Cloud SQL automated backups                                                                                                                                                             | bool         | true                    |    no    |
| database_pitr_enabled               | Whether to enable Cloud SQL point-in-time recovery                                                                                                                                                        | bool         | true                    |    no    |
| web_resources                       | Resources for Langfuse Web                                                                                                                                                                                | map(any)     | { limits = { cpu = "2", memory = "4Gi" }, requests = { cpu = "2", memory = "4Gi" } } |    no    |
| web_hpa_config                      | HPA configuration for Langfuse Web                                                                                                                                                                        | map(any)     | { minReplicas = 1, maxReplicas = 3, targetCPUUtilizationPercentage = 50 } |    no    |
| web_vpa_enabled                     | Whether to enable VPA for Langfuse Web                                                                                                                                                                    | bool         | false                   |    no    |
| worker_resources                    | Resources for Langfuse Worker                                                                                                                                                                             | map(any)     | { limits = { cpu = "2", memory = "4Gi" }, requests = { cpu = "2", memory = "4Gi" } } |    no    |
| worker_hpa_config                   | HPA configuration for Langfuse Worker                                                                                                                                                                     | map(any)     | { minReplicas = 1, maxReplicas = 3, targetCPUUtilizationPercentage = 50 } |    no    |
| worker_vpa_enabled                  | Whether to enable VPA for Langfuse Worker                                                                                                                                                                 | bool         | false                   |    no    |

## Custom SSL & External DNS

If you want to use your own SSL certificate (e.g. a wildcard cert) and manage DNS externally (avoiding Google Cloud DNS delegation), you have two options:

### Option 1: Pass raw certificate content (Recommended)
The module will create the `google_compute_ssl_certificate` resource for you.

```hcl
module "langfuse" {
  source = "github.com/langfuse/langfuse-terraform-gcp"
  
  # ... other config ...

  create_dns_zone             = false
  ssl_certificate_body        = var.ssl_certificate_body        # Pass from secrets
  ssl_certificate_private_key = var.ssl_certificate_private_key # Pass from secrets
}
```

### Option 2: Pre-create certificate resource
Create the resource yourself and pass the name.

```hcl
resource "google_compute_ssl_certificate" "my_cert" {
  name_prefix = "my-cert-"
  # ...
}

module "langfuse" {
  source = "github.com/langfuse/langfuse-terraform-gcp"
  # ...
  ssl_certificate_name = google_compute_ssl_certificate.my_cert.name
}
```

### Option 3: Pre-provision Static IP (Recommended for Production)
If you need a static IP address for your A-record *before* deploying the full stack (e.g. to open a ticket with your DNS team), you can use the `provision_static_ip` flag.

1.  Enable valid static IP provisioning in your module configuration:
    ```hcl
    module "langfuse" {
      # ...
      provision_static_ip = true
    }
    ```

2.  Run a targeted apply to create just the IP:
    ```bash
    terraform apply -target=module.langfuse.google_compute_global_address.ingress
    ```

3.  Get the IP address from the output:
    ```bash
    terraform output ingress_ip
    ```

4.  Configure your DNS A-record with this IP.

5.  Run the full apply:
    ```bash
    terraform apply
    ```

## Outputs

| Name                   | Description                        |
|------------------------|------------------------------------|
| cluster_name           | GKE Cluster Name                   |
| cluster_host           | GKE Cluster endpoint               |
| cluster_ca_certificate | GKE Cluster CA certificate         |
| cluster_token          | GKE Cluster authentication token   |
| ingress_ip             | Static IP address of the Ingress   |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. Here are some ways you can contribute:
- Add support for new cloud providers
- Improve existing configurations
- Add monitoring and alerting templates
- Improve documentation
- Report issues

## Support

- [Langfuse Documentation](https://langfuse.com/docs)
- [Langfuse GitHub](https://github.com/langfuse/langfuse)
- [Join Langfuse Discord](https://langfuse.com/discord)

## License

MIT Licensed. See LICENSE for full details.
