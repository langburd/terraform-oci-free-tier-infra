variable "cluster_name" {
  description = "Name of the OKE cluster."
  type        = string
  default     = "ddyy-oke"

  validation {
    condition     = length(var.cluster_name) >= 1 && length(var.cluster_name) <= 255
    error_message = "cluster_name must be between 1 and 255 characters."
  }
}

variable "node_count" {
  description = "Number of worker nodes in the node pool."
  type        = number
  default     = 2

  validation {
    condition     = var.node_count >= 1 && floor(var.node_count) == var.node_count
    error_message = "node_count must be a whole number >= 1."
  }
}

variable "node_ocpus" {
  description = "OCPUs per worker node. Total across all nodes must not exceed 4 (free tier ARM limit)."
  type        = number
  default     = 2

  validation {
    condition     = var.node_ocpus >= 1 && floor(var.node_ocpus) == var.node_ocpus
    error_message = "node_ocpus must be a whole number >= 1."
  }

  validation {
    condition     = var.node_ocpus * var.node_count <= 4
    error_message = "node_ocpus * node_count must not exceed 4 OCPUs total (free tier ARM limit)."
  }
}

variable "node_memory_in_gbs" {
  description = "Memory in GB per worker node. Total across all nodes must not exceed 24 GB (free tier ARM limit)."
  type        = number
  default     = 12

  validation {
    condition     = var.node_memory_in_gbs >= 1 && floor(var.node_memory_in_gbs) == var.node_memory_in_gbs
    error_message = "node_memory_in_gbs must be a whole number >= 1."
  }

  validation {
    condition     = var.node_memory_in_gbs * var.node_count <= 24
    error_message = "node_memory_in_gbs * node_count must not exceed 24 GB total (free tier ARM limit)."
  }
}

variable "boot_volume_size_in_gbs" {
  description = "Boot volume size in GB per worker node. Total must not exceed 200 GB (free tier block storage limit)."
  type        = number
  default     = 50

  # OCI minimum boot volume size is 50 GB.
  validation {
    condition     = var.boot_volume_size_in_gbs >= 50 && floor(var.boot_volume_size_in_gbs) == var.boot_volume_size_in_gbs
    error_message = "boot_volume_size_in_gbs must be a whole number >= 50 (OCI minimum)."
  }

  validation {
    condition     = var.boot_volume_size_in_gbs * var.node_count <= 200
    error_message = "boot_volume_size_in_gbs * node_count must not exceed 200 GB total (free tier block storage limit)."
  }
}

variable "ssh_public_key" {
  description = "SSH public key to authorize on worker nodes for debugging access. Defaults to ~/.ssh/langburd.pub if not set."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.ssh_public_key == null || can(regex("^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp(256|384|521)) ", var.ssh_public_key))
    error_message = "ssh_public_key must be a valid OpenSSH public key (e.g. starting with 'ssh-ed25519' or 'ssh-rsa')."
  }
}
