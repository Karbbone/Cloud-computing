output "service_account" {
  description = "Compte de service dédié à l'app (moindre privilège)"
  value       = google_service_account.app.email
}

output "data_bucket" {
  description = "Bucket de données (CMEK + versioning)"
  value       = google_storage_bucket.data.name
}

output "backup_bucket" {
  description = "Bucket de sauvegarde (autre région)"
  value       = google_storage_bucket.backup.name
}

output "kms_key" {
  description = "Clé CMEK du bucket principal"
  value       = google_kms_crypto_key.main.id
}

output "service_uri" {
  description = "URI du service (joignable via le load balancer uniquement)"
  value       = google_cloud_run_v2_service.app.uri
}
