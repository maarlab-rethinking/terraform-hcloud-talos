data "helm_template" "spegel" {
  name      = "spegel"
  namespace = "spegel"

  repository   = "oci://ghcr.io/spegel-org/helm-charts"
  chart        = "spegel"
  version      = var.spegel_version
  kube_version = var.kubernetes_version

  set = [
    {
      name  = "spegel.containerdRegistryConfigPath"
      value = "/etc/cri/conf.d/hosts"
    }
  ]
}

data "kubectl_file_documents" "spegel" {
  content = data.helm_template.spegel.manifest
}

resource "kubernetes_namespace" "spegel" {
  metadata {
    name = data.helm_template.spegel.namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }

  depends_on = [
    data.http.talos_health
  ]
}

resource "kubectl_manifest" "apply_spegel" {
  for_each   = var.control_plane_count > 0 ? data.kubectl_file_documents.spegel.manifests : {}
  yaml_body  = each.value
  apply_only = true
  depends_on = [
    data.http.talos_health,
    kubernetes_namespace.spegel
  ]
}
