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

# =====================================================================
#  ATTENTION : configuration VOLONTAIREMENT NON SÉCURISÉE (pédagogique)
#  Chaque "défaut" est commenté. Voir le README pour les impacts et
#  les corrections. NE PAS UTILISER EN PRODUCTION.
# =====================================================================

resource "google_storage_bucket" "insecure" {
  name     = var.bucket_name
  location = var.region

  # DÉFAUT 4 : contrôle d'accès "granulaire" (ACL legacy) au lieu d'uniforme.
  # Correctif : uniform_bucket_level_access = true
  uniform_bucket_level_access = false

  # DÉFAUT 2 : pas de versioning → suppression/écrasement = perte définitive.
  # Correctif : ajouter un bloc versioning { enabled = true }

  # DÉFAUT 6 : pas de règle de cycle de vie → données conservées indéfiniment.
  # Correctif : ajouter un bloc lifecycle_rule { ... }

  # DÉFAUT 3 : pas de logging d'accès configuré (aucune traçabilité).
  # Correctif : ajouter un bloc logging { log_bucket = "..." }

  # DÉFAUT 5 : pas de clé CMEK → chiffrement avec clés Google par défaut.
  # Correctif : ajouter un bloc encryption { default_kms_key_name = "..." }
}

# DÉFAUT 1 (le plus grave) : bucket rendu PUBLIC à tout internet.
# allUsers en lecteur d'objets = n'importe qui peut tout télécharger.
# Correctif : SUPPRIMER cette ressource, restreindre à des comptes précis.
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.insecure.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Un fichier d'exemple, désormais accessible publiquement sans authentification.
resource "google_storage_bucket_object" "demo_file" {
  name    = "donnee-sensible.txt"
  bucket  = google_storage_bucket.insecure.name
  content = "Ceci simule une donnee qui n'aurait jamais du etre publique."
}
