# ArgoCD repository Secret (SSH).
resource "kubernetes_secret_v1" "gitops_repo" {
  depends_on = [helm_release.argocd]

  data = {
    sshPrivateKey = tls_private_key.deploy.private_key_openssh
    type          = "git"
    url           = local.gitops_repo_url
  }
  metadata {
    labels    = { "argocd.argoproj.io/secret-type" = "repository" }
    name      = "gitops-repo"
    namespace = local.namespaces.argocd
  }
  type = "Opaque"
}
