# State handover to ArgoCD: live objects stay, Terraform stops tracking them.

# now owned by ArgoCD addon traefik (langburd/gitops addons/traefik)
removed {
  from = helm_release.traefik

  lifecycle {
    destroy = false
  }
}

# now owned by ArgoCD addon cert-manager (langburd/gitops addons/cert-manager)
removed {
  from = helm_release.cert_manager

  lifecycle {
    destroy = false
  }
}

# now owned by ArgoCD addon traefik (langburd/gitops addons/traefik)
removed {
  from = kubernetes_namespace_v1.traefik

  lifecycle {
    destroy = false
  }
}

# now owned by ArgoCD addon cert-manager (langburd/gitops addons/cert-manager)
removed {
  from = kubernetes_namespace_v1.cert_manager

  lifecycle {
    destroy = false
  }
}

# now owned by ArgoCD addon cert-manager (langburd/gitops addons/cert-manager manifests)
removed {
  from = kubernetes_manifest.letsencrypt_issuer

  lifecycle {
    destroy = false
  }
}

# now owned by ArgoCD addon traefik (langburd/gitops addons/traefik manifests)
removed {
  from = kubernetes_manifest.argocd_certificate

  lifecycle {
    destroy = false
  }
}

# now owned by ArgoCD addon traefik (langburd/gitops addons/traefik manifests)
removed {
  from = kubernetes_manifest.argocd_httproute

  lifecycle {
    destroy = false
  }
}

# now owned by ArgoCD addon traefik (langburd/gitops addons/traefik manifests)
removed {
  from = kubernetes_manifest.argocd_http_redirect

  lifecycle {
    destroy = false
  }
}

# now owned by ArgoCD addon traefik (langburd/gitops addons/traefik manifests)
removed {
  from = kubernetes_manifest.argocd_ipallow

  lifecycle {
    destroy = false
  }
}
