output "url" {
  description = "URL publique de l'application"
  value       = google_cloud_run_v2_service.app.uri
}

output "firestore_database" {
  description = "Base de données Firestore provisionnée"
  value       = google_firestore_database.db.name
}
