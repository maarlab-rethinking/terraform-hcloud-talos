resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
}

data "helm_template" "flux_operator" {
  name      = "flux-operator"
  namespace = "flux-system"

  repository   = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart        = "flux-operator"
  version      = var.flux_operator_version
  kube_version = var.kubernetes_version

  values = var.flux_operator_values
}

data "kubectl_file_documents" "flux_operator" {
  content = data.helm_template.flux_operator.manifest
}

resource "kubectl_manifest" "apply_flux_operator" {
  for_each   = var.control_plane_count > 0 ? data.kubectl_file_documents.flux_operator.manifests : {}
  yaml_body  = each.value
  apply_only = true
  depends_on = [data.http.talos_health, kubernetes_namespace.flux_system, kubectl_manifest.apply_flux_instance]
}

data "helm_template" "flux_instance" {
  name      = "flux-instance"
  namespace = "flux-system"

  repository   = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart        = "flux-instance"
  version      = var.flux_instance_version
  kube_version = var.kubernetes_version

  values = var.flux_instance_values
}

data "kubectl_file_documents" "flux_instance" {
  content = data.helm_template.flux_instance.manifest
}

resource "kubectl_manifest" "apply_flux_instance" {
  for_each   = var.control_plane_count > 0 ? data.kubectl_file_documents.flux_instance.manifests : {}
  yaml_body  = each.value
  apply_only = true
  depends_on = [data.http.talos_health, kubernetes_namespace.flux_system]
}

resource "kubernetes_secret" "flux_secret" {
  count      = var.flux_secret_username == null || var.flux_secret_password == null ? 0 : 1
  depends_on = [talos_cluster_kubeconfig.this]

  metadata {
    name      = var.flux_secret_name
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }

  data = {
    username = base64encode(var.flux_secret_username)
    password = base64encode(var.flux_secret_password)
  }

  type = "Opaque"
}
