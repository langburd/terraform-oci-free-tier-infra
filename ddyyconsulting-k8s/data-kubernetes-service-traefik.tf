# Read the OCI LB public IP from the Traefik service status.
data "kubernetes_service_v1" "traefik" {
  metadata {
    name      = helm_release.traefik.name
    namespace = local.namespaces.traefik
  }
}

locals {
  traefik_lb_ip = data.kubernetes_service_v1.traefik.status[0].load_balancer[0].ingress[0].ip
}
