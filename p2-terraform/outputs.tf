output "function_uri" {
  description = "URL HTTP de la fonction"
  value       = google_cloudfunctions2_function.fn.service_config[0].uri
}
