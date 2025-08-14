data "helm_template" "flux_operator" {
  name      = "flux-operator"
  namespace = "kube-system"

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
  depends_on = [data.http.talos_health]
}

data "helm_template" "flux_instance" {
  name      = "flux-instance"
  namespace = "kube-system"

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
  depends_on = [data.http.talos_health]
}

resource "kubernetes_secret" "flux_secret" {
  count      = var.flux_secret_username == null || var.flux_secret_password == null ? 0 : 1
  depends_on = [data.http.talos_health]

  metadata {
    name      = var.flux_secret_name
    namespace = "kube-system"
  }

  data = {
    username = var.flux_secret_username
    password = var.flux_secret_password
  }

  type = "Opaque"
}
