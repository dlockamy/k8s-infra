terraform {
  required_version = ">= 1.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
  }
}

locals {
  monitoring_namespace = "monitoring"
  k3s_config_path     = "${path.module}/.kube/config"
  k3s_kubeconfig_dir  = "${path.module}/.kube"
  vault_namespace     = "vault"
}

# Install k3s cluster
resource "null_resource" "k3s_install" {
  count = var.install_k3s ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing k3s..."
      curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE=644 sh -
      
      # Wait for k3s to be ready
      for i in {1..30}; do
        if sudo kubectl get nodes > /dev/null 2>&1; then
          echo "k3s is ready"
          break
        fi
        echo "Waiting for k3s to be ready... ($i/30)"
        sleep 2
      done
      
      # Extract kubeconfig
      mkdir -p ${local.k3s_kubeconfig_dir}
      sudo cat /etc/rancher/k3s/k3s.yaml > ${local.k3s_config_path}
      chmod 600 ${local.k3s_config_path}
      
      # Update kubeconfig to use localhost instead of internal IP
      sed -i.bak 's|https://[^:]*:6443|https://localhost:6443|g' ${local.k3s_config_path}
      
      echo "k3s installation complete"
    EOT
  }
}

# Read the generated kubeconfig
data "local_file" "k3s_kubeconfig" {
  count    = var.install_k3s ? 1 : 0
  filename = local.k3s_config_path
  
  depends_on = [null_resource.k3s_install]
}

# Output the kubeconfig for Jenkins to save
resource "local_file" "kubeconfig_output" {
  count    = var.install_k3s ? 1 : 0
  filename = "${path.module}/kubeconfig.txt"
  content  = data.local_file.k3s_kubeconfig[0].content
}

provider "kubernetes" {
  config_path = var.install_k3s ? local.k3s_config_path : var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.install_k3s ? local.k3s_config_path : var.kubeconfig_path
  }
}

# Install cert-manager (required for Let's Encrypt issuers)
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  values = [
    yamlencode({
      installCRDs = true
      # Optionally tune resources here
    })
  ]

  wait    = true
  timeout = 600
}

# Create a ClusterIssuer for Let's Encrypt (production)
resource "null_resource" "cert_manager_issuer" {
  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: ${var.ingress_class_name}
EOF
    EOT

    environment = {
      KUBECONFIG = var.install_k3s ? local.k3s_config_path : var.kubeconfig_path
    }
  }

  depends_on = [helm_release.cert_manager]
}

# Create namespace
resource "kubernetes_namespace" "rancher" {
  metadata {
    name = var.namespace
  }
}

# Deploy Rancher using Helm provider
resource "helm_release" "rancher" {
  name             = var.release_name
  repository       = "https://releases.rancher.com/server-charts/stable"
  chart            = "rancher"
  namespace        = kubernetes_namespace.rancher.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      hostname    = var.rancher_hostname
      replicas    = var.rancher_replicas
      bootstrapPassword = var.rancher_password
      ingress = {
        enabled = true
      }

      # Additional recommended settings
      tls = "ingress"
    
      letsEncrypt = {
        email = var.letsencrypt_email
      }
      
      # Monitoring
      prometheus = {
        create = var.enable_monitoring
      }
    })
  ]

  wait     = true
  timeout  = 600 # 10 minutes

  depends_on = [kubernetes_namespace.rancher, helm_release.cert_manager, null_resource.cert_manager_issuer]
}

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name = local.monitoring_namespace
  }
}

# Deploy Prometheus using Helm provider
resource "helm_release" "prometheus" {
  count = var.enable_monitoring ? 1 : 0

  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = kubernetes_namespace.monitoring[0].metadata[0].name
  create_namespace = false
  version          = var.prometheus_chart_version

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention         = "15d"
          storageClassName  = var.storage_class_name
          storageSize       = var.prometheus_storage_size
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
        }
      }
      grafana = {
        enabled = var.enable_grafana
        adminPassword = var.grafana_admin_password
        persistence = {
          enabled      = true
          size         = var.grafana_storage_size
          storageClassName = var.storage_class_name
        }
      }
      alertmanager = {
        enabled = var.enable_alertmanager
      }
    })
  ]

  wait     = true
  timeout  = 600

  depends_on = [kubernetes_namespace.monitoring, helm_release.rancher]
}

# Create Ingress for Rancher
resource "kubernetes_ingress_v1" "rancher" {
  metadata {
    name      = "rancher-ingress"
    namespace = kubernetes_namespace.rancher.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"      = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    ingress_class_name = var.ingress_class_name
    tls {
      hosts       = [var.rancher_hostname]
      secret_name = "rancher-tls"
    }

    rule {
      host = var.rancher_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "rancher"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.rancher]
}

# Create Ingress for Prometheus (if monitoring is enabled)
resource "kubernetes_ingress_v1" "prometheus" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name      = "prometheus-ingress"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"      = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    ingress_class_name = var.ingress_class_name
    tls {
      hosts       = [var.prometheus_hostname]
      secret_name = "prometheus-tls"
    }

    rule {
      host = var.prometheus_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "prometheus-kube-prometheus-prometheus"
              port {
                number = 9090
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.prometheus]
}

# Create Ingress for Grafana (if monitoring and Grafana are enabled)
resource "kubernetes_ingress_v1" "grafana" {
  count = var.enable_monitoring && var.enable_grafana ? 1 : 0

  metadata {
    name      = "grafana-ingress"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"      = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    ingress_class_name = var.ingress_class_name
    tls {
      hosts       = [var.grafana_hostname]
      secret_name = "grafana-tls"
    }

    rule {
      host = var.grafana_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "prometheus-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.prometheus]
}

# Create ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name = "argocd"
  }
}

# Deploy ArgoCD using Helm provider
resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = kubernetes_namespace.argocd[0].metadata[0].name
  create_namespace = false
  version          = var.argocd_chart_version

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
      }
      redis = {
        enabled = true
      }
      controller = {
        replicas = var.argocd_replicas
      }
      repoServer = {
        replicas = var.argocd_replicas
      }
      configs = {
        secret = {
          argocdServerAdminPassword = var.argocd_admin_password
        }
      }
    })
  ]

  wait     = true
  timeout  = 600

  depends_on = [kubernetes_namespace.argocd, helm_release.rancher]
}

# Create Ingress for ArgoCD
resource "kubernetes_ingress_v1" "argocd" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name      = "argocd-ingress"
    namespace = kubernetes_namespace.argocd[0].metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"      = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    ingress_class_name = var.ingress_class_name
    tls {
      hosts       = [var.argocd_hostname]
      secret_name = "argocd-tls"
    }

    rule {
      host = var.argocd_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}

# Create Jenkins Operator namespace
resource "kubernetes_namespace" "jenkins_operator" {
  count = var.enable_jenkins_operator ? 1 : 0

  metadata {
    name = "jenkins"
  }
}

# Deploy Jenkins Operator using Helm provider
resource "helm_release" "jenkins_operator" {
  count = var.enable_jenkins_operator ? 1 : 0

  name             = "jenkins-operator"
  repository       = "https://raw.githubusercontent.com/jenkinsci/helm-charts/main"
  chart            = "jenkins-operator"
  namespace        = kubernetes_namespace.jenkins_operator[0].metadata[0].name
  create_namespace = false
  version          = var.jenkins_operator_chart_version

  values = [
    yamlencode({
      jenkins = {
        enabled = true
        master = {
          adminPassword = var.jenkins_admin_password
          resources = {
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "2000m"
              memory = "2Gi"
            }
          }
        }
      }
      persistence = {
        enabled      = true
        size         = var.jenkins_storage_size
        storageClassName = var.storage_class_name
      }
    })
  ]

  wait     = true
  timeout  = 600

  depends_on = [kubernetes_namespace.jenkins_operator, helm_release.rancher]
}

# Create Ingress for Jenkins
resource "kubernetes_ingress_v1" "jenkins" {
  count = var.enable_jenkins_operator ? 1 : 0

  metadata {
    name      = "jenkins-ingress"
    namespace = kubernetes_namespace.jenkins_operator[0].metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"      = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    ingress_class_name = var.ingress_class_name
    tls {
      hosts       = [var.jenkins_hostname]
      secret_name = "jenkins-tls"
    }

    rule {
      host = var.jenkins_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "jenkins-operator-http"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.jenkins_operator]
}

# Create Vault namespace
resource "kubernetes_namespace" "vault" {
  count = var.enable_vault ? 1 : 0

  metadata {
    name = local.vault_namespace
  }
}

# Deploy Vault using Helm provider
resource "helm_release" "vault" {
  count = var.enable_vault ? 1 : 0

  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = kubernetes_namespace.vault[0].metadata[0].name
  create_namespace = false
  version          = var.vault_chart_version

  values = [
    yamlencode({
      server = {
        dataStorage = {
          size             = var.vault_storage_size
          storageClassName = var.storage_class_name
        }
        dev = {
          enabled = var.vault_dev_mode
        }
      }
      ui = {
        enabled = true
      }
    })
  ]

  wait     = true
  timeout  = 600

  depends_on = [kubernetes_namespace.vault]
}

# Wait for Vault to be ready
resource "null_resource" "vault_ready" {
  count = var.enable_vault ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Vault to be ready..."
      for i in {1..60}; do
        if kubectl get pods -n vault -l app.kubernetes.io/name=vault --no-headers 2>/dev/null | grep -q Running; then
          echo "Vault is ready"
          break
        fi
        echo "Waiting for Vault pod... ($i/60)"
        sleep 2
      done
    EOT
  }

  depends_on = [helm_release.vault]
}

# Create Ingress for Vault
resource "kubernetes_ingress_v1" "vault" {
  count = var.enable_vault ? 1 : 0

  metadata {
    name      = "vault-ingress"
    namespace = kubernetes_namespace.vault[0].metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"      = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    ingress_class_name = var.ingress_class_name
    tls {
      hosts       = [var.vault_hostname]
      secret_name = "vault-tls"
    }

    rule {
      host = var.vault_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "vault"
              port {
                number = 8200
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.vault]
}

# Store credentials in Vault
resource "null_resource" "vault_backup_credentials" {
  count = var.enable_vault ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Setting up Vault and backing up credentials..."
      
      # Get Vault pod name
      VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
      echo "Using Vault pod: $VAULT_POD"
      
      # Store Rancher credentials
      if [ ! -z "${var.rancher_password}" ]; then
        echo "Backing up Rancher credentials..."
        kubectl exec -n vault $VAULT_POD -- \
          vault kv put secret/rancher/admin \
            username="admin" \
            password="${var.rancher_password}" \
            hostname="${var.rancher_hostname}" || echo "Note: Vault KV v2 may need initialization"
      fi
      
      # Store Grafana credentials
      if [ ! -z "${var.grafana_admin_password}" ] && [ "${var.enable_grafana}" = "true" ]; then
        echo "Backing up Grafana credentials..."
        kubectl exec -n vault $VAULT_POD -- \
          vault kv put secret/grafana/admin \
            username="admin" \
            password="${var.grafana_admin_password}" \
            hostname="${var.grafana_hostname}" || true
      fi
      
      # Store ArgoCD credentials
      if [ ! -z "${var.argocd_admin_password}" ] && [ "${var.enable_argocd}" = "true" ]; then
        echo "Backing up ArgoCD credentials..."
        kubectl exec -n vault $VAULT_POD -- \
          vault kv put secret/argocd/admin \
            username="admin" \
            password="${var.argocd_admin_password}" \
            hostname="${var.argocd_hostname}" || true
      fi
      
      # Store Jenkins credentials
      if [ ! -z "${var.jenkins_admin_password}" ] && [ "${var.enable_jenkins_operator}" = "true" ]; then
        echo "Backing up Jenkins credentials..."
        kubectl exec -n vault $VAULT_POD -- \
          vault kv put secret/jenkins/admin \
            username="admin" \
            password="${var.jenkins_admin_password}" \
            hostname="${var.jenkins_hostname}" || true
      fi
      
      echo "Credential backup to Vault completed"
    EOT
    
    environment = {
      KUBECONFIG = var.install_k3s ? local.k3s_config_path : var.kubeconfig_path
    }
  }

  depends_on = [
    null_resource.vault_ready,
    helm_release.rancher,
    helm_release.prometheus,
    helm_release.argocd,
    helm_release.jenkins_operator
  ]
}

# Save Vault root token and unseal keys to local file
resource "local_file" "vault_credentials" {
  count    = var.enable_vault ? 1 : 0
  filename = "${path.module}/vault-credentials.txt"
  content  = <<-EOT
# Vault Credentials
# Generated at: ${timestamp()}

## Access Information
Vault URL: https://${var.vault_hostname}
Vault Namespace: ${local.vault_namespace}
Dev Mode: ${var.vault_dev_mode}

## Important: Save these credentials in a secure location
## Dev mode uses a pre-unsealed vault with root token: hvac.root

## To access Vault:
1. Open browser: https://${var.vault_hostname}
2. Enter root token when prompted (shown in Vault logs during dev mode)

## To retrieve stored credentials:
vault login <root-token>
vault kv get secret/rancher/admin
vault kv get secret/grafana/admin
vault kv get secret/argocd/admin
vault kv get secret/jenkins/admin

## Vault Pod Access
kubectl -n vault exec -it <pod-name> -- vault

## Production Notes
For production use, DO NOT use dev mode (set vault_dev_mode = false)
Enable Vault authentication methods and configure proper unseal keys
Refer to Vault documentation: https://www.vaultproject.io/docs

## Backed up Secrets
- Rancher admin credentials (username: admin)
- Grafana admin credentials (username: admin)
- ArgoCD admin credentials (username: admin)
- Jenkins admin credentials (username: admin)
  EOT

  depends_on = [helm_release.vault]
}

