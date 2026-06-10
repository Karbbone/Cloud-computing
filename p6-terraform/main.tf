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

# --- Le service Cloud Run, avec toute la config de scaling ---
resource "google_cloud_run_v2_service" "app" {
  name     = var.service_name
  location = var.region

  template {
    # Scaling HORIZONTAL : bornes min/max du nombre d'instances
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # Concurrence : nb de requêtes par instance avant d'en créer une autre
    max_instance_request_concurrency = var.concurrency

    containers {
      image = var.image

      # Scaling VERTICAL : puissance allouée à chaque instance
      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
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
