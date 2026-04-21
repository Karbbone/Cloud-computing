# Mini Projet 1 – BaaS (Cloud Run + Firestore)

Application minimaliste démontrant le concept **BaaS** :
- **Firestore** = base de données entièrement managée par Google (le BaaS)
- **Cloud Run** = hébergement sans serveur à gérer

Aucune infrastructure à provisionner ni maintenir.

## Déploiement (depuis Google Cloud Console → Cloud Shell)

```bash
# 1. Activer les APIs nécessaires
gcloud services enable run.googleapis.com firestore.googleapis.com

# 2. Déployer (depuis le dossier du projet)
gcloud run deploy livre-dor \
  --source . \
  --region europe-west1 \
  --allow-unauthenticated
```

L'URL de l'application est affichée à la fin du déploiement.

> Firestore est créé automatiquement dans le projet Google Cloud.
