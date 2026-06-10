# Mini Projet 4 (Terraform) – Stockage Block vs Objet

> Version **Infrastructure as Code** du [mini projet 4](https://github.com/Karbbone/Cloud-computing/tree/p4). Même application de benchmark (block `/tmp` vs objet GCS), mais le bucket, le service et les droits sont provisionnés par **Terraform**.

## Rappel

L'application compare les temps d'écriture/lecture entre **stockage block** (filesystem local `/tmp`) et **stockage objet** (Google Cloud Storage). Voir le projet 4 pour les concepts et les résultats de coûts.

## L'apport de Terraform

Au projet 4, il fallait déployer puis **ajouter manuellement** le rôle Storage au compte de service. Ici, le bucket, les permissions et le service sont créés **ensemble**, dans le bon ordre, par Terraform :

- le bucket est créé **avant** le service ;
- le service reçoit le nom du bucket via la variable d'environnement `BUCKET_NAME` ;
- le compte de service Cloud Run reçoit `objectAdmin` **sur ce bucket uniquement** (et pas au niveau projet) → moindre privilège.

---

## Ce qui est décrit dans le code

| Ressource | Rôle |
| --- | --- |
| `google_storage_bucket.benchmark` | Le bucket du benchmark (accès uniforme) |
| `google_storage_bucket_iam_member.app_access` | Droit `objectAdmin` sur ce bucket |
| `google_cloud_run_v2_service.app` | Le service, avec `BUCKET_NAME` injecté |
| `google_cloud_run_v2_service_iam_member.public` | Accès public |

---

## Déploiement

### Prérequis

- [Terraform installé](https://developer.hashicorp.com/terraform/install)
- `gcloud auth application-default login`

### Étape 1 — Variables

```bash
cp terraform.tfvars.example terraform.tfvars   # mettre son project_id
terraform init
```

### Étape 2 — Construire l'image

```bash
terraform apply -target=google_artifact_registry_repository.repo -target=google_project_service.apis
PROJECT=$(grep project_id terraform.tfvars | cut -d'"' -f2)
gcloud builds submit --tag europe-west1-docker.pkg.dev/$PROJECT/apps/storage-benchmark:latest
```

### Étape 3 — Tout déployer

```bash
terraform apply
```

L'URL de l'app est dans les outputs. Ouvre-la et lance un benchmark.

---

## Détruire

```bash
terraform destroy
```

`force_destroy = true` permet de supprimer le bucket même s'il contient le fichier `benchmark.txt`.

---

## gcloud vs Terraform

| gcloud (projet 4) | Terraform |
| --- | --- |
| Déploiement puis ajout manuel du rôle Storage | Bucket + droits + service créés ensemble |
| Rôle Storage Admin au niveau **projet** | `objectAdmin` sur **un seul bucket** (moindre privilège) |
| Nom du bucket déduit dans le code | Bucket créé puis injecté via `BUCKET_NAME` |
