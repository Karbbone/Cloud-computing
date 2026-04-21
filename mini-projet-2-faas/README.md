# Mini Projet 2 – FaaS avec Google Cloud Functions

## C'est quoi le FaaS ?

**Function as a Service (FaaS)** = tu déploies une simple fonction, pas un serveur entier.

Sans FaaS, pour exposer une API tu dois :
- louer et configurer un serveur
- gérer le démarrage, l'arrêt, la scalabilité

Avec le FaaS, tu écris juste une fonction. Google l'exécute à la demande et ne la facture qu'à l'utilisation.

Dans ce projet, le FaaS c'est **Google Cloud Functions** : tu déploies `index.js` et Google gère tout le reste.

---

## Ce que fait la fonction

Répond à une requête HTTP avec un message de bonjour et l'heure actuelle.

```
GET https://URL_FONCTION?name=Clement
→ "Bonjour Clement ! Il est 14:32:05."
```

---

## Déploiement (depuis Google Cloud Console → Cloud Shell)

### Étape 1 — Récupérer le code

```bash
git clone https://github.com/Karbbone/Cloud-computing.git
cd Cloud-computing
git checkout p2
cd mini-projet-2-faas
```

### Étape 2 — Activer l'API Cloud Functions

```bash
gcloud services enable cloudfunctions.googleapis.com cloudbuild.googleapis.com
```

### Étape 3 — Déployer la fonction

```bash
gcloud functions deploy helloWorld --runtime nodejs20 --trigger-http --allow-unauthenticated --region europe-west1
```

Le déploiement prend environ 1 minute. L'URL est affichée à la fin :

```
https://europe-west1-projet-1-494007.cloudfunctions.net/helloWorld
```

### Étape 4 — Tester

Ouvre l'URL dans le navigateur, ou avec un paramètre :

```
https://europe-west1-projet-1-494007.cloudfunctions.net/helloWorld?name=Clement
```

---

## Pourquoi c'est du FaaS ?

| Ce que tu gères | Ce que Google gère |
| --------------- | ------------------ |
| La fonction (5 lignes) | Le serveur d'exécution |
| | Le démarrage à la demande |
| | La scalabilité automatique |
| | L'arrêt quand inutilisée |

Tu n'as déployé aucun serveur. Juste une fonction.
