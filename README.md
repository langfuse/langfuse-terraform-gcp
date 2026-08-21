<img width="2400" height="600" alt="hero-b" src="https://github.com/user-attachments/assets/aa5438d5-5274-4c68-9e9d-e733e8960f08" />

# GCP Langfuse Terraform module

This repository contains a Terraform module for deploying [Langfuse](https://langfuse.com/) - the open-source LLM observability platform - on GCP.
This module aims to provide a production-ready, secure, and scalable deployment using managed services whenever possible.

![gcp-architecture](https://github.com/user-attachments/assets/a8fb739f-1757-451e-9808-e77ebfa2d334)


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

2. Set up the module with the settings that suit your need. A minimal installation requires a `domain` which is under your control only.

```hcl
module "langfuse" {
  source = "github.com/langfuse/langfuse-terraform-gcp?ref=1.0.0"

  domain = "langfuse.example.com"

  # Optional use a different name for your installation
  # e.g. when using the module multiple times on the same GCP project
  name   = "langfuse"

  # Optional: Configure the VPC
  subnetwork_cidr = "10.0.0.0/16"

  # Optional: Configure the Langfuse Helm chart version
  langfuse_chart_version = "2.0.0"

  # Optional: Pin the Langfuse application version. Defaults to the latest
  # release at the time this module version was published.
  app_version = "4.14.0"
}

provider "kubernetes" {
  host                   = module.langfuse.cluster_host
  cluster_ca_certificate = module.langfuse.cluster_ca_certificate
  token                  = module.langfuse.cluster_token
}

provider "helm" {
  kubernetes {
    host                   = module.langfuse.cluster_host
    cluster_ca_certificate = module.langfuse.cluster_ca_certificate
    token                  = module.langfuse.cluster_token
  }
}
```

3. Apply the DNS zone and the GKE Cluster.

```bash
terraform init
terraform apply --target module.langfuse.google_dns_managed_zone.this --target module.langfuse.google_container_cluster.this
```

> [!IMPORTANT]
> **The two-stage apply is the supported installation flow, not a workaround.** The `kubernetes` and `helm` providers are configured from this module's outputs, so the GKE cluster must exist before Terraform can plan any Kubernetes or Helm resources (see [kubernetes_manifest](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1775)). This also applies when you embed this module in a larger Terraform configuration: plan on creating the cluster in a first targeted apply (or a separate pipeline stage) before applying the full stack.

4. Set up the Nameserver delegation on your DNS provider. You can find the nameservers using the following command. Replace `langfuse` with your zone name, e.g. `langfuse-example-com`.

```bash
$ gcloud dns managed-zones describe langfuse --format="get(nameServers)"
```

5. Apply the full stack

```bash
terraform apply
```

6. Start using Langfuse by navigating to `https://<domain>` in your browser.

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
- ClickHouse cluster managed by the official [ClickHouse Kubernetes operator](https://github.com/ClickHouse/clickhouse-operator) (including ClickHouse Keeper and cert-manager), or optionally an external ClickHouse such as ClickHouse Cloud
- TLS certificates and Cloud DNS configuration
- Required IAM roles and firewall rules
- GKE Ingress Controller for ingress
- Filestore CSI Driver for persistent storage

## Langfuse version

The module deploys the Langfuse Helm chart v2 (`langfuse_chart_version`), which ships [Langfuse v4](https://langfuse.com/docs/v4). The Langfuse application version is pinned explicitly through the `app_version` variable, which defaults to the latest Langfuse release at the time the module version was published. To upgrade Langfuse, set `app_version` to a newer [release](https://github.com/langfuse/langfuse/releases):

```hcl
module "langfuse" {
  # ...
  app_version = "4.14.0"
}
```

## ClickHouse

By default the Langfuse Helm chart v2 deploys a ClickHouse cluster into the GKE cluster through the official [ClickHouse Kubernetes operator](https://github.com/ClickHouse/clickhouse-operator) (`ClickHouseCluster` and `KeeperCluster` resources). To support this, the module installs:

- [cert-manager](https://cert-manager.io/) (required by the operator to issue its admission webhook certificates)
- The ClickHouse operator (`oci://ghcr.io/clickhouse/clickhouse-operator-helm`)

The deployment can be sized with the `clickhouse_replicas`, `clickhouse_resources`, `clickhouse_storage_size`, `clickhouse_storage_class`, `clickhouse_keeper_replicas`, and `clickhouse_keeper_storage_size` variables.

### External ClickHouse (bring your own)

To use an existing ClickHouse instead — for example [ClickHouse Cloud](https://clickhouse.com/cloud) — set `external_clickhouse`. The module then skips cert-manager, the operator, and the in-cluster ClickHouse entirely. See [examples/external-clickhouse](examples/external-clickhouse/external-clickhouse.tf) for a full example.

```hcl
module "langfuse" {
  source = "github.com/langfuse/langfuse-terraform-gcp"

  domain = "langfuse.example.com"

  external_clickhouse = {
    host = "https://abc123.europe-west4.gcp.clickhouse.cloud"
    # Defaults: http_port = 8443, native_port = 9440, username = "default",
    # database = "default", cluster_enabled = true, migration_ssl = true
  }
  external_clickhouse_password = var.clickhouse_password
}
```

Set `cluster_enabled = false` for ClickHouse Cloud on Azure or for single-node deployments. Make sure the GKE cluster can reach the external ClickHouse (for ClickHouse Cloud, check the IP allowlist or use Private Service Connect).

### Migrating from module versions <= 0.3.x

This module version is a **clean Langfuse v4 installation based on v2.0.0 of the Langfuse Helm chart**. It does not migrate existing deployments.

Earlier versions of this module deployed Langfuse v3 with the Bitnami-based Helm chart v1, which ran ClickHouse (and ZooKeeper) as a Bitnami subchart. The operator-managed ClickHouse starts empty, and the Helm chart refuses a raw in-place `helm upgrade` that would replace leftover Bitnami volumes. If you upgrade an existing installation, you must perform the migration steps **manually, outside of Terraform**, before switching the module version:

1. Migrate the chart deployment (copying the ClickHouse data) following the [chart v1 → v2 migration guide](https://github.com/langfuse/langfuse-k8s/tree/main/examples/upgrade-v1-to-v2).
2. Upgrade the application following the [Langfuse v3 → v4 upgrade guide](https://langfuse.com/self-hosting/upgrade/upgrade-guides/upgrade-v3-to-v4).

New installations are unaffected. If you need to stay on the Bitnami-based deployment for now, pin this module to `0.3.x`.

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
| terraform   | >= 1.3  |
| google      | >= 5.0  |
| google-beta | >= 5.0  |
| kubernetes  | >= 2.10 |
| helm        | >= 2.7  |

## Providers

| Name        | Version |
|-------------|---------|
| google      | >= 5.0  |
| google-beta | >= 5.0  |
| kubernetes  | >= 2.10 |
| helm        | >= 2.7  |
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
| helm_release.clickhouse_operator            | resource |
| random_password.database                    | resource |
| tls_private_key.langfuse                    | resource |

## Inputs

| Name                                | Description                                                                                                                                                                                               | Type         | Default                 | Required |
|-------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------|-------------------------|:--------:|
| name                                | Name to use for or prefix resources with                                                                                                                                                                  | string       | "langfuse"              |    no    |
| domain                              | Domain name used to host langfuse on (e.g., langfuse.company.com)                                                                                                                                         | string       | n/a                     |   yes    |
| use_encryption_key                  | Wheter or not to use an Encryption key for LLM API credential and integration credential store                                                                                                            | bool         | true                    |    no    |
| kubernetes_namespace                | Namespace to deploy langfuse to                                                                                                                                                                           | string       | "langfuse"              |    no    |
| subnetwork_cidr                     | CIDR block for Subnetwork                                                                                                                                                                                 | string       | "10.0.0.0/16"           |    no    |
| database_instance_tier              | The machine type to use for the database instance                                                                                                                                                         | string       | "db-perf-optimized-N-2" |    no    |
| database_instance_edition           | The edition to use for the database instance                                                                                                                                                              | string       | "ENTERPRISE_PLUS"       |    no    |
| database_instance_availability_type | The availability type to use for the database instance                                                                                                                                                    | string       | "REGIONAL"              |    no    |
| database_transaction_log_retention_days | Days of transaction logs retained for point-in-time recovery (1-35). Defaults to 14 on ENTERPRISE_PLUS and 7 on ENTERPRISE (that edition's maximum).                                                  | number       | null                    |    no    |
| postgres_version                    | Version of PostgreSQL to use for the database instance                                                                                                                                                    | string       | "POSTGRES_16"           |    no    |
| cache_tier                          | The service tier of the instance                                                                                                                                                                          | string       | "STANDARD_HA"           |    no    |
| cache_memory_size_gb                | Redis memory size in GB                                                                                                                                                                                   | number       | 1                       |    no    |
| deletion_protection                 | Whether or not to enable deletion_protection on data sensitive resources                                                                                                                                  | bool         | true                    |    no    |
| clickhouse_replicas                 | Number of ClickHouse replicas (single shard). The default of 3 provides a highly available setup. Only used when ClickHouse is deployed in-cluster.                                                       | number       | 3                       |    no    |
| clickhouse_keeper_replicas          | Number of ClickHouse Keeper replicas. Must be 1, 3 or 5 to maintain quorum. Only used when ClickHouse is deployed in-cluster.                                                                             | number       | 3                       |    no    |
| clickhouse_storage_size             | Size of the persistent volume of each ClickHouse replica                                                                                                                                                  | string       | "100Gi"                 |    no    |
| clickhouse_keeper_storage_size      | Size of the persistent volume of each ClickHouse Keeper replica                                                                                                                                           | string       | "10Gi"                  |    no    |
| clickhouse_storage_class            | StorageClass used for the ClickHouse and ClickHouse Keeper volumes                                                                                                                                        | string       | "premium-rwo"           |    no    |
| clickhouse_resources                | Resource requests and limits for each ClickHouse replica                                                                                                                                                  | object       | { cpu = "2", memory = "8Gi" } | no |
| clickhouse_operator_chart_version   | Version of the ClickHouse operator Helm chart. The default matches the version the Langfuse Helm chart is tested against.                                                                                 | string       | "0.0.5"                 |    no    |
| cert_manager_chart_version          | Version of the cert-manager Helm chart. cert-manager issues the certificates for the ClickHouse operator admission webhooks.                                                                              | string       | "v1.20.2"               |    no    |
| external_clickhouse                 | Use an external ClickHouse deployment (e.g. ClickHouse Cloud) instead of deploying ClickHouse into the GKE cluster. See [External ClickHouse](#external-clickhouse-bring-your-own).                       | object       | null                    |    no    |
| external_clickhouse_password        | Password for the external ClickHouse user. Required when external_clickhouse is set.                                                                                                                      | string       | ""                      |    no    |
| langfuse_chart_version              | Version of the Langfuse Helm chart to deploy                                                                                                                                                              | string       | "2.0.0"                 |    no    |
| app_version                         | Langfuse application version (Docker image tag) to deploy. Defaults to the latest Langfuse release at the time this module version was published.                                                          | string       | "4.14.0"                |    no    |
| additional_env                      | Additional environment variables to add to the Langfuse container. Supports both direct values and Kubernetes valueFrom references (secrets, configMaps). See examples/additional-env for usage examples. | list(object) | []                      |    no    |
| create_dns_zone                     | Whether to create a Google Cloud DNS managed zone. Set to `false` if you manage DNS externally.                                                                                                           | bool         | true                    |    no    |
| provision_static_ip                 | Whether to provision a static global IP for the Ingress. Set to `true` if you need a stable IP for DNS configuration before deployment.                                                                   | bool         | false                   |    no    |
| ssl_certificate_name                | Name of an existing SSL certificate (e.g. created via `google_compute_ssl_certificate`). If provided, managed certificate creation is skipped.                                                            | string       | ""                      |    no    |
| ssl_certificate_body                | Content of the SSL certificate (public key). Used to create a `google_compute_ssl_certificate` internally.                                                                                                | string       | ""                      |    no    |
| ssl_certificate_private_key         | Content of the SSL certificate private key. Used to create a `google_compute_ssl_certificate` internally.                                                                                                 | string       | ""                      |    no    |

## Custom SSL & Static IP

If you want to use your own SSL certificate (e.g. a wildcard cert) and manage DNS externally (avoiding Google Cloud DNS delegation), you have two options:

### Option 1: Pass raw certificate content (Recommended)
The module will create the `google_compute_ssl_certificate` resource for you.

```hcl
module "langfuse" {
  source = "github.com/langfuse/langfuse-terraform-gcp"
  
  # ... other config ...

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

| Name                   | Description                      |
|------------------------|----------------------------------|
| cluster_name           | GKE Cluster Name                 |
| cluster_host           | GKE Cluster endpoint             |
| cluster_ca_certificate | GKE Cluster CA certificate       |
| cluster_token          | GKE Cluster authentication token |
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
