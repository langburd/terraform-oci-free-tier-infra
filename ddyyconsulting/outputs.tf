output "dev_compartment_id" {
  description = "The OCID of the Dev compartment"
  value       = module.dev_compartment.compartment_id
}

output "oci_profile_data" {
  description = "The data from the OCI profile"
  sensitive   = true
  value       = module.oci_profile_reader.oci_profile_data
}

output "oke_cluster_id" {
  description = "OCID of the OKE cluster."
  value       = module.oke_cluster.cluster_id
}

output "oke_cluster_state" {
  description = "Lifecycle state of the OKE cluster."
  value       = module.oke_cluster.cluster_state
}

output "oke_cluster_endpoints" {
  description = "OKE cluster API endpoints."
  sensitive   = true
  value       = module.oke_cluster.cluster_endpoints
}

output "oke_node_pool_id" {
  description = "OCID of the OKE node pool."
  value       = module.oke_node_pool.node_pool_id
}

output "oke_bastion_id" {
  description = "OCID of the OCI Bastion fronting the private API endpoint."
  value       = module.bastion.bastion_id
}

output "oke_kubeconfig_command" {
  description = "Commands to generate kubeconfig and rename entries to 'ddyy-oke'."
  sensitive   = true
  value       = <<-EOT
    # Step 1: generate kubeconfig (merges into ~/.kube/config)
    oci ce cluster create-kubeconfig \
      --cluster-id ${module.oke_cluster.cluster_id} \
      --file $HOME/.kube/config \
      --region il-jerusalem-1 \
      --token-version 2.0.0 \
      --kube-endpoint PRIVATE_ENDPOINT \
      --profile ddyyconsulting

    # Step 2: extract OCI-generated suffix (e.g. "cfjwbpimi3a") from cluster name
    OCI_SUFFIX=$(kubectl config view -o jsonpath='{.clusters[*].name}' | tr ' ' '\n' | grep '^cluster-' | sed 's/cluster-//')

    # Step 3: add --profile to the exec credential plugin
    kubectl config set-credentials ddyy-oke \
      --exec-api-version=client.authentication.k8s.io/v1beta1 \
      --exec-command=oci \
      --exec-arg=ce --exec-arg=cluster --exec-arg=generate-token \
      --exec-arg=--cluster-id --exec-arg=${module.oke_cluster.cluster_id} \
      --exec-arg=--region --exec-arg=il-jerusalem-1 \
      --exec-arg=--profile --exec-arg=ddyyconsulting

    # Step 4: rename cluster entry to ddyy-oke (preserves CA cert, overrides server to localhost tunnel)
    CA_DATA=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"cluster-$OCI_SUFFIX\")].cluster.certificate-authority-data}")
    TMPCA=$(mktemp) && echo "$CA_DATA" | base64 -d > "$TMPCA"
    kubectl config set-cluster ddyy-oke --server=https://127.0.0.1:6443 --certificate-authority="$TMPCA" --embed-certs=true
    rm "$TMPCA"

    # Step 5: create context ddyy-oke and switch to it
    kubectl config set-context ddyy-oke --cluster=ddyy-oke --user=ddyy-oke
    kubectl config use-context ddyy-oke

    # Step 6: remove OCI-generated entries
    kubectl config delete-cluster "cluster-$OCI_SUFFIX" 2>/dev/null || true
    kubectl config delete-user "user-$OCI_SUFFIX" 2>/dev/null || true
    kubectl config delete-context "context-$OCI_SUFFIX" 2>/dev/null || true
  EOT
}

output "oke_bastion_connect" {
  description = <<-EOT
    Full workflow to reach the private Kubernetes API endpoint through the OCI Bastion.

    Step 1 — create a port-forwarding session (run once; sessions expire after 30 min):
      Replace LOCAL_PORT with a free port on your machine (e.g. 6443).
      Replace SSH_PUBLIC_KEY_PATH with your public key path (e.g. ~/.ssh/langburd.pub).
      Replace TARGET_IP with the cluster's kubernetes_private_endpoint IP
        (strip the ":6443" suffix from `tofu output -raw oke_cluster_private_endpoint`).

    Step 2 — open the SSH tunnel in a separate terminal and keep it running.

    Step 3 — generate and configure kubeconfig (run `tofu output -raw oke_kubeconfig_command` and execute the printed script;
      it sets the server to the local tunnel and embeds the cluster CA).

    Step 4 — verify:
      kubectl get nodes
  EOT
  sensitive   = true
  value       = <<-EOT
    # --- Step 1: create bastion port-forwarding session ---
    LOCAL_PORT=6443
    TARGET_IP=$(tofu output -raw oke_cluster_private_endpoint | cut -d: -f1)
    SESSION_ID=$(oci bastion session create-port-forwarding \
      --bastion-id ${module.bastion.bastion_id} \
      --display-name oke-kubectl-session \
      --ssh-public-key-file ~/.ssh/langburd.pub \
      --target-private-ip "$TARGET_IP" \
      --target-port 6443 \
      --session-ttl 1800 \
      --profile ddyyconsulting \
      --query 'data.id' --raw-output)
    echo "Session: $SESSION_ID"

    # --- Wait for session to become ACTIVE (~15-30s) ---
    until [ "$(oci bastion session get --session-id "$SESSION_ID" --profile ddyyconsulting --query 'data."lifecycle-state"' --raw-output 2>/dev/null)" = "ACTIVE" ]; do
      echo "waiting for session..."; sleep 5
    done
    echo "Session ACTIVE — starting tunnel"

    # --- Step 2: open SSH tunnel (run in a separate terminal, keep running) ---
    ssh -N -L $${LOCAL_PORT}:${module.oke_cluster.cluster_endpoints[0].private_endpoint} \
      -p 22 "$SESSION_ID@host.bastion.il-jerusalem-1.oci.oraclecloud.com" \
      -i ~/.ssh/langburd \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o KexAlgorithms=ecdh-sha2-nistp256

    # --- Step 3: generate and configure kubeconfig (sets server to the local tunnel and embeds the CA) ---
    $(tofu output -raw oke_kubeconfig_command)

    # --- Step 4: verify ---
    kubectl get nodes
  EOT
}

output "oke_cluster_private_endpoint" {
  description = "Private IP:port of the Kubernetes API endpoint (use to configure the bastion tunnel target)."
  sensitive   = true
  value       = module.oke_cluster.cluster_endpoints[0].private_endpoint
}
