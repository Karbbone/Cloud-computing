# Cloud Computing

Ce dépôt rassemble plusieurs mini-projets Cloud (Google Cloud Platform). **Chaque projet vit sur sa propre branche** — il faut donc naviguer entre les branches pour consulter chacun d'eux. La branche `main` ne contient que cet index.

## Comment naviguer entre les branches

```bash
git fetch --all          # récupérer toutes les branches du dépôt
git branch -a            # lister les branches disponibles
git checkout p1          # se placer sur le projet 1
git checkout terraform   # se placer sur les versions Terraform
```

Sur GitHub, utilise le sélecteur de branche (en haut à gauche de la page du dépôt) pour passer de l'une à l'autre.

## Les projets (une branche chacun)

| Branche | Projet | Description |
| --- | --- | --- |
| [`p1`](../../tree/p1) | BaaS | Livre d'or sur **Firestore** + Cloud Run |
| [`p2`](../../tree/p2) | FaaS | Fonction HTTP sur **Cloud Functions** |
| [`p3`](../../tree/p3) | IAM | Droits **moindre privilège** pour un collègue |
| [`p4`](../../tree/p4) | Stockage | Benchmark **block vs objet** + coûts |
| [`p5`](../../tree/p5) | Sécurité | Bucket GCS **non sécurisé** : impacts et analyse |
| [`p6`](../../tree/p6) | Scaling | Application qui **scale** automatiquement (Cloud Run) |
| [`p7`](../../tree/p7) | Sécurité | Sécurisation complète (IAM, chiffrement, réseau, monitoring) + **PRA** |

## Version Infrastructure as Code

| Branche | Contenu |
| --- | --- |
| [`terraform`](../../tree/terraform) | **Les 7 projets ci-dessus réécrits en Terraform**, un dossier `pN-terraform` par projet |

Chaque approche est documentée dans le `README.md` de sa branche :

- branches `p1`–`p7` → déploiement via **console GCP / `gcloud`** ;
- branche `terraform` → déploiement via **Terraform** (`init` / `apply` / `destroy`).
