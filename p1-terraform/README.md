# Mini Projet 1 (Terraform) – BaaS avec Firestore + Cloud Run

> Version **Infrastructure as Code** du [mini projet 1](https://github.com/Karbbone/Cloud-computing/tree/p1). Même application (livre d'or sur Firestore), mais toute l'infrastructure est décrite en **Terraform** au lieu de commandes `gcloud` manuelles.

## Pourquoi Terraform ?

Au projet 1, on provisionnait à la main : `gcloud firestore databases create`, des `add-iam-policy-binding`, `gcloud run deploy`… Le problème : aucune trace, non reproductible, difficile à détruire proprement.

Avec **Terraform**, on **décrit** l'infrastructure dans des fichiers `.tf`. Terraform calcule la différence entre l'état voulu et l'état réel, puis applique. Avantages :

- **Reproductible** : `terraform apply` recrée tout à l'identique.
- **Versionné** : l'infra est dans Git, comme le code.
- **Réversible** : `terraform destroy` supprime tout sans rien oublier.

---

## Ce qui est décrit dans le code

| Fichier | Rôle |
| --- | --- |
| `main.tf` | APIs, base Firestore, Artifact Registry, IAM, service Cloud Run |
| `variables.tf` | Variables d'entrée (projet, région, image…) |
| `outputs.tf` | Sorties (URL de l'app, nom de la base) |
| `terraform.tfvars.example` | Exemple de valeurs à copier dans `terraform.tfvars` |

Ressources principales créées : `google_firestore_database`, `google_artifact_registry_repository`, `google_cloud_run_v2_service`, et les liaisons IAM (`datastore.user`, `run.invoker` pour `allUsers`).

---

## Déploiement

### Prérequis

- [Terraform installé](https://developer.hashicorp.com/terraform/install) (`terraform -version`)
- `gcloud auth application-default login` (Terraform utilise ces identifiants)

### Étape 1 — Configurer les variables

```bash
cp terraform.tfvars.example terraform.tfvars
# éditer terraform.tfvars : mettre son project_id
```

### Étape 2 — Construire et pousser l'image

Terraform déploie une **image existante** : on la construit d'abord. Le dépôt Artifact Registry est créé par Terraform, donc on l'initialise une première fois pour le créer :

```bash
terraform init
terraform apply -target=google_artifact_registry_repository.repo -target=google_project_service.apis

# Construire et pousser l'image du livre d'or
PROJECT=$(grep project_id terraform.tfvars | cut -d'"' -f2)
gcloud builds submit \
  --tag europe-west1-docker.pkg.dev/$PROJECT/apps/livre-dor:latest
```

### Étape 3 — Déployer toute l'infrastructure

```bash
terraform apply
```

Terraform affiche le plan (ce qu'il va créer), demande confirmation, puis provisionne Firestore + Cloud Run. À la fin, l'URL est affichée dans les outputs :

```
url = "https://livre-dor-xxxxxxxx.europe-west1.run.app"
```

---

## Détruire l'infrastructure

```bash
terraform destroy
```

Une seule commande supprime proprement le service Cloud Run, le dépôt et les liaisons IAM. (La base Firestore `(default)` n'est pas supprimable une fois créée — c'est une limite GCP, pas Terraform.)

---

## gcloud vs Terraform

| Avec gcloud (projet 1) | Avec Terraform (ce projet) |
| --- | --- |
| Commandes tapées une par une | Tout décrit dans des fichiers `.tf` |
| Pas de trace de ce qui existe | État suivi dans `terraform.tfstate` |
| Suppression manuelle, on oublie des ressources | `terraform destroy` nettoie tout |
| Difficile à rejouer sur un autre projet | `terraform apply` reproductible partout |
