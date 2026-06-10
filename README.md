# Cloud Computing – Versions Terraform

Cette branche `terraform` regroupe les **7 mini-projets en Infrastructure as Code (Terraform)**, un dossier par projet. Chaque dossier est autonome (`terraform init` / `apply` / `destroy`).

| Dossier | Projet | Ce que provisionne le Terraform |
| --- | --- | --- |
| [`p1-terraform`](./p1-terraform) | BaaS | Firestore, Cloud Run, Artifact Registry, IAM, accès public |
| [`p2-terraform`](./p2-terraform) | FaaS | Cloud Function gen2 (zip auto du code), bucket source, accès public |
| [`p3-terraform`](./p3-terraform) | IAM | Compte de service + rôles (moindre privilège) |
| [`p4-terraform`](./p4-terraform) | Stockage | Bucket GCS + Cloud Run + IAM au niveau bucket |
| [`p5-terraform`](./p5-terraform) | Bucket non sécurisé | Bucket public mal configuré (défauts commentés) + version corrigée |
| [`p6-terraform`](./p6-terraform) | Scaling | Cloud Run avec min/max instances, concurrence, CPU/RAM en variables |
| [`p7-terraform`](./p7-terraform) | Sécurité + PRA | SA dédié, KMS/CMEK, buckets versionnés + backup, ingress restreint, monitoring, backup auto |

## Prérequis communs

- [Terraform](https://developer.hashicorp.com/terraform/install) (`terraform -version`)
- `gcloud auth application-default login`

## Utilisation type

```bash
cd p1-terraform
cp terraform.tfvars.example terraform.tfvars   # renseigner project_id, etc.
terraform init
terraform apply
# ...
terraform destroy
```

Voir le `README.md` de chaque dossier pour les détails (build d'image, tests, comparatif gcloud vs Terraform).
