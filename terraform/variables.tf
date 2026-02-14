variable "release_name" {
  description = "Helm release name for Rancher"
  type        = string
  default     = "rancher"
}

variable "namespace" {
  description = "Kubernetes namespace for Rancher deployment"
  type        = string
  default     = "cattle-system"
}

variable "rancher_hostname" {
  description = "Hostname for Rancher ingress"
  type        = string
}

variable "rancher_replicas" {
  description = "Number of Rancher replicas"
  type        = number
  default     = 3
}

variable "rancher_password" {
  description = "Bootstrap password for Rancher admin user"
  type        = string
  sensitive   = true
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate"
  type        = string
  default     = "admin@example.com"
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "install_k3s" {
  description = "Install k3s cluster on the local machine"
  type        = bool
  default     = true
}

variable "ingress_class_name" {
  description = "Ingress class name (e.g., nginx, traefik)"
  type        = string
  default     = "nginx"
}

variable "enable_monitoring" {
  description = "Enable Prometheus monitoring stack"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Enable Grafana dashboards"
  type        = bool
  default     = true
}

variable "enable_alertmanager" {
  description = "Enable Alertmanager for alerts"
  type        = bool
  default     = true
}

variable "prometheus_chart_version" {
  description = "Version of kube-prometheus-stack Helm chart"
  type        = string
  default     = "51.0.0"
}

variable "prometheus_hostname" {
  description = "Hostname for Prometheus ingress"
  type        = string
  default     = "prometheus.example.com"
}

variable "grafana_hostname" {
  description = "Hostname for Grafana ingress"
  type        = string
  default     = "grafana.example.com"
}

variable "grafana_admin_password" {
  description = "Grafana admin user password"
  type        = string
  sensitive   = true
  default     = "changeme"
}

variable "storage_class_name" {
  description = "Storage class for Prometheus and Grafana persistent volumes"
  type        = string
  default     = "standard"
}

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus"
  type        = string
  default     = "50Gi"
}

variable "grafana_storage_size" {
  description = "Storage size for Grafana"
  type        = string
  default     = "10Gi"
}

variable "enable_argocd" {
  description = "Enable ArgoCD deployment"
  type        = bool
  default     = true
}

variable "argocd_chart_version" {
  description = "Version of ArgoCD Helm chart"
  type        = string
  default     = "5.46.0"
}

variable "argocd_hostname" {
  description = "Hostname for ArgoCD ingress"
  type        = string
  default     = "argocd.example.com"
}

variable "argocd_replicas" {
  description = "Number of ArgoCD replicas"
  type        = number
  default     = 2
}

variable "argocd_admin_password" {
  description = "ArgoCD admin password"
  type        = string
  sensitive   = true
  default     = "changeme"
}

variable "enable_jenkins_operator" {
  description = "Enable Jenkins Operator deployment"
  type        = bool
  default     = true
}

variable "jenkins_operator_chart_version" {
  description = "Version of Jenkins Operator Helm chart"
  type        = string
  default     = "0.7.0"
}

variable "jenkins_hostname" {
  description = "Hostname for Jenkins ingress"
  type        = string
  default     = "jenkins.example.com"
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password"
  type        = string
  sensitive   = true
  default     = "changeme"
}

variable "jenkins_storage_size" {
  description = "Storage size for Jenkins"
  type        = string
  default     = "20Gi"
}

variable "enable_vault" {
  description = "Enable Vault for secrets management"
  type        = bool
  default     = true
}

variable "vault_chart_version" {
  description = "Version of Vault Helm chart"
  type        = string
  default     = "0.27.0"
}

variable "vault_hostname" {
  description = "Hostname for Vault ingress"
  type        = string
  default     = "vault.example.com"
}

variable "vault_storage_size" {
  description = "Storage size for Vault data"
  type        = string
  default     = "10Gi"
}

variable "vault_dev_mode" {
  description = "Enable Vault dev mode (not for production)"
  type        = bool
  default     = true
}
