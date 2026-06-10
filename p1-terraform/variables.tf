variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région GCP"
  type        = string
  default     = "europe-west1"
}

variable "service_name" {
  description = "Nom du service Cloud Run"
  type        = string
  default     = "livre-dor"
}

variable "image" {
  description = "Image du conteneur à déployer (construite et poussée au préalable)"
  type        = string
  # ex: europe-west1-docker.pkg.dev/PROJET/apps/livre-dor:latest
}
