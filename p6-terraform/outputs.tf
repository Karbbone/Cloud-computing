output "url" {
  description = "URL publique de l'application"
  value       = google_cloud_run_v2_service.app.uri
}

output "scaling_config" {
  description = "Configuration de scaling appliquée"
  value = {
    min_instances = var.min_instances
    max_instances = var.max_instances
    concurrency   = var.concurrency
    cpu           = var.cpu
    memory        = var.memory
  }
}
