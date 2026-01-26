resource "helm_release" "hcloud_ccm" {
  count     = var.deploy_hcloud_ccm ? 1 : 0
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
