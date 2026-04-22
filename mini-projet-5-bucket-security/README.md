# Mini Projet 5 – Bucket GCS non sécurisé : impacts et analyse

## Contexte

Ce projet crée volontairement un bucket Google Cloud Storage **mal configuré**, liste tout ce qui n'a pas été sécurisé, et analyse les conséquences concrètes de chaque oubli.

> L'objectif est pédagogique : comprendre les risques pour mieux les éviter en production.

---

## Création du bucket via la console GCP

### Étape 1 — Ouvrir Cloud Storage

Va sur [console.cloud.google.com](https://console.cloud.google.com), recherche **Cloud Storage** et clique sur **Buckets**.

### Étape 2 — Créer un bucket

Clique sur **Créer**, puis remplis :

- **Nom** : `bucket-non-securise-p5` (le nom doit être unique mondial)
- **Région** : `europe-west1`
- **Classe de stockage** : Standard
- **Contrôle des accès** : laisser sur **Granulaire** (au lieu de Uniforme)
- **Protection des données** : ne pas activer le versioning

Clique **Créer**.

### Étape 3 — Rendre le bucket public

Dans l'onglet **Autorisations** du bucket :

1. Clique **Accorder l'accès**
2. Dans **Nouveaux comptes principaux**, tape `allUsers`
3. Dans **Rôle**, sélectionne **Lecteur des objets Storage**
4. Clique **Enregistrer**
5. Confirme le message d'avertissement "Ce bucket sera public"

### Étape 4 — Uploader un fichier

Dans l'onglet **Objets**, clique **Charger des fichiers** et dépose n'importe quel fichier.

Le fichier est maintenant accessible publiquement via :

```text
https://storage.googleapis.com/bucket-non-securise-p5/[nom-du-fichier]
```

Aucun compte, aucune authentification requise.

---

## Ce qu'on n'a pas sécurisé

### 1. Accès public activé (`allUsers`)

**Ce qui a été fait :** dans Autorisations → `allUsers` avec le rôle Lecteur des objets.

**Impact :** N'importe qui connaissant l'URL peut télécharger tous les fichiers. Les noms de buckets GCS sont souvent prévisibles. Des outils automatisés scannent en permanence les buckets GCS publics.

**Ce qu'il fallait faire :** ne jamais ajouter `allUsers`. Restreindre l'accès à des comptes de service ou des utilisateurs spécifiques via **Autorisations → Accorder l'accès**.

---

### 2. Versioning désactivé

**Ce qui a été fait :** lors de la création, on n'a pas coché **Activer la protection contre la suppression temporaire et le versioning** dans la section Protection des données.

**Impact :** Si un fichier est écrasé ou supprimé (accidentellement ou par un attaquant), il est **définitivement perdu**. Aucune restauration possible.

**Ce qu'il fallait faire :** dans **Protection des données** → activer le versioning.

---

### 3. Logs d'accès désactivés

**Ce qui a été fait :** rien — aucun log configuré.

**Impact :** Impossible de savoir qui a accédé à quoi, quand, depuis quelle IP. En cas de fuite, on ne peut pas identifier l'origine ni l'étendue. Non conforme RGPD.

**Ce qu'il fallait faire :** dans les paramètres du bucket → **Journaux d'audit** → activer les logs dans un bucket dédié.

---

### 4. Contrôle d'accès Granulaire au lieu de Uniforme

**Ce qui a été fait :** lors de la création, on a laissé le mode **Granulaire** (legacy ACL).

**Impact :** Chaque fichier peut avoir ses propres permissions. Un fichier peut être public même si le bucket est censé être privé. Très difficile à auditer.

**Ce qu'il fallait faire :** sélectionner **Uniforme** à la création. Cela force des permissions cohérentes sur tous les objets du bucket.

---

### 5. Pas de chiffrement géré (CMEK)

**Ce qui a été fait :** GCS chiffre les données par défaut avec ses propres clés (Google-managed).

**Impact :** Google contrôle les clés. En cas de réquisition légale ou de compromission, les données sont accessibles sans notre consentement explicite.

**Ce qu'il fallait faire :** dans **Configuration** → **Chiffrement** → sélectionner une clé Cloud KMS personnelle.

---

### 6. Pas de politique de cycle de vie

**Ce qui a été fait :** rien — les objets s'accumulent indéfiniment.

**Impact :** Les données sensibles restent stockées pour toujours. Coût croissant et surface d'attaque élargie.

**Ce qu'il fallait faire :** dans **Cycle de vie** → **Ajouter une règle** → supprimer les objets après 90 jours.

---

### 7. Pas d'alerte monitoring

**Ce qui a été fait :** aucun monitoring configuré.

**Impact :** Si quelqu'un télécharge massivement les données (exfiltration), aucune alerte. On ne le découvre qu'en regardant la facture.

**Ce qu'il fallait faire :** dans **Cloud Monitoring** → créer une alerte sur `storage/api/request_count`.

---

## Tableau récapitulatif

| Oubli de sécurité | Impact | Gravité |
| --- | --- | --- |
| Accès public `allUsers` | Fuite de toutes les données | 🔴 Critique |
| Versioning désactivé | Perte définitive en cas de suppression | 🔴 Critique |
| Logs d'accès absents | Aucune traçabilité, non-conformité RGPD | 🟠 Élevé |
| Contrôle Granulaire | Permissions incohérentes par objet | 🟠 Élevé |
| Pas de CMEK | Clés contrôlées par Google | 🟡 Moyen |
| Pas de lifecycle | Accumulation de données inutiles | 🟡 Moyen |
| Pas d'alerte monitoring | Exfiltration non détectée | 🟠 Élevé |

---

## Scénario d'attaque réel

Entre 2017 et 2020, des centaines de buckets S3 (AWS) et GCS mal configurés ont été découverts publics par des chercheurs en sécurité. Parmi les données exposées : données médicales, bases clients, clés d'API, fichiers de configuration avec mots de passe.

Des outils automatisés énumèrent les buckets GCS à partir de noms prévisibles (nom de l'entreprise + suffixes courants). **Un bucket public mal nommé peut être trouvé en quelques minutes.**

---

## Nettoyage après la démo

Dans la console, onglet **Objets** : sélectionner tous les fichiers → **Supprimer**.

Puis dans la liste des buckets : cliquer sur les trois points à droite du bucket → **Supprimer**.
