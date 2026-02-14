output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.rancher.name
}

output "namespace" {
  description = "Kubernetes namespace where Rancher is deployed"
  value       = helm_release.rancher.namespace
}

output "rancher_status" {
  description = "Status of the Rancher Helm release"
  value       = helm_release.rancher.status
}

output "rancher_chart_version" {
  description = "Version of the deployed Rancher chart"
  value       = helm_release.rancher.version
}

output "rancher_hostname" {
  description = "Rancher access URL"
  value       = "https://${var.rancher_hostname}"
}

output "monitoring_enabled" {
  description = "Whether monitoring stack is enabled"
  value       = var.enable_monitoring
}

output "prometheus_status" {
  description = "Status of Prometheus Helm release"
  value       = var.enable_monitoring ? helm_release.prometheus[0].status : "disabled"
}

output "prometheus_hostname" {
  description = "Prometheus access URL"
  value       = var.enable_monitoring ? "https://${var.prometheus_hostname}" : "disabled"
}

output "grafana_status" {
  description = "Status of Grafana"
  value       = var.enable_grafana && var.enable_monitoring ? helm_release.prometheus[0].status : "disabled"
}

output "grafana_hostname" {
  description = "Grafana access URL"
  value       = var.enable_grafana && var.enable_monitoring ? "https://${var.grafana_hostname}" : "disabled"
}

output "grafana_admin_user" {
  description = "Grafana admin username"
  value       = var.enable_grafana && var.enable_monitoring ? "admin" : "disabled"
}

output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring stack"
  value       = var.enable_monitoring ? kubernetes_namespace.monitoring[0].metadata[0].name : "disabled"
}

output "argocd_status" {
  description = "Status of ArgoCD Helm release"
  value       = var.enable_argocd ? helm_release.argocd[0].status : "disabled"
}

output "argocd_hostname" {
  description = "ArgoCD access URL"
  value       = var.enable_argocd ? "https://${var.argocd_hostname}" : "disabled"
}

output "argocd_admin_user" {
  description = "ArgoCD admin username"
  value       = var.enable_argocd ? "admin" : "disabled"
}

output "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  value       = var.enable_argocd ? kubernetes_namespace.argocd[0].metadata[0].name : "disabled"
}

output "jenkins_status" {
  description = "Status of Jenkins Operator Helm release"
  value       = var.enable_jenkins_operator ? helm_release.jenkins_operator[0].status : "disabled"
}

output "jenkins_hostname" {
  description = "Jenkins access URL"
  value       = var.enable_jenkins_operator ? "https://${var.jenkins_hostname}" : "disabled"
}

output "jenkins_admin_user" {
  description = "Jenkins admin username"
  value       = var.enable_jenkins_operator ? "admin" : "disabled"
}

output "jenkins_namespace" {
  description = "Kubernetes namespace for Jenkins"
  value       = var.enable_jenkins_operator ? kubernetes_namespace.jenkins_operator[0].metadata[0].name : "disabled"
}
