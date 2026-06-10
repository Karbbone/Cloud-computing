terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
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
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "eventarc.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# --- Empaqueter le code source de la fonction en .zip ---
data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/function-source.zip"
}

# --- Bucket qui héberge le code source de la fonction ---
resource "google_storage_bucket" "source" {
  name                        = "${var.project_id}-function-source"
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "source" {
  # Le hash dans le nom force le redéploiement quand le code change
  name   = "source-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.source.output_path
}

# --- La fonction (FaaS) : Cloud Functions gen2 ---
resource "google_cloudfunctions2_function" "fn" {
  name     = var.function_name
  location = var.region

  build_config {
    runtime     = "nodejs20"
    entry_point = "helloWorld"
    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.source.name
      }
    }
  }

  service_config {
    max_instance_count = 3
    available_memory   = "256M"
    timeout_seconds    = 60
  }

  depends_on = [google_project_service.apis]
}

# --- Accès public (gen2 = backé par Cloud Run, on autorise allUsers à invoquer) ---
resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloudfunctions2_function.fn.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
