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
- **Vault**: Secrets management and credential storage
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
  │   ├── Deploy Vault (helm_release)
  │   ├── Create Ingress (Rancher, Prometheus, Grafana, ArgoCD, Jenkins, Vault)
  │   ├── Store credentials in Vault
  │   └── Create Namespaces (cattle-system, monitoring, argocd, jenkins, vault)
  └── Verify Deployment
```

## Prerequisites

### Prerequisites

### System Requirements
- Jenkins with build agent labeled `mars`
- The `mars` agent must have:
  - curl installed
  - For local installation: sudo access (for k3s installation)
  - For remote installation: SSH client, SSH key-based authentication configured
  - At least 4 CPU cores and 8GB RAM
  - Linux OS (Ubuntu 20.04+ recommended)
- Terraform 1.0+ installed
- kubectl installed (k3s will provide this)

### Kubernetes Components (Automatic)

When `install_k3s=true` (default):
- k3s cluster is automatically installed on the Jenkins agent
- Kubeconfig is automatically extracted and saved
- All subsequent deployments use this k3s cluster

OR manually provide:
- Ingress controller (NGINX recommended)
- cert-manager for TLS certificate management
- StorageClass for persistent volumes

### Jenkins Credentials
- `kubeconfig`: Jenkins credential containing your Kubernetes config file

## Quick Start

### 1. Deploy via Jenkins

1. Create a Jenkins pipeline job pointing to this repository
2. Ensure the Jenkins agent is labeled `mars`
3. The pipeline will automatically:
   - Install k3s cluster on the specified host via SSH (or locally)
   - Extract and display the kubeconfig
   - Configure Terraform to use k3s
   - Deploy all Helm charts
4. Configure build parameters when triggering the job:
   - `K3S_HOST`: Remote host IP/hostname or `localhost` (default: `localhost`)
   - `K3S_SSH_USER`: SSH user for remote host (default: `ubuntu`)
   - `K3S_INSTALL_PATH`: Installation path on remote host (default: `/opt/k3s`)
   - `RANCHER_HOSTNAME`: Your Rancher FQDN (e.g., rancher.example.com)
   - `RANCHER_PASSWORD`: Bootstrap password for Rancher admin
   - `RANCHER_REPLICAS`: Number of Rancher pods (default: 3)
5. Build the pipeline

**Remote Installation Example:**
```
K3S_HOST = 192.168.1.100
K3S_SSH_USER = ubuntu
K3S_INSTALL_PATH = /opt/k3s
RANCHER_HOSTNAME = rancher.example.com
```

**Local Installation Example:**
```
K3S_HOST = localhost
K3S_INSTALL_PATH = /opt/k3s
RANCHER_HOSTNAME = rancher.example.com
```

**Important Notes:**
- SSH keys must be configured on the Jenkins agent for remote installations
- The SSH user must have sudo access without password prompt
- After the first run, manually add the k3s kubeconfig to Jenkins credentials (see below)
- For remote hosts, ensure port 6443 is accessible from Jenkins agent

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

### Vault Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_vault` | Enable Vault deployment | `true` |
| `vault_chart_version` | Vault Helm chart version | `0.27.0` |
| `vault_hostname` | Vault FQDN | `vault.example.com` |
| `vault_storage_size` | Vault data storage size | `10Gi` |
| `vault_dev_mode` | Enable dev mode (not for production) | `true` |

### Infrastructure Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ingress_class_name` | Ingress controller class | `nginx` |
| `storage_class_name` | Storage class name | `standard` |
| `prometheus_storage_size` | Prometheus storage | `50Gi` |
| `grafana_storage_size` | Grafana storage | `10Gi` |
| `kubeconfig_path` | Kubeconfig file path (if not using k3s) | `~/.kube/config` |
| `install_k3s` | Automatically install k3s cluster | `true` |

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
- **Vault**: `https://vault.example.com`
  - Default: Dev mode with pre-unsealed access
  - All credentials backed up in `secret/` path

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
2. **Install k3s via SSH**: Automatically installs k3s on specified host:
   - Local installation if `K3S_HOST=localhost`
   - Remote installation via SSH if `K3S_HOST` is a remote IP/hostname
   - Creates install directory and waits for cluster readiness
3. **Extract k3s Kubeconfig**: Extracts kubeconfig and saves it locally:
   - For local: reads from `/etc/rancher/k3s/k3s.yaml`
   - For remote: copies via SCP from remote host
   - Updates server address to use correct hostname/IP
4. **Save k3s Config to Jenkins Credentials**: Outputs instructions to save kubeconfig as Jenkins credential `my_k3s_config`
5. **Terraform Init**: Initializes Terraform backend and providers
6. **Terraform Plan**: Generates execution plan
7. **Terraform Apply**: Applies configuration to k3s cluster
8. **Verify Deployment**: Waits for Rancher rollout completion

## Vault Secrets Management

Vault is automatically deployed and configured to back up all sensitive credentials:

### Stored Secrets
All credentials are stored in Vault's KV v2 secrets engine under these paths:
- `secret/rancher/admin` - Rancher admin credentials
- `secret/grafana/admin` - Grafana admin credentials
- `secret/argocd/admin` - ArgoCD admin credentials
- `secret/jenkins/admin` - Jenkins admin credentials

Each secret contains:
- `username` - Admin username
- `password` - Admin password
- `hostname` - Service hostname/FQDN

### Accessing Vault Secrets

**Via Web UI:**
1. Open `https://vault.example.com`
2. Login with root token (shown in Vault logs during dev mode)
3. Navigate to Secrets > secret > [path]

**Via Vault CLI:**
```bash
# Install Vault CLI
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault

# Access Vault from pod
kubectl -n vault exec -it vault-0 -- vault login
kubectl -n vault exec -it vault-0 -- vault kv get secret/rancher/admin

# Port-forward to local machine
kubectl -n vault port-forward vault-0 8200:8200
vault login <root-token>
vault kv get secret/rancher/admin
```

**Via Kubernetes Secrets:**
Vault credentials are also stored as Kubernetes secrets for application access:
```bash
kubectl get secrets -n vault
kubectl get secret vault-root-token -n vault -o jsonpath='{.data.token}' | base64 -d
```

### Vault Configuration (Dev Mode)

In dev mode (default):
- Vault starts pre-unsealed
- Root token is `hvac.root` (can be changed)
- Data is stored in memory (not persistent across restarts)
- NOT suitable for production

### Production Vault Setup

For production use:
1. Set `vault_dev_mode = false`
2. Configure proper storage backend (Raft, Consul, etc.)
3. Set up authentication methods (OIDC, Kubernetes, etc.)
4. Generate and securely store Unseal Keys
5. Configure Auto Unseal or Shamir Key Sharing
6. Enable audit logging

See [Vault Production Hardening](https://www.vaultproject.io/docs/configuration/seal) for details.

### Credential Rotation

To rotate credentials:
1. Update the credential in source system (e.g., change Rancher admin password)
2. Re-run Terraform deployment
3. Vault will update the stored secret automatically

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

### k3s Installation Issues

**Local Installation:**

Check k3s status:
```bash
sudo systemctl status k3s
sudo kubectl get nodes
sudo kubectl cluster-info
```

View k3s logs:
```bash
sudo journalctl -u k3s -f
```

Restart k3s:
```bash
sudo systemctl restart k3s
```

Uninstall k3s (if needed):
```bash
sudo /usr/local/bin/k3s-uninstall.sh
```

**Remote Installation:**

SSH to the remote host:
```bash
ssh -i ~/.ssh/id_rsa ubuntu@192.168.1.100
sudo systemctl status k3s
sudo kubectl get nodes
sudo kubectl cluster-info
```

Check SSH connectivity:
```bash
ssh -o StrictHostKeyChecking=no ubuntu@192.168.1.100 "echo SSH works"
```

Verify sudo access (no password prompt):
```bash
ssh ubuntu@192.168.1.100 "sudo -l"
```

### SSH Connection Issues

**Permission Denied:**
- Verify SSH key is in `~/.ssh/id_rsa` or set `SSH_KEY_PATH` environment variable
- Ensure Jenkins agent has correct SSH key permissions (600)
- Check remote host SSH config allows the user

**Timeout:**
- Verify remote host is reachable: `ping <host>`
- Check firewall rules on both machines
- Verify SSH port (22) is open

### Kubeconfig Not Found

Verify kubeconfig exists:
```bash
ls -la terraform/.kube/config
cat terraform/.kube/config
```

For remote installations, verify kubeconfig was copied:
```bash
ssh ubuntu@192.168.1.100 "cat /etc/rancher/k3s/k3s.yaml"
```

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
kubectl get pvc -n vault
kubectl describe pvc prometheus-kube-prometheus-prometheus-db-prometheus-kube-prometheus-prometheus-0 -n monitoring
```

### Vault Issues

Check Vault pod status:
```bash
kubectl get pods -n vault
kubectl describe pod vault-0 -n vault
kubectl logs -n vault vault-0
```

Verify Vault is unsealed:
```bash
kubectl exec -n vault vault-0 -- vault status
```

Access Vault directly:
```bash
kubectl exec -n vault -it vault-0 -- /bin/sh
vault status
vault kv list secret/
```

Retrieve stored credentials:
```bash
kubectl exec -n vault vault-0 -- vault kv get secret/rancher/admin
kubectl exec -n vault vault-0 -- vault kv get secret/grafana/admin
kubectl exec -n vault vault-0 -- vault kv get secret/argocd/admin
kubectl exec -n vault vault-0 -- vault kv get secret/jenkins/admin
```

### Ingress Not Working

Verify ingress controller:
```bash
kubectl get ingress -n cattle-system
kubectl get ingress -n monitoring
kubectl get ingress -n argocd
kubectl get ingress -n jenkins
kubectl get ingress -n vault
```

Describe ingress:
```bash
kubectl describe ingress rancher-ingress -n cattle-system
kubectl describe ingress argocd-ingress -n argocd
kubectl describe ingress jenkins-ingress -n jenkins
kubectl describe ingress vault-ingress -n vault
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
- **Vault**: https://helm.releases.hashicorp.com

## Security Considerations

- Use strong passwords for Rancher, Grafana, ArgoCD, and Jenkins
- Store sensitive values in Jenkins secrets and Vault
- Enable RBAC on your Kubernetes cluster
- Use network policies to restrict traffic
- Regularly update all components and dependencies
- Rotate bootstrap passwords after initial setup
- **Vault Production**: Disable dev mode for production use
- **Vault Storage**: Use persistent volume or external backend (Consul, AWS S3)
- **Vault Authentication**: Configure proper auth methods instead of root token
- Back up Vault encryption keys in a secure location
- Enable Vault audit logging for compliance

## Support & Documentation

- Rancher Docs: https://ranchermanager.docs.rancher.com/
- Prometheus Docs: https://prometheus.io/docs/
- Grafana Docs: https://grafana.com/docs/
- ArgoCD Docs: https://argo-cd.readthedocs.io/
- Jenkins Operator Docs: https://jenkinsci.github.io/kubernetes-operator/
- Vault Docs: https://www.vaultproject.io/docs
- Terraform Helm Provider: https://registry.terraform.io/providers/hashicorp/helm/latest/docs
- Terraform Vault Provider: https://registry.terraform.io/providers/hashicorp/vault/latest/docs

## License

This deployment automation is provided as-is.
