output "public_url" {
  description = "URL publique du fichier exposé (accessible sans authentification)"
  value       = "https://storage.googleapis.com/${google_storage_bucket.insecure.name}/${google_storage_bucket_object.demo_file.name}"
}
