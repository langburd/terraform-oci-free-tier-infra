resource "kubernetes_namespace_v1" "traefik" {
  metadata { name = local.namespaces.traefik }
}
