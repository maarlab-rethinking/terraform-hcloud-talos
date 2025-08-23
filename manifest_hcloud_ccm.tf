resource "helm_release" "hcloud_ccm" {
  name      = "hcloud-cloud-controller-manager"
  namespace = "kube-system"

  repository = "https://charts.hetzner.cloud"
  chart      = "hcloud-cloud-controller-manager"
  version    = var.hcloud_ccm_version

  set = [
    {
      name  = "networking.enabled"
      value = "true"
    },
    {
      name  = "networking.clusterCIDR"
      value = local.pod_ipv4_cidr
    }
  ]

  depends_on = [data.http.talos_health]
}
