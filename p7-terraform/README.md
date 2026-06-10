# Mini Projet 7 (Terraform) – Sécuriser une application de bout en bout

> Version **Infrastructure as Code** du [mini projet 7](https://github.com/Karbbone/Cloud-computing/tree/p7). On reprend l'application de stockage (projet 4) et on la sécurise selon 4 axes + backup/PRA, mais **tout est décrit en Terraform** au lieu de commandes `gcloud`.

## Pourquoi la sécurité en IaC ?

Sécuriser à la main (`gcloud`) c'est fragile : on oublie une étape, on ne sait plus quel est l'état réel, on ne peut pas auditer. En Terraform, **toute la posture de sécurité est dans le code** : revue en PR, scannée par des outils (tfsec, Checkov), reproductible et destructible proprement.

Le fichier `main.tf` est découpé en 5 sections numérotées correspondant aux axes ci-dessous.

---

## 1. IAM – Moindre privilège

```hcl
resource "google_service_account" "app" { ... }            # SA dédié à l'app
resource "google_storage_bucket_iam_member" "app_access" { # objectAdmin
  bucket = google_storage_bucket.data.name                 #  sur CE bucket
  role   = "roles/storage.objectAdmin"                      #  uniquement
}
```

Le service Cloud Run tourne sous un **compte de service dédié** (`service_account = ...` dans le template), pas le compte par défaut surprivilégié. Ce compte n'a accès qu'au bucket de données — rien d'autre dans le projet.

## 2. Chiffrement – Transit / Repos / Sauvegardes

- **En transit** : Cloud Run impose le HTTPS/TLS (rien à coder).
- **Au repos (CMEK)** : on crée nos propres clés Cloud KMS et on les applique aux buckets via `encryption { default_kms_key_name = ... }`. Une clé par région (CMEK exige clé et bucket co-localisés).
- **Sauvegardes** : le bucket de backup est lui aussi chiffré avec une clé KMS qu'on contrôle.

```hcl
resource "google_kms_crypto_key" "main" { ... }
resource "google_storage_bucket" "data" {
  encryption { default_kms_key_name = google_kms_crypto_key.main.id }
}
```

Révoquer la clé KMS rend instantanément les données illisibles.

## 3. Réseau – Surface d'exposition

```hcl
resource "google_cloud_run_v2_service" "app" {
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
}
```

Le service **n'est pas joignable directement depuis internet** : seul le trafic venant d'un load balancer est accepté. C'est devant ce load balancer qu'on branche **Cloud Armor** (WAF anti-injection/XSS + rate-limiting anti-DDoS). La surface d'attaque est réduite à un point d'entrée unique et filtré.

## 4. Monitoring & Logging

```hcl
resource "google_monitoring_notification_channel" "email" { ... }
resource "google_monitoring_alert_policy" "errors_5xx" { ... }
```

- **Logging** : Cloud Run envoie automatiquement logs et audit logs vers Cloud Logging.
- **Métriques / APM** : exposées nativement (requêtes, latences p95/p99, erreurs, instances).
- **Alerte** : une politique déclenche un email dès que le taux de **5xx** dépasse 0 sur 5 min.
- **Dashboard** : à composer dans Cloud Monitoring (trafic, latence, erreurs).

## 5. Backup, Restauration et PRA

- **Versioning** activé sur les deux buckets (`versioning { enabled = true }`).
- **Bucket de backup dans une autre région** (`europe-west4`) → résilience géographique.
- **Sauvegarde automatique quotidienne** via `google_storage_transfer_job` (2h du matin, data → backup), avec les droits accordés au compte de service du Storage Transfer Service.

---

## Déploiement

### Prérequis

- [Terraform installé](https://developer.hashicorp.com/terraform/install)
- `gcloud auth application-default login`

```bash
cp terraform.tfvars.example terraform.tfvars   # project_id, alert_email, image
terraform init

# 1) APIs + dépôt, puis build de l'image
terraform apply -target=google_artifact_registry_repository.repo -target=google_project_service.apis
PROJECT=$(grep project_id terraform.tfvars | cut -d'"' -f2)
gcloud builds submit --tag europe-west1-docker.pkg.dev/$PROJECT/apps/storage-benchmark:latest

# 2) Toute l'infra sécurisée
terraform apply
```

> Note : l'ingress étant restreint au load balancer, l'app n'est pas testable via son URL directe. Pour un test rapide, basculer temporairement `ingress = "INGRESS_TRAFFIC_ALL"`, ou monter un load balancer HTTPS + Cloud Armor devant le service.

---

## Plan de Reprise d'Activité (PRA)

| Indicateur | Cible |
| --- | --- |
| **RPO** (perte de données max) | ≤ 24 h (backup quotidien) + versioning quasi temps réel |
| **RTO** (temps de remise en ligne) | ≤ 1 h |

| Incident | Réponse (avec cette infra Terraform) |
| --- | --- |
| Fichier supprimé par erreur | Restauration via le **versioning** du bucket |
| Bucket corrompu/supprimé | Restauration depuis le **bucket de backup** (`gcloud storage rsync`) |
| Panne de la région `europe-west1` | `terraform apply -var region=europe-west4` redéploie l'infra dans la région de secours |
| Compromission d'une clé/accès | Révoquer la clé KMS (données illisibles), recréer le SA, restaurer depuis backup |

**Procédure (panne régionale) :** alerte Monitoring → changer `region` → `terraform apply` dans la région de backup → vérifier → communiquer → post-mortem.

**Test du PRA** : tous les trimestres, simuler la perte du bucket principal et exécuter la restauration en mesurant le temps réel (doit rester sous le RTO).

---

## Détruire

```bash
terraform destroy
```

Supprime SA, clés KMS, buckets, service, alerte et job de backup. Avantage IaC : aucune ressource sensible oubliée.

---

## Récapitulatif : gcloud vs Terraform

| Axe | gcloud (projet 7) | Terraform (ce projet) |
| --- | --- | --- |
| IAM | Commandes éparses | SA + droits dans le code, audités |
| Chiffrement | KMS configuré à la main | Clés + CMEK déclaratifs |
| Réseau | `--ingress` en flag | `ingress` versionné |
| Monitoring | Créé dans la console | Alertes as code |
| Backup/PRA | Job créé manuellement | `transfer_job` + PRA reproductible (`-var region=`) |
