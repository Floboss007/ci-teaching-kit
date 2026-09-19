output "vm_external_ip" {
  description = "Nexus VM's public IP — this is the value to put in the VM_HOST GitHub Secret"
  value       = google_compute_instance.ci_stack.network_interface[0].access_config[0].nat_ip
}

output "nexus_url" {
  value = "http://${google_compute_instance.ci_stack.network_interface[0].access_config[0].nat_ip}:8081"
}

output "gke_cluster_name" {
  description = "Pass this to `gcloud container clusters get-credentials`"
  value       = google_container_cluster.ci_demo_cluster_femi.name
}

output "artifact_registry_repo" {
  description = "Full path to push Docker images to, e.g. in the GitHub Actions workflow"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.ci_demo_repo.repository_id}"
}

# Tomcat's actual URL isn't known until after the LoadBalancer Service
# is created by kubectl — Terraform doesn't manage that Service, so it
# can't output this IP directly. Get it after deploying with:
#   kubectl get service ci-demo-app-service
