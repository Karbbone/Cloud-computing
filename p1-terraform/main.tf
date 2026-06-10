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

# --- Activation des APIs nécessaires ---
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "firestore.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# --- Le BaaS : base de données Firestore entièrement managée ---
resource "google_firestore_database" "db" {
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"
  depends_on  = [google_project_service.apis]
}

# --- Dépôt Artifact Registry pour héberger l'image ---
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "apps"
  format        = "DOCKER"
  depends_on    = [google_project_service.apis]
}

# Compte de service par défaut Compute (utilisé par Cloud Run et Cloud Build)
data "google_project" "this" {}

locals {
  compute_sa = "${data.google_project.this.number}-compute@developer.gserviceaccount.com"
}

# --- IAM : accès Firestore pour le service Cloud Run ---
resource "google_project_iam_member" "datastore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${local.compute_sa}"
}

# --- Le service Cloud Run qui sert l'application ---
resource "google_cloud_run_v2_service" "app" {
  name     = var.service_name
  location = var.region

  template {
    containers {
      image = var.image
    }
  }

  depends_on = [google_project_service.apis]
}

# --- Accès public à l'application ---
resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloud_run_v2_service.app.name
  location = google_cloud_run_v2_service.app.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
