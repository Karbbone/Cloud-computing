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
    "cloudkms.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "storagetransfer.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

data "google_project" "this" {}

resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "apps"
  format        = "DOCKER"
  depends_on    = [google_project_service.apis]
}

# =====================================================================
#  1. IAM – Moindre privilège
#  Compte de service dédié à l'app, droits limités au bucket de données.
# =====================================================================
resource "google_service_account" "app" {
  account_id   = "app-storage-sa"
  display_name = "SA app storage-benchmark"
}

# =====================================================================
#  2. Chiffrement (CMEK) – clés gérées par nous via Cloud KMS
#  Une clé par région (CMEK exige clé et bucket dans la même région).
# =====================================================================
data "google_storage_project_service_account" "gcs" {}

# Clé pour la région principale
resource "google_kms_key_ring" "main" {
  name       = "app-keyring"
  location   = var.region
  depends_on = [google_project_service.apis]
}

resource "google_kms_crypto_key" "main" {
  name     = "bucket-key"
  key_ring = google_kms_key_ring.main.id
}

# Clé pour la région de backup
resource "google_kms_key_ring" "backup" {
  name       = "app-keyring-backup"
  location   = var.backup_region
  depends_on = [google_project_service.apis]
}

resource "google_kms_crypto_key" "backup" {
  name     = "backup-key"
  key_ring = google_kms_key_ring.backup.id
}

# Le compte de service GCS doit pouvoir chiffrer/déchiffrer avec les clés
resource "google_kms_crypto_key_iam_member" "gcs_main" {
  crypto_key_id = google_kms_crypto_key.main.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

resource "google_kms_crypto_key_iam_member" "gcs_backup" {
  crypto_key_id = google_kms_crypto_key.backup.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

# =====================================================================
#  5. Backup – bucket principal + bucket de sauvegarde, versionnés et CMEK
# =====================================================================
resource "google_storage_bucket" "data" {
  name                        = "benchmark-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true # accès uniforme (pas d'ACL par objet)
  force_destroy               = true

  versioning {
    enabled = true # restauration possible après suppression/écrasement
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.main.id # chiffrement CMEK
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_main]
}

resource "google_storage_bucket" "backup" {
  name                        = "benchmark-${var.project_id}-backup"
  location                    = var.backup_region # AUTRE région = résilience géo
  uniform_bucket_level_access = true
  force_destroy               = true

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.backup.id
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_backup]
}

# IAM : l'app n'a accès qu'au bucket de données (moindre privilège)
resource "google_storage_bucket_iam_member" "app_access" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.app.email}"
}

# --- Backup automatique quotidien : data -> backup ---
data "google_storage_transfer_project_service_account" "sts" {}

resource "google_storage_bucket_iam_member" "sts_read" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${data.google_storage_transfer_project_service_account.sts.email}"
}

resource "google_storage_bucket_iam_member" "sts_write" {
  bucket = google_storage_bucket.backup.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_storage_transfer_project_service_account.sts.email}"
}

resource "google_storage_transfer_job" "daily_backup" {
  description = "Sauvegarde quotidienne data -> backup"

  transfer_spec {
    gcs_data_source {
      bucket_name = google_storage_bucket.data.name
    }
    gcs_data_sink {
      bucket_name = google_storage_bucket.backup.name
    }
  }

  schedule {
    schedule_start_date {
      year  = 2026
      month = 1
      day   = 1
    }
    start_time_of_day {
      hours   = 2
      minutes = 0
      seconds = 0
      nanos   = 0
    }
  }

  depends_on = [
    google_storage_bucket_iam_member.sts_read,
    google_storage_bucket_iam_member.sts_write,
  ]
}

# =====================================================================
#  3. Réseau – surface d'exposition réduite
#  Ingress restreint au load balancer (on place Cloud Armor devant).
# =====================================================================
resource "google_cloud_run_v2_service" "app" {
  name     = var.service_name
  location = var.region

  # N'accepte que le trafic du load balancer interne, pas internet en direct
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = google_service_account.app.email # tourne sous le SA dédié
    containers {
      image = var.image
      env {
        name  = "BUCKET_NAME"
        value = google_storage_bucket.data.name
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# =====================================================================
#  4. Monitoring & Logging – canal d'alerte + politique sur les 5xx
# =====================================================================
resource "google_monitoring_notification_channel" "email" {
  display_name = "Email alertes"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
  depends_on = [google_project_service.apis]
}

resource "google_monitoring_alert_policy" "errors_5xx" {
  display_name = "Cloud Run - taux d'erreurs 5xx eleve"
  combiner     = "OR"

  conditions {
    display_name = "5xx > 0 sur 5 min"
    condition_threshold {
      filter = join(" AND ", [
        "resource.type = \"cloud_run_revision\"",
        "metric.type = \"run.googleapis.com/request_count\"",
        "metric.labels.response_code_class = \"5xx\"",
      ])
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "300s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  depends_on            = [google_project_service.apis]
}
