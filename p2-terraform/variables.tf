variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région GCP"
  type        = string
  default     = "europe-west1"
}

variable "function_name" {
  description = "Nom de la fonction"
  type        = string
  default     = "hello-world"
}
