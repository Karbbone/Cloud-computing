# Mini Projet 3 – Sécuriser son application avec IAM

## C'est quoi IAM ?

**Identity and Access Management (IAM)** = le système de GCP qui contrôle qui peut faire quoi sur quelles ressources.

Sans IAM, tout le monde aurait les mêmes droits sur ton projet GCP (c'est catastrophique en production).

Avec IAM, tu définis des règles précises :
- **Qui** (un compte Google, un compte de service)
- **Peut faire quoi** (rôle : voir, déployer, administrer…)
- **Sur quelle ressource** (tout le projet, ou juste un service Cloud Run)

---

## Objectif du projet

Donner à un collègue de classe les droits **strictement nécessaires** pour déployer son propre serveur Cloud Run, sans lui donner accès à tout le projet.

Principe du **moindre privilège** : on n'accorde que ce dont on a besoin, rien de plus.

---

## Étapes réalisées

### Étape 1 — Identifier le projet GCP

```bash
gcloud config get-value project
```

Résultat : `cloud-computing-457008`

Pour lister tous tes projets :

```bash
gcloud projects list
```

---

### Étape 2 — Créer un compte de service pour le collègue

Un **compte de service** (service account) est une identité non-humaine utilisée par une application ou un développeur pour agir sur GCP.

```bash
gcloud iam service-accounts create collegue-deployer \
  --display-name="Compte déploiement collègue" \
  --project=cloud-computing-457008
```

Cela crée l'identité : `collegue-deployer@cloud-computing-457008.iam.gserviceaccount.com`

---

### Étape 3 — Attribuer les rôles nécessaires

On attribue uniquement les rôles requis pour déployer sur Cloud Run :

**Rôle 1 : Cloud Run Developer** — permet de déployer et gérer des services Cloud Run

```bash
gcloud projects add-iam-policy-binding cloud-computing-457008 \
  --member="serviceAccount:collegue-deployer@cloud-computing-457008.iam.gserviceaccount.com" \
  --role="roles/run.developer"
```

**Rôle 2 : Service Account User** — requis pour qu'un compte puisse agir en tant que compte de service lors d'un déploiement

```bash
gcloud projects add-iam-policy-binding cloud-computing-457008 \
  --member="serviceAccount:collegue-deployer@cloud-computing-457008.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

**Rôle 3 : Storage Object Viewer** — accès en lecture aux images Docker dans Container Registry

```bash
gcloud projects add-iam-policy-binding cloud-computing-457008 \
  --member="serviceAccount:collegue-deployer@cloud-computing-457008.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

---

### Étape 4 — Générer une clé pour le collègue

On génère un fichier JSON que le collègue utilisera pour s'authentifier :

```bash
gcloud iam service-accounts keys create collegue-key.json \
  --iam-account=collegue-deployer@cloud-computing-457008.iam.gserviceaccount.com
```

> ⚠️ Ce fichier `collegue-key.json` est une clé privée. Ne jamais le committer dans Git.

---

### Étape 5 — Le collègue s'authentifie avec la clé

Le collègue utilise la clé pour configurer son environnement local :

```bash
gcloud auth activate-service-account \
  --key-file=collegue-key.json
```

Il peut ensuite déployer sur Cloud Run :

```bash
gcloud run deploy mon-serveur \
  --image=gcr.io/cloud-computing-457008/mon-image \
  --region=europe-west1 \
  --project=cloud-computing-457008
```

---

### Étape 6 — Vérifier les droits attribués

Pour voir toutes les liaisons IAM du projet :

```bash
gcloud projects get-iam-policy cloud-computing-457008
```

Pour voir uniquement les droits d'un compte spécifique :

```bash
gcloud projects get-iam-policy cloud-computing-457008 \
  --flatten="bindings[].members" \
  --filter="bindings.members:collegue-deployer@cloud-computing-457008.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

---

### Étape 7 — Révoquer l'accès (quand ce n'est plus nécessaire)

Bonne pratique : supprimer les accès dès qu'ils ne sont plus utiles.

```bash
gcloud projects remove-iam-policy-binding cloud-computing-457008 \
  --member="serviceAccount:collegue-deployer@cloud-computing-457008.iam.gserviceaccount.com" \
  --role="roles/run.developer"
```

Ou supprimer entièrement le compte de service :

```bash
gcloud iam service-accounts delete \
  collegue-deployer@cloud-computing-457008.iam.gserviceaccount.com
```

---

## Résumé des concepts IAM

| Concept | Définition |
|--------|-----------|
| **Principal** | Qui a les droits (compte Google, compte de service) |
| **Rôle** | Ensemble de permissions prédéfinies (ex : `roles/run.developer`) |
| **Policy binding** | Liaison entre un principal et un rôle sur une ressource |
| **Compte de service** | Identité machine utilisée à la place d'un compte humain |
| **Moindre privilège** | N'accorder que le strict nécessaire |

---

## Pourquoi IAM plutôt que donner son mot de passe ?

| Partage de mot de passe | IAM |
|------------------------|-----|
| Accès total au compte | Accès limité à des ressources précises |
| Impossible à révoquer sélectivement | Révocable à tout moment |
| Pas de traçabilité | Chaque action est loguée dans Cloud Audit Logs |
| Non sécurisé | Standard de sécurité cloud |
