variable "project_id" {
  description = "Your GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region to deploy into"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone to deploy into"
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "VM size for the Nexus VM. Nexus alone is fine on e2-medium; keep e2-standard-2 if you also expect heavier load."
  type        = string
  default     = "e2-standard-2"
}

variable "gke_node_count" {
  description = "Number of nodes in the GKE cluster. 1 is enough for a teaching demo."
  type        = number
  default     = 3
}

variable "gke_machine_type" {
  description = "Machine type for GKE nodes. e2-medium is the practical minimum for running Tomcat comfortably."
  type        = string
  default     = "e2-medium"
}

variable "admin_ip" {
  description = "Your own public IP (as CIDR, e.g. 203.0.113.5/32), allowed full admin access to Jenkins/Nexus/Tomcat UIs. Find yours at https://whatismyip.com"
  type        = string
}

variable "repo_url" {
  description = "Git repo URL the VM will clone on startup"
  type        = string
  default     = "https://github.com/Floboss007/ci-teaching-kit.git"
}
