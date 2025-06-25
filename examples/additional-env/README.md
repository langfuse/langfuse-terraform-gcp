# Additional Environment Variables Example

This example demonstrates how to use the `additional_env` parameter to inject custom environment variables into the Langfuse container. The feature supports both direct values and Kubernetes `valueFrom` references.

## Features Demonstrated

### Direct Values
Simple key-value pairs that are directly injected as environment variables:

```hcl
additional_env = [
  {
    name  = "CUSTOM_FEATURE_FLAG"
    value = "enabled"
  },
  {
    name  = "LOG_LEVEL"
    value = "info"
  }
]
```

### Secret References
Reference values from Kubernetes Secrets:

```hcl
additional_env = [
  {
    name = "DATABASE_PASSWORD"
    valueFrom = {
      secretKeyRef = {
        name = "my-database-secret"
        key  = "password"
      }
    }
  },
  # Optional secret (won't fail if secret doesn't exist)
  {
    name = "OPTIONAL_API_KEY"
    valueFrom = {
      secretKeyRef = {
        name     = "optional-secrets"
        key      = "api-key"
        optional = true
      }
    }
  }
]
```

### ConfigMap References
Reference values from Kubernetes ConfigMaps:

```hcl
additional_env = [
  {
    name = "APP_CONFIG"
    valueFrom = {
      configMapKeyRef = {
        name = "app-config"
        key  = "config.json"
      }
    }
  }
]
```

### Field References
Reference Pod metadata and status fields:

```hcl
additional_env = [
  {
    name = "POD_NAME"
    valueFrom = {
      fieldRef = {
        fieldPath = "metadata.name"
      }
    }
  },
  {
    name = "POD_IP"
    valueFrom = {
      fieldRef = {
        fieldPath = "status.podIP"
      }
    }
  }
]
```

### Resource Field References
Reference container resource limits and requests:

```hcl
additional_env = [
  {
    name = "CPU_LIMIT"
    valueFrom = {
      resourceFieldRef = {
        resource = "limits.cpu"
      }
    }
  },
  {
    name = "MEMORY_REQUEST"
    valueFrom = {
      resourceFieldRef = {
        resource      = "requests.memory"
        containerName = "langfuse"
        divisor       = "1Mi"
      }
    }
  }
]
```

## Usage

1. **Apply the configuration:**
   ```bash
   terraform init
   terraform apply
   ```

2. **Verify the environment variables are set:**
   ```bash
   kubectl exec -n langfuse deployment/langfuse -- env | grep -E "(CUSTOM_FEATURE_FLAG|LOG_LEVEL|DATABASE_PASSWORD|POD_NAME)"
   ```

## Validation Rules

The module includes validation to ensure proper usage:

1. **Mutual Exclusivity**: Each environment variable must have either `value` or `valueFrom` specified, but not both.

2. **Single Reference Type**: When using `valueFrom`, exactly one of `secretKeyRef`, `configMapKeyRef`, `fieldRef`, or `resourceFieldRef` must be specified.

## Common Use Cases

- **Feature Flags**: Enable/disable features without rebuilding the application
- **Configuration**: Inject configuration values from ConfigMaps
- **Secrets**: Safely inject sensitive data from Kubernetes Secrets
- **Pod Information**: Make Pod metadata available to the application
- **Resource Awareness**: Allow applications to know their resource limits

## Security Considerations

- Use Secrets for sensitive data rather than direct values
- Consider using the `optional` flag for non-critical secrets
- Be mindful of what Pod metadata you expose to applications
- Use appropriate RBAC to control access to referenced Secrets and ConfigMaps
