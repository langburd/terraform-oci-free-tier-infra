# Kubernetes provider v3 deprecated the unversioned resource names in favour of the
# _v1 variants. Re-addressing the existing state entries has to be done with
# removed+import pairs, NOT `moved` blocks: a cross-resource-type move requires the
# provider to implement the MoveResourceState RPC, and hashicorp/kubernetes does not
# ("The <type> resource type does not support moving resource state across resource
# types"). `removed` with `destroy = false` forgets the old address without touching
# the cluster object, and `import` adopts that same object at the new address.
#
# ONE-SHOT: delete this whole file after the apply that consumes it succeeds.
# Leaving it in place makes every later plan re-plan the imports.

removed {
  from = kubernetes_namespace.argocd
  lifecycle { destroy = false }
}

import {
  to = kubernetes_namespace_v1.argocd
  id = "argocd"
}

removed {
  from = kubernetes_namespace.cert_manager
  lifecycle { destroy = false }
}

import {
  to = kubernetes_namespace_v1.cert_manager
  id = "cert-manager"
}

removed {
  from = kubernetes_namespace.traefik
  lifecycle { destroy = false }
}

import {
  to = kubernetes_namespace_v1.traefik
  id = "traefik"
}

removed {
  from = kubernetes_secret.cloudflare_token
  lifecycle { destroy = false }
}

import {
  to = kubernetes_secret_v1.cloudflare_token
  id = "cert-manager/cloudflare-api-token"
}

removed {
  from = kubernetes_secret.gitops_repo
  lifecycle { destroy = false }
}

import {
  to = kubernetes_secret_v1.gitops_repo
  id = "argocd/gitops-repo"
}
