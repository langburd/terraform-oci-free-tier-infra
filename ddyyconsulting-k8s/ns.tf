resource "kubernetes_namespace_v1" "argocd" {
  metadata { name = local.namespaces.argocd }
}

resource "kubernetes_namespace_v1" "cert_manager" {
  metadata { name = local.namespaces.cert_manager }
}

resource "kubernetes_namespace_v1" "traefik" {
  metadata { name = local.namespaces.traefik }
}
