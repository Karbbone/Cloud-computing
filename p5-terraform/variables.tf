variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région GCP"
  type        = string
  default     = "europe-west1"
}

variable "bucket_name" {
  description = "Nom du bucket (doit être unique mondialement)"
  type        = string
  default     = "bucket-non-securise-p5-tf"
}
