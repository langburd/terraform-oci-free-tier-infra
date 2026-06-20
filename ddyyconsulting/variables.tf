variable "cluster_name" {
  description = "Name of the OKE cluster."
  type        = string
  default     = "ddyy-oke"
}

variable "node_count" {
  description = "Number of worker nodes in the node pool."
  type        = number
  default     = 2
}

variable "node_ocpus" {
  description = "OCPUs per worker node. Total across all nodes must not exceed 4 (free tier ARM limit)."
  type        = number
  default     = 2
}

variable "node_memory_in_gbs" {
  description = "Memory in GB per worker node. Total across all nodes must not exceed 24 GB (free tier ARM limit)."
  type        = number
  default     = 12
}

variable "boot_volume_size_in_gbs" {
  description = "Boot volume size in GB per worker node. Total must not exceed 200 GB (free tier block storage limit)."
  type        = number
  default     = 50
}

variable "ssh_public_key" {
  description = "SSH public key to authorize on worker nodes for debugging access. Defaults to ~/.ssh/langburd.pub if not set."
  type        = string
  default     = null
  sensitive   = true
}
