terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_instance" "ci_stack" {
  name         = "ci-teaching-kit-femi"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["ci-stack"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 30 # GB — just Nexus + Tomcat now, no Jenkins, so less disk needed
    }
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral external IP — this is what makes Nexus/Tomcat reachable
      # from GitHub-hosted Actions runners.
    }
  }

  metadata_startup_script = templatefile("${path.module}/startup-script.sh", {
    repo_url = var.repo_url
  })
}

# Admin access: only your own IP can reach the Nexus UI and SSH.
# Port 8082 (Tomcat) is gone from here — Tomcat now runs inside GKE,
# exposed via its own LoadBalancer Service, not this VM.
resource "google_compute_firewall" "admin_access" {
  name    = "allow-ci-stack-admin-femi"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "8081"]
  }

  source_ranges = [var.admin_ip]
  target_tags   = ["ci-stack"]
}

# GitHub-hosted Actions runners do NOT have published, stable IP ranges
# the way GitHub's own webhook servers do — runners are ephemeral VMs on
# Azure, with IPs that change per-run and aren't practical to allowlist.
# This means Nexus (8081) has to be open more broadly for the workflow
# to reach it at all.
#
# This is a real security tradeoff, not a shortcut — worth stating
# outright to students: opening this port to 0.0.0.0/0 means anyone on
# the internet can attempt to reach Nexus directly, not just GitHub.
# The deployer/admin passwords are the only thing standing between
# "reachable" and "compromised" here. Acceptable for a short-lived
# teaching VM that gets torn down after class; NOT acceptable for
# anything long-lived or holding real data.
resource "google_compute_firewall" "actions_runner_access" {
  name    = "allow-github-actions-runner-femi"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8081"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ci-stack"]
}

# --- Kubernetes (GKE) ---

# These APIs aren't enabled by default on a fresh project — Terraform
# needs them on before it can create the resources below.
resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifact_registry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# Where the GitHub Actions workflow pushes the built Docker image —
# this replaces Nexus's role for this part of the pipeline. Nexus still
# stores the WAR file itself (unchanged); this is specifically for the
# container image that gets deployed to Kubernetes.
resource "google_artifact_registry_repository" "ci_demo_repo" {
  depends_on    = [google_project_service.artifact_registry]
  location      = var.region
  repository_id = "ci-demo-repo-femi"
  format        = "DOCKER"
}

# A small, single-node GKE cluster — enough to run one Tomcat pod for
# teaching purposes. Real production clusters would use multiple nodes
# across zones for actual high availability.
resource "google_container_cluster" "ci_demo_cluster_femi" {
  depends_on = [google_project_service.container]
  name       = "ci-demo-cluster"
  location   = var.zone

  # Removing the default node pool immediately and defining our own
  # below is the standard Terraform pattern for GKE — it avoids a
  # awkwardly-configured default pool you didn't choose the settings for.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Autopilot would remove node-management entirely, but costs more per
  # pod and hides some of the "nodes vs pods" concepts worth teaching —
  # a standard cluster with an explicit node pool keeps that visible.
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}
}

resource "google_container_node_pool" "ci_demo_nodes" {
  name       = "ci-demo-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.ci_demo_cluster_femi.name
  node_count = var.gke_node_count

  node_config {
    machine_type = var.gke_machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}
