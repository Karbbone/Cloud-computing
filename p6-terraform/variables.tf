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
  default     = "scaling-demo"
}

variable "image" {
  description = "Image du conteneur (construite et poussée au préalable)"
  type        = string
}

# --- Paramètres de scaling (le cœur du projet) ---
variable "min_instances" {
  description = "Nombre minimum d'instances (0 = scale-to-zero, coût nul mais cold start)"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Plafond d'instances (sécurité anti-facture)"
  type        = number
  default     = 10
}

variable "concurrency" {
  description = "Requêtes simultanées par instance avant d'en créer une nouvelle"
  type        = number
  default     = 80
}

variable "cpu" {
  description = "CPU par instance (scaling vertical)"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Mémoire par instance (scaling vertical)"
  type        = string
  default     = "512Mi"
}
