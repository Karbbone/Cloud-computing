# Mini Projet 1 – BaaS avec Google Cloud

## C'est quoi le BaaS ?

**Backend as a Service (BaaS)** = tu utilises un backend tout fait, hébergé et géré par un tiers.

Sans BaaS, pour stocker des données tu dois :
- louer un serveur
- installer une base de données
- la configurer, la sécuriser, la maintenir

Avec le BaaS, tu appelles juste une API. Google gère tout le reste.

Dans ce projet, le BaaS c'est **Firestore** : une base de données NoSQL entièrement managée par Google. Tu n'installes rien, tu n'administres rien.

---

## Ce que fait l'application

Un livre d'or minimaliste :
- un formulaire pour écrire un message
- les messages sont sauvegardés dans Firestore (BaaS)
- la liste s'affiche à chaque visite

---

## Prérequis

- Un compte Google
- Un projet Google Cloud (gratuit pour tester) → [console.cloud.google.com](https://console.cloud.google.com)

---

## Déploiement étape par étape

### Étape 1 — Ouvrir Google Cloud Console

Va sur [console.cloud.google.com](https://console.cloud.google.com) et connecte-toi avec ton compte Google.

### Étape 2 — Créer un projet

1. En haut à gauche, clique sur le sélecteur de projet
2. **New Project**
3. Donne-lui un nom (ex: `mini-projet-baas`)
4. Clique **Create**

### Étape 3 — Ouvrir Cloud Shell

En haut à droite de la console, clique sur l'icône **Cloud Shell** (le petit terminal `>_`).

Un terminal s'ouvre directement dans le navigateur. Tu n'as rien à installer sur ton ordinateur.

### Étape 4 — Récupérer le code

Dans Cloud Shell, clone le repo :

```bash
git clone https://github.com/TON_PSEUDO/TON_REPO.git
cd TON_REPO/mini-projet-1-baas
```

### Étape 5 — Créer la base de données Firestore

```bash
gcloud firestore databases create --region=europe-west1
```

C'est cette commande qui provisionne ta base de données. Tu ne touches à rien d'autre — c'est le principe du BaaS.

### Étape 6 — Déployer l'application

```bash
gcloud services enable run.googleapis.com

gcloud run deploy livre-dor \
  --source . \
  --region europe-west1 \
  --allow-unauthenticated
```

- `--source .` : Google Cloud détecte automatiquement que c'est du Node.js et construit l'image
- `--allow-unauthenticated` : l'app est accessible publiquement

Le déploiement prend environ 2 minutes. À la fin, tu obtiens une URL du type :
```
https://livre-dor-xxxxxxxxxx-ew.a.run.app
```

Ouvre cette URL dans ton navigateur : l'application est en ligne.

---

## Pourquoi c'est du BaaS ?

| Ce que tu gères | Ce que Google gère |
|---|---|
| Le code de l'app (30 lignes) | La base de données Firestore |
| | Les serveurs, la RAM, le stockage |
| | La scalabilité et la disponibilité |
| | Les sauvegardes |

Tu n'as configuré aucun serveur de base de données. Tu as juste appelé `gcloud firestore databases create` et Firestore existait. C'est ça, le BaaS.
