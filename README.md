# Rancher Kubernetes Deployment

This package provides automated deployment of Rancher with Prometheus monitoring and Grafana dashboards to a Kubernetes cluster using Jenkins CI/CD and Terraform Infrastructure-as-Code.

## Overview

The deployment includes:
- **Rancher**: Multi-cluster Kubernetes management platform
- **Prometheus**: Metrics collection and monitoring
- **Grafana**: Visualization and dashboarding
- **Alertmanager**: Alert routing and management
- **ArgoCD**: GitOps continuous delivery
- **Jenkins Operator**: Kubernetes-native Jenkins automation
- **Ingress**: TLS-enabled external access with Let's Encrypt certificates

## Architecture

```
Jenkins (mars agent)
  ├── Terraform Init
  ├── Terraform Plan
  ├── Terraform Apply
  │   ├── Deploy Rancher (helm_release)
  │   ├── Deploy Prometheus Stack (helm_release)
  │   ├── Deploy ArgoCD (helm_release)
  │   ├── Deploy Jenkins Operator (helm_release)
  │   ├── Create Ingress (Rancher, Prometheus, Grafana, ArgoCD, Jenkins)
  │   └── Create Namespaces (cattle-system, monitoring, argocd, jenkins)
  └── Verify Deployment
```

## Prerequisites

### System Requirements
- Kubernetes cluster (v1.20+)
- `kubectl` configured and accessible
- Helm 3+ installed
- Terraform 1.0+ installed
- Jenkins with build agent labeled `mars`

### Kubernetes Components
- Ingress controller (NGINX recommended)
- cert-manager for TLS certificate management
- StorageClass for persistent volumes
- Sufficient cluster resources (minimum 4 cores, 8GB RAM)

### Jenkins Credentials
- `kubeconfig`: Jenkins credential containing your Kubernetes config file

## Quick Start

### 1. Deploy via Jenkins

1. Create a Jenkins pipeline job pointing to this repository
2. Ensure the Jenkins agent is labeled `mars`
3. Configure build parameters:
   - `RANCHER_HOSTNAME`: Your Rancher FQDN (e.g., rancher.example.com)
   - `RANCHER_PASSWORD`: Bootstrap password for Rancher admin
   - `RANCHER_REPLICAS`: Number of Rancher pods (default: 3)

4. Build the pipeline

### 2. Deploy via Terraform Directly

```bash
cd terraform
terraform init
terraform plan \
  -var="rancher_hostname=rancher.example.com" \
  -var="rancher_password=your-secure-password" \
  -var="prometheus_hostname=prometheus.example.com" \
  -var="grafana_hostname=grafana.example.com" \
  -var="grafana_admin_password=grafana-password"
terraform apply
```

## Configuration

### Rancher Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `release_name` | Helm release name | `rancher` |
| `namespace` | Kubernetes namespace | `cattle-system` |
| `rancher_hostname` | FQDN for Rancher access | Required |
| `rancher_password` | Bootstrap password | Required |
| `rancher_replicas` | Number of replicas | `3` |
| `letsencrypt_email` | Email for Let's Encrypt | `admin@example.com` |

### Monitoring Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_monitoring` | Enable Prometheus stack | `true` |
| `enable_grafana` | Enable Grafana dashboards | `true` |
| `enable_alertmanager` | Enable Alertmanager | `true` |
| `prometheus_chart_version` | Prometheus chart version | `51.0.0` |
| `prometheus_hostname` | Prometheus FQDN | `prometheus.example.com` |
| `grafana_hostname` | Grafana FQDN | `grafana.example.com` |
| `grafana_admin_password` | Grafana admin password | `changeme` |

### ArgoCD Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_argocd` | Enable ArgoCD deployment | `true` |
| `argocd_chart_version` | ArgoCD chart version | `5.46.0` |
| `argocd_hostname` | ArgoCD FQDN | `argocd.example.com` |
| `argocd_replicas` | Number of ArgoCD replicas | `2` |
| `argocd_admin_password` | ArgoCD admin password | `changeme` |

### Jenkins Operator Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_jenkins_operator` | Enable Jenkins Operator | `true` |
| `jenkins_operator_chart_version` | Jenkins Operator chart version | `0.7.0` |
| `jenkins_hostname` | Jenkins FQDN | `jenkins.example.com` |
| `jenkins_admin_password` | Jenkins admin password | `changeme` |
| `jenkins_storage_size` | Jenkins persistent storage | `20Gi` |

### Infrastructure Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ingress_class_name` | Ingress controller class | `nginx` |
| `storage_class_name` | Storage class name | `standard` |
| `prometheus_storage_size` | Prometheus storage | `50Gi` |
| `grafana_storage_size` | Grafana storage | `10Gi` |
| `kubeconfig_path` | Kubeconfig file path | `~/.kube/config` |

## Access Points

Once deployed, access your components via:

- **Rancher**: `https://rancher.example.com`
- **Prometheus**: `https://prometheus.example.com`
- **Grafana**: `https://grafana.example.com`
  - Username: `admin`
  - Password: `<grafana_admin_password>`
- **ArgoCD**: `https://argocd.example.com`
  - Username: `admin`
  - Password: `<argocd_admin_password>`
- **Jenkins**: `https://jenkins.example.com`
  - Username: `admin`
  - Password: `<jenkins_admin_password>`

## File Structure

```
.
├── Jenkinsfile                 # Jenkins pipeline configuration
├── terraform/
│   ├── main.tf                # Main Terraform configuration
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values
│   └── terraform.tfvars       # Optional variable values (create as needed)
└── README.md                   # This file
```

## Jenkinsfile Stages

1. **Checkout**: Clones the repository
2. **Terraform Init**: Initializes Terraform backend and providers
3. **Terraform Plan**: Generates execution plan
4. **Terraform Apply**: Applies configuration to cluster
5. **Verify Deployment**: Waits for Rancher rollout completion

## Terraform Outputs

After applying Terraform, the following outputs are available:

```bash
terraform output
```

Key outputs:
- `rancher_hostname` - Rancher access URL
- `prometheus_hostname` - Prometheus access URL (if enabled)
- `grafana_hostname` - Grafana access URL (if enabled)
- `monitoring_namespace` - Monitoring stack namespace
- `prometheus_status` - Status of Prometheus deployment

## Troubleshooting

### Deployment Stuck

Check pod status:
```bash
kubectl get pods -n cattle-system
kubectl get pods -n monitoring
```

View logs:
```bash
kubectl logs -n cattle-system -l app=rancher
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
```

### Certificate Issues

Verify cert-manager:
```bash
kubectl get certificates -n cattle-system
kubectl describe certificate rancher-tls -n cattle-system
```

### Storage Issues

Check PersistentVolumeClaims:
```bash
kubectl get pvc -n monitoring
kubectl describe pvc prometheus-kube-prometheus-prometheus-db-prometheus-kube-prometheus-prometheus-0 -n monitoring
```

### Ingress Not Working

Verify ingress controller:
```bash
kubectl get ingress -n cattle-system
kubectl get ingress -n monitoring
kubectl get ingress -n argocd
kubectl get ingress -n jenkins
```

Describe ingress:
```bash
kubectl describe ingress rancher-ingress -n cattle-system
kubectl describe ingress argocd-ingress -n argocd
kubectl describe ingress jenkins-ingress -n jenkins
```

## Cleanup

To remove all components:

```bash
cd terraform
terraform destroy \
  -var="rancher_hostname=rancher.example.com" \
  -var="rancher_password=your-password" \
  -var="prometheus_hostname=prometheus.example.com" \
  -var="grafana_hostname=grafana.example.com" \
  -var="grafana_admin_password=grafana-password" \
  -var="argocd_hostname=argocd.example.com" \
  -var="argocd_admin_password=argocd-password" \
  -var="jenkins_hostname=jenkins.example.com" \
  -var="jenkins_admin_password=jenkins-password"
```

## Advanced Configuration

### Custom Helm Values

Edit `terraform/main.tf` to customize Helm chart values in the `values` block for each `helm_release` resource.

### State Management

For production, configure remote state backend in `terraform/main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "your-bucket"
    key    = "rancher/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### Multiple Environments

Create separate variable files:
```bash
terraform apply -var-file="prod.tfvars"
terraform apply -var-file="staging.tfvars"
```

## Helm Charts Used

- **Rancher**: https://releases.rancher.com/server-charts/stable
- **Prometheus**: https://prometheus-community.github.io/helm-charts
- **ArgoCD**: https://argoproj.github.io/argo-helm
- **Jenkins Operator**: https://raw.githubusercontent.com/jenkinsci/helm-charts/main

## Security Considerations

- Use strong passwords for Rancher and Grafana
- Store sensitive values in Jenkins secrets
- Enable RBAC on your Kubernetes cluster
- Use network policies to restrict traffic
- Regularly update Rancher and monitoring stack versions
- Rotate bootstrap password after initial setup

## Support & Documentation

- Rancher Docs: https://ranchermanager.docs.rancher.com/
- Prometheus Docs: https://prometheus.io/docs/
- Grafana Docs: https://grafana.com/docs/
- ArgoCD Docs: https://argo-cd.readthedocs.io/
- Jenkins Operator Docs: https://jenkinsci.github.io/kubernetes-operator/
- Terraform Helm Provider: https://registry.terraform.io/providers/hashicorp/helm/latest/docs

## License

This deployment automation is provided as-is.
