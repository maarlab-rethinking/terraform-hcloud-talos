resource "helm_release" "cilium" {
  name      = "cilium"
  namespace = "kube-system"

  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium_version

  values = var.cilium_values != null ? var.cilium_values : null

  set = var.cilium_values == null ? [
    {
      name  = "operator.replicas"
      value = var.control_plane_count > 1 ? 2 : 1
    },
    {
      name  = "ipam.mode"
      value = "kubernetes"
    },
    {
      name  = "routingMode"
      value = "native"
    },
    {
      name  = "ipv4NativeRoutingCIDR"
      value = local.pod_ipv4_cidr
    },
    {
      name  = "kubeProxyReplacement"
      value = "true"
    },
    {
      name  = "bpf.masquerade"
      value = "false"
    },
    {
      name  = "loadBalancer.acceleration"
      value = "best-effort" # https://github.com/hcloud-talos/terraform-hcloud-talos/issues/119
    },
    {
      name  = "encryption.enabled"
      value = var.cilium_enable_encryption
    },
    {
      name  = "encryption.type"
      value = "wireguard"
    },
    {
      name  = "securityContext.capabilities.ciliumAgent"
      value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
    },
    {
      name  = "securityContext.capabilities.cleanCiliumState"
      value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
    },
    {
      name  = "cgroup.autoMount.enabled"
      value = false
    },
    {
      name  = "cgroup.hostRoot"
      value = "/sys/fs/cgroup"
    },
    {
      name  = "k8sServiceHost"
      value = "127.0.0.1"
    },
    {
      name  = "k8sServicePort"
      value = local.api_port_kube_prism
    },
    {
      name  = "hubble.enabled"
      value = false
    },
    {
      name  = "prometheus.serviceMonitor.enabled"
      value = var.cilium_enable_service_monitors
    },
    {
      name  = "prometheus.serviceMonitor.trustCRDsExist"
      value = var.cilium_enable_service_monitors
    },
    {
      name  = "operator.prometheus.serviceMonitor.enabled"
      value = var.cilium_enable_service_monitors
    }
  ] : null

  depends_on = [data.http.talos_health]
}

data "helm_template" "prometheus_operator_crds" {
  count        = var.deploy_prometheus_operator_crds ? 1 : 0
  chart        = "prometheus-operator-crds"
  name         = "prometheus-operator-crds"
  repository   = "https://prometheus-community.github.io/helm-charts"
  kube_version = var.kubernetes_version
}

data "kubectl_file_documents" "prometheus_operator_crds" {
  count   = var.deploy_prometheus_operator_crds ? 1 : 0
  content = data.helm_template.prometheus_operator_crds[0].manifest
}

resource "kubectl_manifest" "apply_prometheus_operator_crds" {
  for_each          = var.control_plane_count > 0 && var.deploy_prometheus_operator_crds ? data.kubectl_file_documents.prometheus_operator_crds[0].manifests : {}
  yaml_body         = each.value
  server_side_apply = true
  apply_only        = true
  depends_on        = [data.http.talos_health]
}
