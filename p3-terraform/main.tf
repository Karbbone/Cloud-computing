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

# --- Compte de service dédié au collègue (identité machine) ---
resource "google_service_account" "deployer" {
  account_id   = "collegue-deployer"
  display_name = "Compte déploiement collègue"
}

# --- Attribution des rôles, un par un, au niveau projet ---
# Principe du moindre privilège : uniquement ce qui est nécessaire pour déployer.
resource "google_project_iam_member" "deployer_roles" {
  for_each = toset(var.deployer_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.deployer.email}"
}

# --- Clé du compte de service (à transmettre au collègue) ---
# ATTENTION : une clé exportée est sensible. À éviter en prod (préférer la
# fédération d'identité). Ici à but pédagogique, comme dans le projet 3.
resource "google_service_account_key" "deployer_key" {
  service_account_id = google_service_account.deployer.name
}
