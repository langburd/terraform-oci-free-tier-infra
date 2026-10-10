# Cluster CA is not exported by the OKE module, so derive it from the cluster's
# kube-config at apply time (Task 1 fallback path). The kube-config carries the
# base64 CA in clusters[0].cluster["certificate-authority-data"].
data "oci_containerengine_cluster_kube_config" "this" {
  cluster_id = local.cluster_id
}

locals {
  cluster_ca = yamldecode(data.oci_containerengine_cluster_kube_config.this.content)["clusters"][0]["cluster"]["certificate-authority-data"]
}
