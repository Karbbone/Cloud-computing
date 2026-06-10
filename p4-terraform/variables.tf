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
  default     = "storage-benchmark"
}

variable "image" {
  description = "Image du conteneur (construite et poussée au préalable)"
  type        = string
}
