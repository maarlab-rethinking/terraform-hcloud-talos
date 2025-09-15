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
  count      = var.flux_instance_values != null || var.flux_bootstrap_url != null ? 1 : 0
  depends_on = [helm_release.flux_operator]

  name       = "flux-instance"
  namespace  = "flux-system"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-instance"
  version    = var.flux_instance_version

  values = var.flux_instance_values
  set = var.flux_instance_values == null && var.flux_bootstrap_url != null ? concat([
    {
      name  = "instance.components[0]"
      value = "source-controller"
    },
    {
      name  = "instance.components[1]"
      value = "kustomize-controller"
    },
    {
      name  = "instance.components[2]"
      value = "helm-controller"
    },
    {
      name  = "instance.components[3]"
      value = "notification-controller"
    },
    {
      name  = "instance.components[4]"
      value = "image-reflector-controller"
    },
    {
      name  = "instance.components[5]"
      value = "image-automation-controller"
    },
    {
      name  = "instance.sync.kind"
      value = "GitRepository"
    },
    {
      name  = "instance.sync.url"
      value = var.flux_bootstrap_url
    },
    {
      name  = "instance.sync.ref"
      value = "refs/heads/${var.flux_branch}"
    },
    {
      name  = "instance.sync.path"
      value = var.flux_cluster_path
    }
    ], var.flux_secret_username != null && var.flux_secret_password != null ? [
    {
      name  = "instance.sync.pullSecret"
      value = kubernetes_secret.flux_secret[0].metadata[0].name
    }
  ] : []) : null
}

resource "kubernetes_secret" "flux_secret" {
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
