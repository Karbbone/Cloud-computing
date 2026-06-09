# Mini Projet 6 – Scaler une application pour absorber la charge

## C'est quoi le « scaling » ?

**Scaler** = adapter les ressources d'une application à la charge qu'elle reçoit.

Quand 1 utilisateur se connecte, une petite machine suffit. Quand 10 000 utilisateurs arrivent en même temps, il faut plus de puissance, sinon l'application devient lente ou tombe.

Il existe deux façons de scaler :

| Type                   | Principe                                                           | Image                                 |
| ---------------------- | ------------------------------------------------------------------ | ------------------------------------- |
| **Scaling vertical**   | On donne **plus de puissance** à la même machine (plus de CPU/RAM) | Acheter un camion plus gros           |
| **Scaling horizontal** | On **ajoute des machines** identiques et on répartit la charge     | Mettre plusieurs camions sur la route |

Le scaling horizontal est la base du Cloud : il est quasi illimité et automatique.

---

## Le service utilisé : Cloud Run

**Cloud Run** (GCP) exécute l'application dans des conteneurs et fait du **scaling horizontal automatique** :

- 0 trafic → **0 instance** (on ne paie rien)
- Le trafic monte → Cloud Run **crée des instances** en quelques secondes
- Le trafic redescend → Cloud Run **détruit les instances** inutiles

C'est l'**autoscaling** : on ne gère aucun serveur, on configure juste des règles.

---

## Ce que fait l'application

Une petite API Node.js (Express) avec 3 routes :

| Route          | Rôle                                                           |
| -------------- | -------------------------------------------------------------- |
| `/`            | Page d'accueil + liens                                         |
| `/info`        | Affiche l'**ID unique de l'instance** qui répond               |
| `/load?ms=200` | Occupe le **CPU pendant 200 ms** (sert à simuler de la charge) |

Chaque instance génère un ID aléatoire à son démarrage. En envoyant beaucoup de requêtes `/load` en parallèle, Cloud Run crée plusieurs instances : les réponses affichent alors **des IDs différents** → on voit le scaling horizontal en direct.

---

## Déploiement

### Étape 1 — Déployer sur Cloud Run

```bash
gcloud run deploy scaling-demo \
  --source ./mini-projet-6-scaling \
  --region europe-west1 \
  --allow-unauthenticated
```

À la fin, l'URL du service est affichée. L'application répond déjà et scale par défaut (jusqu'à 100 instances).

---

## Configurer le scaling

C'est le cœur du projet. On pilote l'autoscaling avec 4 paramètres au déploiement (ou via la console : **Cloud Run → service → Modifier et déployer une nouvelle révision**).

### 1. Nombre min / max d'instances

```bash
gcloud run services update scaling-demo \
  --region europe-west1 \
  --min-instances 0 \
  --max-instances 10
```

- `--min-instances 0` : descend à zéro quand il n'y a pas de trafic → coût nul, mais le **premier** appel est plus lent (cold start). Mettre `1` pour éviter ça.
- `--max-instances 10` : plafond de sécurité. Empêche une facture explosive en cas de pic ou d'attaque.

### 2. Concurrence (requêtes par instance)

```bash
gcloud run services update scaling-demo \
  --region europe-west1 \
  --concurrency 80
```

- `--concurrency 80` : chaque instance traite jusqu'à 80 requêtes **en même temps** avant que Cloud Run en crée une nouvelle.
- Valeur **haute** → moins d'instances, moins cher (bon pour des requêtes légères).
- Valeur **basse** (ex. `1`) → une instance par requête, idéal pour des tâches lourdes en CPU comme notre `/load`.

C'est le réglage le plus important : il décide **quand** une nouvelle instance est créée.

### 3. CPU et mémoire par instance (scaling vertical)

```bash
gcloud run services update scaling-demo \
  --region europe-west1 \
  --cpu 1 \
  --memory 512Mi
```

On combine ainsi scaling vertical (puissance par instance) et horizontal (nombre d'instances).

---

## Tester le scaling sous charge

### Générer de la charge

On envoie beaucoup de requêtes en parallèle vers `/load`. Avec l'outil [`hey`](https://github.com/rakyll/hey) :

```bash
# 2000 requêtes, 100 en parallèle, chacune occupe le CPU 500 ms
hey -n 2000 -c 100 "https://URL_DU_SERVICE/load?ms=500"
```

Sans installer d'outil, une boucle bash suffit :

```bash
URL="https://URL_DU_SERVICE/info"
for i in $(seq 1 200); do curl -s "$URL" | grep -o '"instance":"[^"]*"' & done; wait \
  | sort | uniq -c
```

Cette dernière commande affiche **combien de réponses sont venues de chaque instance**. Plusieurs IDs = plusieurs instances = scaling réussi.

### Observer dans la console

**Cloud Run → service `scaling-demo` → onglet Métriques** :

- **Nombre d'instances de conteneur** : monte pendant la charge, redescend après.
- **Nombre de requêtes** : le pic de trafic.
- **Latence** : reste stable grâce au scaling (au lieu d'exploser).

---

## Ce qu'on observe

| Phase              | Trafic       | Instances         | Coût                    |
| ------------------ | ------------ | ----------------- | ----------------------- |
| Repos              | 0 req        | 0 (ou 1 si min=1) | ~0                      |
| Charge légère      | quelques req | 1–2               | faible                  |
| Pic (`hey -c 100`) | 100 req/s    | 5–10              | modéré, le temps du pic |
| Après le pic       | 0 req        | retombe à 0       | ~0                      |

**Conclusion** : sans toucher au code ni gérer de serveur, l'application a absorbé un pic de charge en multipliant ses instances, puis a libéré les ressources automatiquement. C'est tout l'intérêt du scaling horizontal managé.

---

## Bonnes pratiques de scaling

- **Toujours définir `--max-instances`** : sinon un pic (ou une attaque DDoS) peut générer des milliers d'instances et une énorme facture.
- **`--min-instances 1`** pour les apps critiques : évite le cold start au prix d'une instance toujours allumée.
- **Ajuster `--concurrency`** selon le type de charge : haute pour des requêtes légères, basse pour des tâches CPU lourdes.
- **Rendre l'app stateless** : aucune instance ne doit stocker de données locales, puisqu'elles sont créées/détruites en permanence.

---

## Nettoyage après la démo

```bash
gcloud run services delete scaling-demo --region europe-west1
```

---
