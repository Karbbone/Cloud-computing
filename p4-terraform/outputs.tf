output "url" {
  description = "URL publique de l'application"
  value       = google_cloud_run_v2_service.app.uri
}

output "bucket" {
  description = "Bucket GCS du benchmark"
  value       = google_storage_bucket.benchmark.name
}
