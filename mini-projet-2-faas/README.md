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

## Déploiement (via Google Cloud Console + GitHub)

### Étape 1 — Ouvrir Cloud Run

Va sur [console.cloud.google.com](https://console.cloud.google.com), recherche **Cloud Run** et ouvre le service.

### Étape 2 — Créer une fonction

Clique sur **Écrire une fonction**, puis sélectionne **Node.js**.

### Étape 3 — Connecter GitHub

Sélectionne **GitHub** comme source, puis connecte ton compte GitHub et choisis :

- **Repository** : `Karbbone/Cloud-computing`
- **Branch** : `p2`
- **Répertoire de contexte** : `/mini-projet-2-faas`
- **Cible de la fonction** : `helloWorld`

### Étape 4 — Configurer l'accès

Dans la section **Authentification**, sélectionne **Autoriser l'accès public**.

### Étape 5 — Déployer

Clique **Déployer**. Le déploiement prend environ 1 minute. L'URL est affichée à la fin.

### Étape 6 — Tester

Ouvre l'URL dans le navigateur, ou avec un paramètre :

```
https://TON_URL?name=Clement
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
