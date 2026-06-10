variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région GCP"
  type        = string
  default     = "europe-west1"
}

variable "deployer_roles" {
  description = "Rôles strictement nécessaires pour déployer sur Cloud Run (moindre privilège)"
  type        = list(string)
  default = [
    "roles/run.developer",          # déployer/gérer des services Cloud Run
    "roles/iam.serviceAccountUser", # agir en tant que compte de service au déploiement
    "roles/storage.objectViewer",   # lire les images de conteneur
  ]
}
