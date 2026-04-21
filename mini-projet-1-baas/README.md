# Mini Projet 1 – BaaS (Firebase)

Application web minimaliste qui démontre l'usage d'un **Backend as a Service** via Firebase Firestore.

## Ce que ça fait

- Un champ texte pour saisir un message
- Le message est stocké dans **Firestore** (base de données gérée par Firebase)
- La liste se met à jour en **temps réel** sans rechargement de page

Aucun serveur backend à écrire ni à maintenir : Firebase gère tout (base de données, hébergement, temps réel).

## Déploiement

### 1. Créer un projet Firebase
1. Aller sur [console.firebase.google.com](https://console.firebase.google.com)
2. Créer un nouveau projet
3. Activer **Firestore Database** (mode test)
4. Dans les paramètres du projet > "Ajouter une application Web", copier la config

### 2. Configurer le projet
Dans `index.html`, remplacer :
```js
const firebaseConfig = {
  apiKey: "VOTRE_API_KEY",
  authDomain: "VOTRE_PROJECT_ID.firebaseapp.com",
  projectId: "VOTRE_PROJECT_ID",
};
```

Dans `.firebaserc`, remplacer `VOTRE_PROJECT_ID` par l'ID du projet Firebase.

### 3. Déployer
```bash
npm install -g firebase-tools
firebase login
firebase deploy --only hosting
```

L'application est accessible à l'URL : `https://VOTRE_PROJECT_ID.web.app`
