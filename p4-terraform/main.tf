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
}

# --- Activation des APIs ---
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "storage.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# --- Dépôt Artifact Registry pour l'image ---
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "apps"
  format        = "DOCKER"
  depends_on    = [google_project_service.apis]
}

# --- Le stockage objet : bucket GCS pour le benchmark ---
resource "google_storage_bucket" "benchmark" {
  name                        = "benchmark-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  depends_on                  = [google_project_service.apis]
}

data "google_project" "this" {}

locals {
  compute_sa = "${data.google_project.this.number}-compute@developer.gserviceaccount.com"
}

# --- IAM : le compte de service Cloud Run peut lire/écrire dans CE bucket ---
resource "google_storage_bucket_iam_member" "app_access" {
  bucket = google_storage_bucket.benchmark.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.compute_sa}"
}

# --- Le service Cloud Run ---
resource "google_cloud_run_v2_service" "app" {
  name     = var.service_name
  location = var.region

  template {
    containers {
      image = var.image
      env {
        name  = "BUCKET_NAME"
        value = google_storage_bucket.benchmark.name
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# --- Accès public ---
resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloud_run_v2_service.app.name
  location = google_cloud_run_v2_service.app.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
