resource "kubernetes_namespace_v1" "cert_manager" {
  metadata { name = local.namespaces.cert_manager }
}
