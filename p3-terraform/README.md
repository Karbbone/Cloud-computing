# Mini Projet 3 (Terraform) – IAM et moindre privilège

> Version **Infrastructure as Code** du [mini projet 3](https://github.com/Karbbone/Cloud-computing/tree/p3). On donne à un collègue les droits **strictement nécessaires** pour déployer sur Cloud Run, mais cette fois les identités et les rôles sont décrits en **Terraform**.

## Rappel : IAM et moindre privilège

**IAM** contrôle *qui* peut faire *quoi* sur *quelle ressource*. Le **moindre privilège** : n'accorder que ce qui est strictement nécessaire, rien de plus.

## L'apport de Terraform pour l'IAM

L'IAM géré à la main (`gcloud ... add-iam-policy-binding`) dérive vite : on ajoute des droits « au cas où », on oublie de les retirer. Avec Terraform :

- la liste des rôles est **explicite et auditable** dans `variables.tf` ;
- retirer un droit = retirer une ligne + `terraform apply` ;
- supprimer le compte et **tous** ses droits d'un coup = `terraform destroy`.

C'est l'**IAM as Code** : la politique d'accès est versionnée et revue comme du code.

---

## Ce qui est décrit dans le code

| Ressource | Rôle |
| --- | --- |
| `google_service_account.deployer` | Le compte de service du collègue |
| `google_project_iam_member.deployer_roles` | Une liaison par rôle (via `for_each`) |
| `google_service_account_key.deployer_key` | Clé d'authentification (sortie sensible) |

Les 3 rôles accordés (et **seulement** ceux-là) :

| Rôle | Pourquoi |
| --- | --- |
| `roles/run.developer` | Déployer et gérer des services Cloud Run |
| `roles/iam.serviceAccountUser` | Agir en tant que compte de service au déploiement |
| `roles/storage.objectViewer` | Lire les images de conteneur |

---

## Déploiement

```bash
cp terraform.tfvars.example terraform.tfvars   # mettre son project_id
terraform init
terraform apply
```

### Récupérer la clé pour le collègue

```bash
terraform output -raw deployer_key | base64 -d > collegue-key.json
gcloud auth activate-service-account --key-file=collegue-key.json
```

### Vérifier les droits

```bash
gcloud projects get-iam-policy $(grep project_id terraform.tfvars | cut -d'"' -f2) \
  --flatten="bindings[].members" \
  --filter="bindings.members:collegue-deployer@*" \
  --format="table(bindings.role)"
```

---

## Révoquer / nettoyer

Pour retirer **un** droit : supprimer le rôle de la liste `deployer_roles` dans `variables.tf` puis `terraform apply`.

Pour tout supprimer (compte + droits + clé) :

```bash
terraform destroy
```

---

## gcloud vs Terraform

| `gcloud add-iam-policy-binding` | Terraform |
| --- | --- |
| Droits ajoutés un par un, sans vue d'ensemble | Liste centralisée et auditable |
| Révocation à la main, on oublie | `apply`/`destroy` cohérent |
| Pas de revue | La politique passe en revue de code (PR) |
