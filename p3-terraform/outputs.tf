output "service_account_email" {
  description = "Email du compte de service créé"
  value       = google_service_account.deployer.email
}

output "assigned_roles" {
  description = "Rôles attribués au compte (moindre privilège)"
  value       = var.deployer_roles
}

# La clé privée est sensible : marquée sensitive, à récupérer avec
# `terraform output -raw deployer_key | base64 -d > collegue-key.json`
output "deployer_key" {
  description = "Clé du compte de service (base64)"
  value       = google_service_account_key.deployer_key.private_key
  sensitive   = true
}
