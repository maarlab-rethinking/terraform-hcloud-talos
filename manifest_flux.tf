resource "helm_release" "flux_operator" {
  depends_on = [helm_release.cilium]

  name             = "flux-operator"
  namespace        = "flux-system"
  repository       = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart            = "flux-operator"
  create_namespace = true
  version          = var.flux_operator_version
  values           = var.flux_operator_values
}

resource "helm_release" "flux_instance" {
  count      = var.flux_instance_values == null ? 0 : 1
  depends_on = [helm_release.flux_operator]

  name       = "flux-instance"
  namespace  = "flux-system"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-instance"
  version    = var.flux_instance_version
  values     = var.flux_instance_values
}

resource "kubernetes_secret" "flux_secret" {
  count      = var.flux_secret_username == null || var.flux_secret_password == null ? 0 : 1
  depends_on = [helm_release.flux_operator]

  metadata {
    name      = var.flux_secret_name
    namespace = "flux-system"
  }

  data = {
    username = var.flux_secret_username
    password = var.flux_secret_password
  }

  type = "Opaque"
}
