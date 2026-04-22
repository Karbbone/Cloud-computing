# Mini Projet 4 – Stockage Block vs Objet : benchmark et coûts

## C'est quoi le stockage Block vs Objet ?

### Stockage Block (Persistent Disk sur GCP)
Un disque attaché à une VM, comme le disque dur de ton ordinateur. Tu y accèdes via le système de fichiers (`/data/fichier.txt`). Très rapide, mais lié à une seule machine.

### Stockage Objet (Google Cloud Storage)
Un entrepôt de fichiers accessible via une API HTTP depuis n'importe où. Moins rapide (latence réseau), mais massivement scalable et bien moins cher.

| | Block (Persistent Disk) | Objet (GCS) |
|---|---|---|
| Accès | Système de fichiers | API HTTP |
| Latence | Très faible (µs–ms) | Plus élevée (ms–dizaines de ms) |
| Scalabilité | Limitée à la VM | Illimitée |
| Usage typique | Base de données, OS | Backup, media, logs, ML datasets |

---

## Ce que fait l'application

Une interface web simple qui :
1. Génère un fichier de taille choisie (1 Ko, 100 Ko ou 1 Mo)
2. L'écrit et le relit en **stockage block** (filesystem `/tmp`, qui simule un disque persistant)
3. L'écrit et le relit en **stockage objet** (Google Cloud Storage)
4. Affiche les temps en millisecondes pour comparer

---

## Déploiement

Une seule commande, comme le projet p1. Le bucket GCS est créé automatiquement par l'application au démarrage.

### Étape 1 — Déployer sur Cloud Run

```bash
gcloud run deploy storage-benchmark \
  --source ./mini-projet-4-storage \
  --region europe-west1 \
  --allow-unauthenticated
```

Cloud Run détecte automatiquement le projet GCP courant via la variable `GOOGLE_CLOUD_PROJECT` et nomme le bucket `benchmark-[ID-PROJET]`.

### Étape 2 — Donner les droits Storage au compte de service Cloud Run

Par défaut, le compte de service Cloud Run n'a pas le droit de créer des buckets. On lui accorde le rôle Storage Admin :

```bash
# Récupérer l'email du compte de service
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
  --role="roles/storage.admin"
```

C'est la seule étape manuelle. Ensuite le bucket est créé et géré par l'app.

---

## Résultats observés (exemples typiques)

| Taille | Block write (ms) | Block read (ms) | GCS write (ms) | GCS read (ms) |
|--------|-----------------|----------------|----------------|---------------|
| 1 Ko   | < 1             | < 1            | 80–150         | 50–120        |
| 100 Ko | 1–2             | < 1            | 100–200        | 80–160        |
| 1 Mo   | 3–8             | 2–5            | 200–500        | 150–400       |

**Conclusion** : le block storage est 50× à 100× plus rapide, mais uniquement accessible depuis la machine sur laquelle il est monté.

---

## Coût mensuel pour 1 To

### Stockage Block – Persistent Disk (GCP)

| Type | Prix/Go/mois | Prix/To/mois |
|------|-------------|-------------|
| HDD standard | 0,040 $ | **~41 $** |
| SSD | 0,170 $ | **~174 $** |

Le disque est **réservé** en permanence même s'il est vide.

### Stockage Objet – Google Cloud Storage

| Classe | Prix/Go/mois | Prix/To/mois | Usage |
|--------|-------------|-------------|-------|
| Standard | 0,020 $ | **~20 $** | Données accédées souvent |
| Nearline | 0,010 $ | **~10 $** | Accès < 1×/mois |
| Coldline | 0,004 $ | **~4 $** | Accès < 1×/trimestre |
| Archive  | 0,0012 $ | **~1,2 $** | Archivage long terme |

> Attention : GCS facture aussi les opérations (lectures/écritures) et l'egress réseau, mais ces coûts restent faibles pour des usages classiques.

### Comparaison directe pour 1 To

```
Block SSD         : ~174 $/mois
Block HDD         : ~ 41 $/mois
Objet Standard    : ~ 20 $/mois   ← 2× moins cher que HDD
Objet Nearline    : ~ 10 $/mois   ← 4× moins cher que HDD
Objet Coldline    : ~  4 $/mois
Objet Archive     : ~  1,2 $/mois ← 34× moins cher que SSD !
```

**Règle simple** : si tu n'as pas besoin de la vitesse d'un disque local, le stockage objet est presque toujours la bonne réponse économique.

---

## Lien application déployée

> À compléter après déploiement
