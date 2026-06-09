# Mini Projet 7 – Sécuriser une application de bout en bout

## Application réutilisée

On reprend l'application du **mini projet 4** (`storage-benchmark`) : une API Node.js déployée sur Cloud Run qui lit et écrit des fichiers dans un bucket Google Cloud Storage. Le code est identique — ce projet ne touche pas à l'application, il **sécurise tout ce qui l'entoure**.

L'objectif : montrer comment configurer une application sécurisée selon 4 axes, puis mettre en place une **sauvegarde/restauration automatique** et rédiger un **Plan de Reprise d'Activité (PRA)**.

> Variables utilisées dans les commandes :
>
> ```bash
> PROJECT_ID=$(gcloud config get-value project)
> PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
> REGION=europe-west1
> SERVICE=storage-benchmark
> BUCKET=benchmark-$PROJECT_ID
> ```

---

## 1. IAM – Rôles et moindre privilège

**Principe :** chaque identité ne reçoit que les permissions strictement nécessaires, rien de plus.

### Problème de départ

Par défaut, Cloud Run utilise le **compte de service Compute par défaut**, qui a souvent le rôle `Editor` sur tout le projet — beaucoup trop large.

### Solution : un compte de service dédié et minimal

```bash
# 1. Créer un compte de service dédié à l'application
gcloud iam service-accounts create app-storage-sa \
  --display-name="SA app storage-benchmark"

SA=app-storage-sa@$PROJECT_ID.iam.gserviceaccount.com

# 2. Lui donner UNIQUEMENT l'accès objet sur le bucket (pas admin du projet)
gcloud storage buckets add-iam-policy-binding gs://$BUCKET \
  --member="serviceAccount:$SA" \
  --role="roles/storage.objectAdmin"

# 3. Faire tourner le service Cloud Run sous ce compte
gcloud run services update $SERVICE \
  --region $REGION \
  --service-account $SA
```

| Avant                                               | Après                                              |
| --------------------------------------------------- | -------------------------------------------------- |
| Compte par défaut, rôle `Editor` sur tout le projet | Compte dédié, `objectAdmin` sur **un seul bucket** |
| Une faille = tout le projet compromis               | Une faille = limitée à ce bucket                   |

**Bonnes pratiques appliquées :** rôle au niveau ressource (bucket) et non projet, pas de clé JSON exportée (Cloud Run utilise l'identité managée), révocation simple.

---

## 2. Chiffrement des données – En transit / Au repos / Sauvegardes

### En transit (Encryption in transit)

- Cloud Run **n'expose que du HTTPS** (TLS) — le HTTP est automatiquement redirigé.
- Les appels de l'app vers l'API GCS se font aussi en TLS.
- Rien à configurer : c'est imposé par la plateforme.

### Au repos (Encryption at rest)

GCS chiffre **tout** par défaut avec des clés gérées par Google. Pour garder le contrôle des clés, on utilise **CMEK** (Customer-Managed Encryption Keys) via Cloud KMS :

```bash
# Créer un trousseau et une clé KMS
gcloud kms keyrings create app-keyring --location $REGION

gcloud kms keys create bucket-key \
  --location $REGION --keyring app-keyring --purpose encryption

# Autoriser le compte de service GCS à utiliser la clé
GCS_SA=service-$PROJECT_NUMBER@gs-project-accounts.iam.gserviceaccount.com
gcloud kms keys add-iam-policy-binding bucket-key \
  --location $REGION --keyring app-keyring \
  --member="serviceAccount:$GCS_SA" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"

# Appliquer la clé par défaut au bucket
gcloud storage buckets update gs://$BUCKET \
  --default-encryption-key=projects/$PROJECT_ID/locations/$REGION/keyRings/app-keyring/cryptoKeys/bucket-key
```

### Chiffrement des sauvegardes (Backup encryption)

Le bucket de sauvegarde (voir section Backup) utilise **la même clé KMS**. Les sauvegardes sont donc chiffrées avec une clé que **nous** contrôlons, et qu'on peut révoquer pour rendre les données illisibles instantanément.

---

## 3. Sécurité réseau – Pare-feu et surface d'exposition

**Objectif : réduire la surface d'attaque.** Moins l'application est exposée, moins elle est attaquable.

### Restreindre l'entrée (ingress)

```bash
# N'accepter que le trafic passant par le load balancer interne / VPC,
# au lieu d'exposer le service à tout internet
gcloud run services update $SERVICE \
  --region $REGION \
  --ingress internal-and-cloud-load-balancing
```

| Valeur d'ingress                    | Surface exposée                                        |
| ----------------------------------- | ------------------------------------------------------ |
| `all` (défaut)                      | Tout internet peut appeler l'URL                       |
| `internal-and-cloud-load-balancing` | Seulement le VPC + un load balancer (où on met le WAF) |
| `internal`                          | Seulement le réseau interne                            |

### Pare-feu applicatif (WAF) avec Cloud Armor

Devant le load balancer, **Cloud Armor** filtre le trafic malveillant :

```bash
# Créer une politique de sécurité
gcloud compute security-policies create app-armor-policy

# Bloquer les injections SQL et XSS (règles préconfigurées)
gcloud compute security-policies rules create 1000 \
  --security-policy app-armor-policy \
  --expression "evaluatePreconfiguredExpr('sqli-v33-stable')" \
  --action deny-403

# Limiter le débit : 100 req/min par IP (anti-DDoS / brute force)
gcloud compute security-policies rules create 2000 \
  --security-policy app-armor-policy \
  --action throttle \
  --rate-limit-threshold-count 100 \
  --rate-limit-threshold-interval-sec 60 \
  --conform-action allow --exceed-action deny-429 \
  --enforce-on-key IP
```

**Résultat :** l'app n'est plus joignable en direct ; tout passe par un point d'entrée unique qui filtre injections, XSS et pics de requêtes.

---

## 4. Monitoring et Logging – Logs / Métriques / APM / Dashboards

**Objectif : tout voir, être alerté avant les utilisateurs.**

### Logging

Cloud Run envoie automatiquement ses logs (`console.log` de l'app + logs des requêtes) vers **Cloud Logging**. On peut les filtrer :

```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE" \
  --limit 20 --format "table(timestamp, severity, textPayload)"
```

Les **Cloud Audit Logs** enregistrent en plus qui a accédé à quelle ressource (traçabilité, conformité RGPD).

### Métriques + APM

Cloud Run expose nativement (onglet **Métriques** du service) : nombre de requêtes, latences (p50/p95/p99), taux d'erreurs 5xx, utilisation CPU/RAM, nombre d'instances. C'est l'**APM** intégré.

### Alertes

```bash
# Exemple : alerte si le taux d'erreurs 5xx dépasse un seuil
# (créée dans Cloud Monitoring → Alerting → Create Policy)
```

On configure dans **Cloud Monitoring → Alerting** une politique : _« si le taux de 5xx > 5 % pendant 5 min → email/Slack »_.

### Dashboard

Dans **Cloud Monitoring → Dashboards**, on crée un tableau de bord regroupant : trafic, latence p95, erreurs, instances actives. Une seule vue pour l'état de santé de l'app.

---

## 5. Backup, Restauration et PRA

### Sauvegarde automatique

Trois mécanismes complémentaires sur le bucket de données :

**a) Versioning** — garde chaque version d'un objet écrasé/supprimé :

```bash
gcloud storage buckets update gs://$BUCKET --versioning
```

**b) Réplication vers un bucket de sauvegarde** dans une **autre région** (résilience géographique), chiffré avec notre clé KMS :

```bash
# Bucket de backup dans une région différente
gcloud storage buckets create gs://$BUCKET-backup \
  --location europe-west4 \
  --default-encryption-key=projects/$PROJECT_ID/locations/$REGION/keyRings/app-keyring/cryptoKeys/bucket-key
```

**c) Copie automatique planifiée** via un job Cloud Scheduler qui déclenche une transfert/copie quotidien :

```bash
# Job quotidien à 2h du matin : synchronise data → backup
gcloud scheduler jobs create http daily-backup \
  --location $REGION \
  --schedule "0 2 * * *" \
  --uri "https://storagetransfer.googleapis.com/..." \
  --oauth-service-account-email $SA
```

> En pratique simple, on peut aussi utiliser **Storage Transfer Service** (console : _Transfert_ → _Créer un job de transfert_ → planifié quotidien, source = bucket data, destination = bucket backup).

### Restauration

```bash
# Restaurer un objet précis depuis sa version précédente (versioning)
gcloud storage cp gs://$BUCKET/benchmark.txt#GENERATION gs://$BUCKET/benchmark.txt

# Ou restauration complète depuis le bucket de backup
gcloud storage rsync gs://$BUCKET-backup gs://$BUCKET --recursive
```

---

## Plan de Reprise d'Activité (PRA / DRP)

Le **PRA** décrit comment redémarrer le service après un incident majeur (perte de données, panne régionale, compromission).

### Objectifs

| Indicateur                         | Définition                                  | Cible fixée                                             |
| ---------------------------------- | ------------------------------------------- | ------------------------------------------------------- |
| **RPO** (Recovery Point Objective) | Quantité de données qu'on accepte de perdre | ≤ 24 h (backup quotidien) + versioning quasi temps réel |
| **RTO** (Recovery Time Objective)  | Temps max pour remettre le service en ligne | ≤ 1 h                                                   |

### Scénarios couverts

| Incident                                       | Réponse                                                                                                                   |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| **Suppression accidentelle d'un fichier**      | Restauration via versioning (`gcloud storage cp ...#GENERATION`) — quelques minutes                                       |
| **Corruption / suppression du bucket**         | Restauration depuis le bucket de backup (autre région) via `rsync`                                                        |
| **Panne complète de la région `europe-west1`** | Redéploiement de Cloud Run en `europe-west4` (`gcloud run deploy --region europe-west4`) pointant sur le bucket de backup |
| **Compromission (clé/accès)**                  | Révoquer la clé KMS (données illisibles), recréer le compte de service, restaurer depuis backup                           |

### Procédure de reprise (panne régionale)

1. **Constat & décision** — l'alerte Monitoring signale l'indisponibilité ; on déclenche le PRA.
2. **Redéployer l'application** dans la région de secours :
   ```bash
   gcloud run deploy $SERVICE --source . --region europe-west4 \
     --service-account $SA --allow-unauthenticated
   ```
3. **Rebrancher les données** : pointer l'app sur `gs://$BUCKET-backup` (variable d'env `BUCKET_NAME`).
4. **Vérifier** : tester `/`, lancer un benchmark, contrôler les logs.
5. **Communiquer** : informer les utilisateurs du rétablissement.
6. **Post-mortem** : analyser la cause, mettre à jour le PRA.

### Test du PRA

Un PRA non testé ne vaut rien. **Tous les trimestres**, on simule la perte du bucket principal et on exécute la procédure de restauration en mesurant le temps réel de reprise (doit rester sous le RTO d'1 h).

---

## Tableau récapitulatif de la sécurisation

| Axe             | Avant (app brute)                  | Après (sécurisée)                                |
| --------------- | ---------------------------------- | ------------------------------------------------ |
| **IAM**         | Compte par défaut, droits `Editor` | Compte dédié, `objectAdmin` sur 1 bucket         |
| **Chiffrement** | Clés Google par défaut             | CMEK (clé KMS contrôlée) + TLS partout           |
| **Réseau**      | Exposé à tout internet             | Ingress restreint + Cloud Armor (WAF, anti-DDoS) |
| **Monitoring**  | Aucun                              | Logs, métriques, alertes, dashboard              |
| **Backup/PRA**  | Aucun                              | Versioning + backup multi-région + PRA testé     |

---

## Nettoyage après la démo

```bash
gcloud run services delete $SERVICE --region $REGION
gcloud storage rm --recursive gs://$BUCKET gs://$BUCKET-backup
gcloud kms keys versions destroy 1 --key bucket-key --keyring app-keyring --location $REGION
gcloud iam service-accounts delete $SA
```

---
