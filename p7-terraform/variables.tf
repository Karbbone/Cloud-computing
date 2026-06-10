variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région principale"
  type        = string
  default     = "europe-west1"
}

variable "backup_region" {
  description = "Région de sauvegarde (différente, pour la résilience géographique)"
  type        = string
  default     = "europe-west4"
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

variable "alert_email" {
  description = "Email pour recevoir les alertes monitoring"
  type        = string
}
