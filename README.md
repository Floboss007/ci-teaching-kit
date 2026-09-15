# CI Teaching Kit — GitHub Actions + Nexus + GKE

Pipeline runs on GitHub Actions. Nexus (artifact storage for the WAR
file) runs on a small GCP VM. The actual app now runs as a container
inside a GKE (Kubernetes) cluster, instead of a standalone Tomcat
container.

## What changed from the standalone-Tomcat version

- Tomcat is no longer a container you `curl` a WAR into — instead, the
  WAR gets baked into a Tomcat image (`Dockerfile.tomcat-app`) at build
  time, pushed to Artifact Registry, and Kubernetes runs that image as
  a Pod.
- `docker-compose.yml` now only runs Nexus — Tomcat's entry is gone.
- `tomcat-config/` (manager API users/access files) is gone — no
  longer needed, since deployment goes through `kubectl`, not the
  manager API.
- New folder: `k8s/` — `deployment.yaml` and `service.yaml`, the
  Kubernetes manifests describing how many copies of the app to run
  and how to expose it to the internet.
- Terraform now also provisions a GKE cluster and an Artifact Registry
  repository, in addition to the Nexus VM.

## One-time setup

### 1. Deploy infrastructure with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: project_id, admin_ip
terraform init
terraform apply
```

This now takes longer than before — it's provisioning a GKE cluster in
addition to the VM. Get several key values afterward:

```bash
terraform output
```

Note `vm_external_ip`, `gke_cluster_name`, and `artifact_registry_repo`.

### 2. Set up Nexus (same as before)

- `http://<vm_external_ip>:8081` → log in as admin, set password
- **Security → Users → Create local user**: `deployer` / a real password / Active
- Assign the built-in `nx-admin` role

### 3. Create a GCP service account for GitHub Actions

GitHub's runners need permission to push images and deploy to GKE:

```bash
gcloud iam service-accounts create github-actions-deployer \
  --display-name="GitHub Actions Deployer"

gcloud projects add-iam-policy-binding <your-project-id> \
  --member="serviceAccount:github-actions-deployer@<your-project-id>.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding <your-project-id> \
  --member="serviceAccount:github-actions-deployer@<your-project-id>.iam.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions-deployer@<your-project-id>.iam.gserviceaccount.com
```

This creates `github-actions-key.json` in your current folder — **do
not commit this file**, it's already covered by nothing in `.gitignore`
by default, so add it now:

```bash
echo "github-actions-key.json" >> .gitignore
```

### 4. Add GitHub Secrets

Repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret name | Value |
|---|---|
| `VM_HOST` | `terraform output vm_external_ip` |
| `NEXUS_PASSWORD` | The `deployer` password you set in Nexus |
| `GCP_SA_KEY` | The **entire contents** of `github-actions-key.json` |
| `GCP_ARTIFACT_REPO` | `terraform output artifact_registry_repo` |
| `GCP_REGION` | `us-central1` (or whatever you set in `terraform.tfvars`) |
| `GCP_ZONE` | `us-central1-a` (or whatever you set) |
| `GKE_CLUSTER_NAME` | `terraform output gke_cluster_name` |

After adding `GCP_SA_KEY`, delete the local key file — it's no longer
needed on your machine:

```bash
rm github-actions-key.json
```

### 5. Push to trigger the pipeline

```bash
git commit --allow-empty -m "Trigger first GKE deploy"
git push
```

Watch the Actions tab. The final step prints the app's live external
IP and curls it to confirm.

## Getting the app's URL later

Terraform doesn't manage the Kubernetes Service, so it can't output
the app's IP directly. Get it anytime with:

```bash
gcloud container clusters get-credentials $(terraform -chdir=terraform output -raw gke_cluster_name) --zone <your-zone>
kubectl get service ci-demo-app-service
```

The `EXTERNAL-IP` column is where the app is reachable, at
`http://<that-ip>/ci-demo-app/hello`.

## Teardown

Terraform now also owns the GKE cluster and Artifact Registry, so the
same command tears down everything:

```bash
cd terraform
terraform destroy
```

Also revoke the service account, since Terraform doesn't manage it:

```bash
gcloud iam service-accounts delete github-actions-deployer@<your-project-id>.iam.gserviceaccount.com
```
