# Mini Projet 6 (Terraform) – Scaler une application

> Version **Infrastructure as Code** du [mini projet 6](https://github.com/Karbbone/Cloud-computing/tree/p6). Même application (API qui affiche l'ID de l'instance + endpoint CPU `/load`), mais toute la configuration de scaling est pilotée par des **variables Terraform**.

## Rappel : le scaling

- **Horizontal** : ajouter/retirer des instances selon la charge (le cœur du Cloud).
- **Vertical** : donner plus de CPU/RAM à chaque instance.

Cloud Run fait du scaling horizontal **automatique** : 0 trafic → 0 instance, pic de trafic → plusieurs instances.

## L'apport de Terraform

Au projet 6, on ajustait le scaling avec des `gcloud run services update --min-instances ... --concurrency ...`. Ici, **tous les leviers sont des variables** dans `terraform.tfvars`. On change une valeur, on fait `terraform apply`, et la nouvelle config est appliquée — versionnée et traçable.

---

## Les leviers de scaling (dans `variables.tf`)

| Variable | Rôle | Défaut |
| --- | --- | --- |
| `min_instances` | Instances minimum (0 = scale-to-zero, mais cold start) | `0` |
| `max_instances` | Plafond (sécurité anti-facture) | `10` |
| `concurrency` | Requêtes simultanées par instance avant d'en créer une | `80` |
| `cpu` | CPU par instance (scaling vertical) | `"1"` |
| `memory` | RAM par instance (scaling vertical) | `"512Mi"` |

Dans le code, ils correspondent à :

```hcl
scaling {
  min_instance_count = var.min_instances
  max_instance_count = var.max_instances
}
max_instance_request_concurrency = var.concurrency
resources { limits = { cpu = var.cpu, memory = var.memory } }
```

**La concurrence est le réglage clé** : elle décide *quand* une nouvelle instance est créée. Basse (ex. `1`) pour des tâches CPU lourdes comme `/load` ; haute pour des requêtes légères.

---

## Déploiement

```bash
cp terraform.tfvars.example terraform.tfvars   # mettre son project_id
terraform init

# 1) Créer le dépôt + APIs, puis construire l'image
terraform apply -target=google_artifact_registry_repository.repo -target=google_project_service.apis
PROJECT=$(grep project_id terraform.tfvars | cut -d'"' -f2)
gcloud builds submit --tag europe-west1-docker.pkg.dev/$PROJECT/apps/scaling-demo:latest

# 2) Déployer le service avec sa config de scaling
terraform apply
```

---

## Tester le scaling

```bash
URL=$(terraform output -raw url)

# Générer de la charge (avec hey : https://github.com/rakyll/hey)
hey -n 2000 -c 100 "$URL/load?ms=500"

# Compter les instances qui ont répondu
for i in $(seq 1 200); do curl -s "$URL/info" | grep -o '"instance":"[^"]*"' & done; wait | sort | uniq -c
```

Plusieurs IDs = plusieurs instances créées par l'autoscaling. À observer aussi dans **Cloud Run → Métriques → Nombre d'instances**.

## Ajuster la config

Modifier une valeur dans `terraform.tfvars` (ex. passer `concurrency = 1`), puis :

```bash
terraform apply
```

Une nouvelle révision est déployée avec la config mise à jour.

---

## Détruire

```bash
terraform destroy
```

---

## gcloud vs Terraform

| `gcloud run services update` | Terraform |
| --- | --- |
| Réglages passés en flags, non tracés | Réglages = variables versionnées |
| État réel inconnu après plusieurs updates | `tfstate` = source de vérité |
| Difficile de rejouer la même config | `apply` reproductible |
