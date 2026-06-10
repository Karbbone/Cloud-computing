# Mini Projet 2 (Terraform) – FaaS avec Cloud Functions

> Version **Infrastructure as Code** du [mini projet 2](https://github.com/Karbbone/Cloud-computing/tree/p2). Même fonction `helloWorld`, mais déployée et gérée entièrement par **Terraform**.

## Rappel : c'est quoi le FaaS ?

**Function as a Service** = on déploie une simple fonction, pas un serveur. Google l'exécute à la demande et ne facture qu'à l'usage. Ici la fonction répond à une requête HTTP avec un message de bonjour.

## L'apport de Terraform

Au projet 2, on déployait via la console (clics) ou `gcloud functions deploy`. Ici, Terraform :

1. **empaquette automatiquement** le code (`src/`) en `.zip`,
2. l'**upload** dans un bucket,
3. **crée la fonction** Cloud Functions gen2 à partir de ce zip,
4. **ouvre l'accès public**.

Tout est reproductible et destructible en une commande.

---

## Ce qui est décrit dans le code

| Fichier | Rôle |
| --- | --- |
| `src/index.js`, `src/package.json` | Le code de la fonction (inchangé) |
| `main.tf` | Zip du source, bucket, fonction gen2, accès public |
| `variables.tf` / `outputs.tf` | Variables et URL de sortie |

Ressources clés : `archive_file` (zip), `google_storage_bucket` (+ object), `google_cloudfunctions2_function`, `google_cloud_run_v2_service_iam_member` (accès public).

> Astuce : le nom de l'objet zip contient le **hash MD5** du code. Quand on modifie `src/`, le hash change → Terraform détecte la modif et redéploie la fonction automatiquement.

---

## Déploiement

### Prérequis

- [Terraform installé](https://developer.hashicorp.com/terraform/install)
- `gcloud auth application-default login`

### Étapes

```bash
cp terraform.tfvars.example terraform.tfvars   # mettre son project_id
terraform init
terraform apply
```

À la fin, l'URL de la fonction est affichée :

```
function_uri = "https://hello-world-xxxxxxxx.europe-west1.run.app"
```

### Tester

```bash
curl "$(terraform output -raw function_uri)?name=Clement"
# → Bonjour Clement ! Il est 14:32:05.
```

---

## Détruire

```bash
terraform destroy
```

Supprime la fonction, le bucket source et l'objet zip.

---

## gcloud vs Terraform

| `gcloud functions deploy` | Terraform |
| --- | --- |
| Empaquetage et upload implicites, opaques | Zip + upload explicites et versionnés |
| Redéploiement manuel à chaque changement | Redéploiement auto via le hash du code |
| Pas d'état de l'infra | État suivi, `destroy` propre |
