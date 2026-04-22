# Mini Projet 5 – Bucket GCS non sécurisé : impacts et analyse

## Contexte

Ce projet crée volontairement un bucket Google Cloud Storage **mal configuré**, liste tout ce qui n'a pas été sécurisé, et analyse les conséquences concrètes de chaque oubli.

> L'objectif est pédagogique : comprendre les risques pour mieux les éviter en production.

---

## Création du bucket (intentionnellement non sécurisé)

```bash
# 1. Créer le bucket
gsutil mb -l europe-west1 gs://bucket-non-securise-p5

# 2. Ouvrir l'accès en lecture à tout le monde
gsutil iam ch allUsers:objectViewer gs://bucket-non-securise-p5

# 3. Uploader un fichier "sensible" pour la démo
echo "Données confidentielles – ne pas diffuser" > secret.txt
gsutil cp secret.txt gs://bucket-non-securise-p5/secret.txt
```

Le fichier est maintenant lisible par n'importe qui dans le monde via :

```
https://storage.googleapis.com/bucket-non-securise-p5/secret.txt
```

Aucun compte, aucune authentification requise.

---

## Ce qu'on n'a pas sécurisé

### 1. Accès public activé (`allUsers:objectViewer`)

**Ce qui a été fait :** `gsutil iam ch allUsers:objectViewer`

**Impact :** N'importe qui connaissant l'URL peut télécharger tous les fichiers du bucket. Les noms de buckets GCS sont prévisibles (souvent basés sur le nom du projet). Des outils automatisés scannent en permanence les buckets GCS publics.

**Ce qu'il fallait faire :**
```bash
# Ne jamais accorder allUsers. Restreindre à des comptes spécifiques.
gsutil iam ch serviceAccount:mon-service@projet.iam.gserviceaccount.com:objectViewer gs://mon-bucket
```

---

### 2. Versioning désactivé

**Ce qui a été fait :** rien — le versioning est désactivé par défaut.

**Impact :** Si un fichier est écrasé ou supprimé (accidentellement ou par un attaquant), il est **définitivement perdu**. Aucune possibilité de restauration.

**Ce qu'il fallait faire :**
```bash
gsutil versioning set on gs://bucket-non-securise-p5
```

---

### 3. Logs d'accès désactivés

**Ce qui a été fait :** rien — aucun log configuré.

**Impact :** Impossible de savoir qui a accédé à quoi, quand, depuis quelle IP. En cas de fuite de données, on ne peut pas identifier l'origine ni l'étendue de l'incident. Problème majeur pour la conformité RGPD.

**Ce qu'il fallait faire :**
```bash
# Activer les logs dans un bucket dédié
gsutil logging set on -b gs://mon-bucket-logs gs://bucket-non-securise-p5
```

---

### 4. Uniform Bucket-Level Access désactivé

**Ce qui a été fait :** rien — le mode legacy ACL est utilisé par défaut.

**Impact :** Chaque objet peut avoir ses propres permissions, ce qui rend la gestion des accès incohérente et difficile à auditer. Un fichier peut être public même si le bucket est censé être privé.

**Ce qu'il fallait faire :**
```bash
# Forcer des permissions uniformes au niveau du bucket
gsutil uniformbucketlevelaccess set on gs://bucket-non-securise-p5
```

---

### 5. Pas de chiffrement géré (CMEK)

**Ce qui a été fait :** GCS chiffre les données par défaut avec ses propres clés (Google-managed). On n'a pas configuré de clé personnelle.

**Impact :** Google contrôle les clés de chiffrement. En cas de réquisition légale ou de compromission de l'infrastructure Google, les données sont accessibles sans notre consentement.

**Ce qu'il fallait faire :**
```bash
# Utiliser une clé Cloud KMS personnelle
gsutil kms authorize -k projects/projet/locations/europe-west1/keyRings/mon-ring/cryptoKeys/ma-cle \
  gs://bucket-non-securise-p5
```

---

### 6. Pas de politique de cycle de vie

**Ce qui a été fait :** rien — les objets s'accumulent indéfiniment.

**Impact :** Les données sensibles restent stockées pour toujours, même après leur date d'utilité. Coût croissant et surface d'attaque élargie.

**Ce qu'il fallait faire :** définir une règle de suppression automatique :
```bash
gsutil lifecycle set lifecycle.json gs://bucket-non-securise-p5
```

Avec `lifecycle.json` :
```json
{
  "rule": [
    {
      "action": { "type": "Delete" },
      "condition": { "age": 90 }
    }
  ]
}
```

---

### 7. Pas d'alerte sur les accès

**Ce qui a été fait :** aucun monitoring configuré.

**Impact :** Si quelqu'un télécharge massivement les données (exfiltration), aucune alerte n'est déclenchée. On ne le découvrira qu'en regardant la facture.

**Ce qu'il fallait faire :** configurer une alerte Cloud Monitoring sur les métriques `storage.googleapis.com/api/request_count`.

---

## Tableau récapitulatif

| Oubli de sécurité | Impact | Gravité |
|---|---|---|
| Accès public `allUsers` | Fuite de toutes les données | 🔴 Critique |
| Versioning désactivé | Perte définitive en cas de suppression | 🔴 Critique |
| Logs d'accès absents | Aucune traçabilité, non-conformité RGPD | 🟠 Élevé |
| Uniform ACL désactivé | Permissions incohérentes par objet | 🟠 Élevé |
| Pas de CMEK | Clés contrôlées par Google | 🟡 Moyen |
| Pas de lifecycle | Accumulation de données inutiles | 🟡 Moyen |
| Pas d'alerte monitoring | Exfiltration non détectée | 🟠 Élevé |

---

## Scénario d'attaque réel

En 2017–2020, des centaines de buckets S3 (AWS) et GCS mal configurés ont été découverts publics par des chercheurs en sécurité. Parmi les données exposées : données médicales, bases de clients, clés d'API, fichiers de configuration avec mots de passe.

L'outil **GCPBucketBrute** ou de simples scripts peuvent énumérer automatiquement des buckets GCS publics à partir de noms prévisibles (nom de l'entreprise + suffixes courants).

**Un bucket public mal nommé peut être trouvé en quelques minutes.**

---

## Nettoyage après la démo

```bash
# Supprimer le fichier sensible
gsutil rm gs://bucket-non-securise-p5/secret.txt

# Supprimer le bucket entièrement
gsutil rm -r gs://bucket-non-securise-p5
```
