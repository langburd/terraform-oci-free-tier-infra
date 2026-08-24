resource "kubernetes_namespace" "argocd" {
  metadata { name = local.namespaces.argocd }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata { name = local.namespaces.cert_manager }
}

resource "kubernetes_namespace" "traefik" {
  metadata { name = local.namespaces.traefik }
}
