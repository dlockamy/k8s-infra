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
  }
}

locals {
  monitoring_namespace = "monitoring"
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
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
      tls = {
        source = "letsEncrypt"
      }
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

  depends_on = [kubernetes_namespace.rancher]
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
