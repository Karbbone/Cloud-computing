# Mini Projet 5 (Terraform) – Bucket GCS non sécurisé

> Version **Infrastructure as Code** du [mini projet 5](https://github.com/Karbbone/Cloud-computing/tree/p5). On crée volontairement un bucket **mal configuré**, mais cette fois la mauvaise configuration est **écrite en Terraform** et chaque défaut est commenté dans le code.

## Intérêt de la version Terraform

C'est encore plus parlant en IaC : chaque faiblesse de sécurité est une **ligne (ou une absence de ligne)** visible dans `main.tf`. On voit d'un coup d'œil ce qui manque, et le fichier `secure.tf.example` montre la version corrigée à comparer côte à côte.

> ⚠️ But uniquement pédagogique. Ne jamais déployer ça en production.

---

## Les défauts présents dans `main.tf`

| # | Défaut | Dans le code | Impact |
| --- | --- | --- | --- |
| 1 | **Accès public** `allUsers` | ressource `public_read` | 🔴 Toutes les données téléchargeables par n'importe qui |
| 2 | **Versioning absent** | pas de bloc `versioning` | 🔴 Suppression/écrasement = perte définitive |
| 3 | **Logs d'accès absents** | pas de bloc `logging` | 🟠 Aucune traçabilité (non conforme RGPD) |
| 4 | **Accès granulaire** | `uniform_bucket_level_access = false` | 🟠 Permissions incohérentes par objet |
| 5 | **Pas de CMEK** | pas de bloc `encryption` | 🟡 Clés contrôlées par Google |
| 6 | **Pas de cycle de vie** | pas de `lifecycle_rule` | 🟡 Données accumulées indéfiniment |

---

## Déployer la démo (le bucket vulnérable)

```bash
cp terraform.tfvars.example terraform.tfvars   # mettre project_id + un bucket_name UNIQUE
terraform init
terraform apply
```

Terraform sort l'URL publique du fichier exposé :

```bash
curl "$(terraform output -raw public_url)"
# → le contenu s'affiche, SANS aucune authentification
```

N'importe qui dans le monde connaissant cette URL peut lire le fichier.

---

## La version corrigée

Le fichier `secure.tf.example` montre le **même bucket correctement sécurisé** :

| Défaut | Correctif Terraform |
| --- | --- |
| Accès public | Supprimer `allUsers`, restreindre à un `serviceAccount` |
| Versioning | `versioning { enabled = true }` |
| Logs | `logging { log_bucket = "..." }` |
| Granulaire | `uniform_bucket_level_access = true` |
| CMEK | `encryption { default_kms_key_name = "..." }` |
| Cycle de vie | `lifecycle_rule { ... age = 90 ... }` |

C'est exactement l'approche du **mini projet 7** (sécurisation complète), mais ici en Terraform.

---

## Nettoyage

```bash
terraform destroy
```

Supprime le bucket, le fichier et la liaison publique. Avantage majeur de l'IaC : impossible d'oublier une ressource exposée — `destroy` enlève tout ce qui a été créé.

---

## Scénario d'attaque

Des outils automatisés énumèrent en permanence les buckets GCS publics à partir de noms prévisibles. Un bucket public mal nommé est trouvable en quelques minutes. En IaC, le risque est qu'un `allUsers` se glisse dans une revue : d'où l'intérêt des outils de scan de code Terraform (tfsec, Checkov) qui **bloquent** ce genre de configuration avant le déploiement.
