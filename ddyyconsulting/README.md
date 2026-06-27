# ddyyconsulting

OCI environment hosting a private OKE (Oracle Kubernetes Engine) cluster. The Kubernetes API endpoint is **private** — reachable only through the OCI Bastion fronting it.

## Accessing the OKE cluster

The cluster API has no public endpoint. To run `kubectl` against it you must:

1. Create an OCI Bastion **port-forwarding session** (TTL 30 min).
2. Open an SSH tunnel from a local port to the cluster's private endpoint through the bastion.
3. Generate and patch a kubeconfig whose `server` points at the local tunnel.

The OpenTofu outputs print copy-paste scripts for each step. Run from this directory:

```bash
tofu output -raw oke_bastion_connect      # full end-to-end workflow
tofu output -raw oke_kubeconfig_command   # just the kubeconfig generation/patching
tofu output -raw oke_cluster_private_endpoint
```

> These outputs are marked `sensitive`; `-raw` is required to print them.

### One-command helper (zsh)

For day-to-day access, a `zsh` function wraps the whole flow: it reuses an
ACTIVE bastion session when one exists, backgrounds the SSH tunnel, waits until
the local port accepts connections, configures the `ddyy-oke` kubeconfig
context, and runs `kubectl get nodes`. Re-running it is idempotent.

Add the function below to your shell (e.g. a sourced `~/.zshrc` fragment). Fill
the values from the OpenTofu outputs of this environment:

| Variable     | Source                                                            |
| ------------ | ----------------------------------------------------------------- |
| `BASTION_ID` | `tofu output -raw oke_bastion_id`                                 |
| `CLUSTER_ID` | `tofu output -raw oke_cluster_id`                                 |
| `TARGET_IP`  | `tofu output -raw oke_cluster_private_endpoint` (strip `:6443`)   |
| `SSH_KEY` / `SSH_PUB` | your bastion SSH key pair                                |

```zsh
oke-connect() {
  # ACTIVE bastion session + SSH tunnel + kubeconfig, ready for kubectl. Idempotent.
  local BASTION_ID="<oke_bastion_id>"
  local CLUSTER_ID="<oke_cluster_id>"
  local TARGET_IP="<private endpoint IP>"
  local TARGET_PORT="6443"
  local REGION="il-jerusalem-1"
  local PROFILE="ddyyconsulting"
  local SSH_KEY="${HOME}/.ssh/langburd"
  local SSH_PUB="${HOME}/.ssh/langburd.pub"
  local LOCAL_PORT="6443"
  local BASTION_HOST="host.bastion.${REGION}.oci.oraclecloud.com"
  local SESSION_NAME="oke-kubectl-session"
  local KCTX="ddyy-oke"

  local dep
  for dep in oci kubectl ssh nc; do
    command -v "${dep}" >/dev/null 2>&1 || { echo "oke-connect: missing dependency: ${dep}" >&2; return 1; }
  done

  if nc -z 127.0.0.1 "${LOCAL_PORT}" >/dev/null 2>&1; then
    echo "oke-connect: tunnel on 127.0.0.1:${LOCAL_PORT} already up"
  else
    local session_id
    session_id=$(oci bastion session list \
      --bastion-id "${BASTION_ID}" --session-lifecycle-state ACTIVE \
      --display-name "${SESSION_NAME}" --profile "${PROFILE}" \
      --query 'data[0].id' --raw-output 2>/dev/null)

    if [[ -n "${session_id}" && "${session_id}" != "null" ]]; then
      echo "oke-connect: reusing ACTIVE session ${session_id}"
    else
      echo "oke-connect: creating bastion session..."
      session_id=$(oci bastion session create-port-forwarding \
        --bastion-id "${BASTION_ID}" --display-name "${SESSION_NAME}" \
        --ssh-public-key-file "${SSH_PUB}" --target-private-ip "${TARGET_IP}" \
        --target-port "${TARGET_PORT}" --session-ttl 1800 --profile "${PROFILE}" \
        --query 'data.id' --raw-output 2>/dev/null)
      [[ -n "${session_id}" && "${session_id}" != "null" ]] || { echo "oke-connect: failed to create session" >&2; return 1; }
      echo "oke-connect: session ${session_id} — waiting for ACTIVE..."
      local state tries=0
      until [[ "${state}" == "ACTIVE" ]]; do
        (( tries >= 24 )) && { echo "oke-connect: session did not become ACTIVE in time" >&2; return 1; }
        sleep 5
        state=$(oci bastion session get --session-id "${session_id}" --profile "${PROFILE}" \
          --query 'data."lifecycle-state"' --raw-output 2>/dev/null)
        (( tries++ ))
      done
      echo "oke-connect: session ACTIVE"
    fi

    echo "oke-connect: opening tunnel 127.0.0.1:${LOCAL_PORT} -> ${TARGET_IP}:${TARGET_PORT}"
    ssh -N -f -L "${LOCAL_PORT}:${TARGET_IP}:${TARGET_PORT}" \
      -p 22 "${session_id}@${BASTION_HOST}" -i "${SSH_KEY}" \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o KexAlgorithms=ecdh-sha2-nistp256 -o IdentitiesOnly=yes -o ExitOnForwardFailure=yes \
      || { echo "oke-connect: ssh tunnel failed to start" >&2; return 1; }

    local wait=0
    until nc -z 127.0.0.1 "${LOCAL_PORT}" >/dev/null 2>&1; do
      (( wait >= 15 )) && { echo "oke-connect: tunnel port ${LOCAL_PORT} never came up" >&2; return 1; }
      sleep 1; (( wait++ ))
    done
    echo "oke-connect: tunnel up"
  fi

  echo "oke-connect: configuring kubeconfig context ${KCTX}"
  oci ce cluster create-kubeconfig --cluster-id "${CLUSTER_ID}" \
    --file "${HOME}/.kube/config" --region "${REGION}" --token-version 2.0.0 \
    --kube-endpoint PRIVATE_ENDPOINT --profile "${PROFILE}" >/dev/null 2>&1

  local oci_suffix
  oci_suffix=$(kubectl config view -o jsonpath='{.clusters[*].name}' | tr ' ' '\n' | grep '^cluster-' | sed 's/cluster-//' | head -1)

  kubectl config set-credentials "${KCTX}" \
    --exec-api-version=client.authentication.k8s.io/v1beta1 --exec-command=oci \
    --exec-arg=ce --exec-arg=cluster --exec-arg=generate-token \
    --exec-arg=--cluster-id --exec-arg="${CLUSTER_ID}" \
    --exec-arg=--region --exec-arg="${REGION}" \
    --exec-arg=--profile --exec-arg="${PROFILE}" >/dev/null

  local ca_data tmpca
  ca_data=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"cluster-${oci_suffix}\")].cluster.certificate-authority-data}")
  tmpca=$(mktemp); echo "${ca_data}" | base64 -d > "${tmpca}"
  kubectl config set-cluster "${KCTX}" --server="https://127.0.0.1:${LOCAL_PORT}" \
    --certificate-authority="${tmpca}" --embed-certs=true >/dev/null
  rm -f "${tmpca}"

  kubectl config set-context "${KCTX}" --cluster="${KCTX}" --user="${KCTX}" >/dev/null
  kubectl config use-context "${KCTX}" >/dev/null

  if [[ -n "${oci_suffix}" ]]; then
    kubectl config delete-cluster "cluster-${oci_suffix}" >/dev/null 2>&1 || true
    kubectl config delete-user "user-${oci_suffix}" >/dev/null 2>&1 || true
    kubectl config delete-context "context-${oci_suffix}" >/dev/null 2>&1 || true
  fi

  echo "oke-connect: verifying..."
  kubectl get nodes
}

oke-disconnect() {
  # Tear down the tunnel; pass --session to also delete the ACTIVE bastion session.
  local BASTION_ID="<oke_bastion_id>"
  local PROFILE="ddyyconsulting"
  local SESSION_NAME="oke-kubectl-session"
  local LOCAL_PORT="6443"

  if pkill -f "ssh -N -f -L ${LOCAL_PORT}:" 2>/dev/null; then
    echo "oke-disconnect: tunnel killed"
  else
    echo "oke-disconnect: no tunnel found"
  fi

  if [[ "$1" == "--session" ]]; then
    local session_id
    session_id=$(oci bastion session list --bastion-id "${BASTION_ID}" \
      --session-lifecycle-state ACTIVE --display-name "${SESSION_NAME}" \
      --profile "${PROFILE}" --query 'data[0].id' --raw-output 2>/dev/null)
    if [[ -n "${session_id}" && "${session_id}" != "null" ]]; then
      oci bastion session delete --session-id "${session_id}" --profile "${PROFILE}" --force >/dev/null 2>&1 \
        && echo "oke-disconnect: session ${session_id} deleted"
    else
      echo "oke-disconnect: no ACTIVE session to delete"
    fi
  fi
}
```

Usage:

```bash
oke-connect             # connect and verify
kubectl get pods -A     # cluster is now reachable
oke-disconnect          # close the tunnel
oke-disconnect --session  # close the tunnel and delete the bastion session
```

Notes:

- Bastion sessions expire after 30 min; `oke-connect` creates a fresh one when the old one is gone.
- The local port (`6443`) and SSH key paths are configurable at the top of the function.
- The `KexAlgorithms=ecdh-sha2-nistp256` option is required — the OCI bastion SSH host only offers that key exchange.
- `IdentitiesOnly=yes` is required so `ssh` offers only the `-i` key. Without it, keys loaded in `ssh-agent` are offered first and the bastion rejects them with `Permission denied (publickey)` before the correct key is tried.
