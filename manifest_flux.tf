resource "helm_release" "flux_operator" {
  depends_on = [helm_release.cilium]

  name             = "flux-operator"
  namespace        = "flux-system"
  repository       = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart            = "flux-operator"
  create_namespace = true
  version          = var.flux_operator_version
  values = concat(
    var.flux_operator_values != null ? var.flux_operator_values : [],
    local.total_worker_count == 0 ? [yamlencode({
      tolerations = [
        {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ]
    })] : []
  )
}

locals {
  flux_instance_default_values = {
    instance = {
      components = [
        "source-controller",
        "kustomize-controller",
        "helm-controller",
        "notification-controller",
        "image-reflector-controller",
        "image-automation-controller"
      ]
      sync = merge({
        kind = "GitRepository"
        url  = var.flux_bootstrap_url
        ref  = "refs/heads/${var.flux_branch}"
        path = var.flux_cluster_path
        }, var.flux_secret_username != null && var.flux_secret_password != null ? {
        pullSecret = try(kubernetes_secret_v1.flux_secret[0].metadata[0].name, "")
      } : {})
      distribution = {
        artifact = "oci://ghcr.io/controlplaneio-fluxcd/flux-operator-manifests:v${var.flux_operator_version}"
      }
      tolerations = local.total_worker_count == 0 ? [
        {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ] : []
    }
  }
}

resource "helm_release" "flux_instance" {
  count      = var.flux_instance_values != null || var.flux_bootstrap_url != null ? 1 : 0
  depends_on = [helm_release.flux_operator]

  name       = "flux-instance"
  namespace  = "flux-system"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-instance"
  version    = var.flux_instance_version

  values = var.flux_instance_values != null ? var.flux_instance_values : [yamlencode(local.flux_instance_default_values)]
}

resource "kubernetes_secret_v1" "flux_secret" {
  count      = var.flux_secret_username == null || var.flux_secret_password == null ? 0 : 1
  depends_on = [helm_release.flux_operator]

  metadata {
    name      = "pull-secret"
    namespace = "flux-system"
  }

  data = {
    username = var.flux_secret_username
    password = var.flux_secret_password
  }

  type = "Opaque"
}
