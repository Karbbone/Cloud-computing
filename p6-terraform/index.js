const express = require("express");
const crypto = require("crypto");

const app = express();

// Identité unique de l'instance : générée au démarrage du conteneur.
// Si Cloud Run lance plusieurs instances pour absorber la charge,
// chaque réponse affichera un ID différent → on "voit" le scaling horizontal.
const INSTANCE_ID = crypto.randomBytes(4).toString("hex");
const STARTED_AT = new Date().toISOString();
let requestCount = 0;

// Page d'accueil : explique l'app et donne les liens
app.get("/", (req, res) => {
  res.send(`
    <h1>Mini Projet 6 – Scaling sur Cloud Run</h1>
    <p>Instance : <strong>${INSTANCE_ID}</strong> (démarrée à ${STARTED_AT})</p>
    <ul>
      <li><a href="/info">/info</a> — identité de l'instance + nb de requêtes traitées</li>
      <li><a href="/load">/load</a> — calcul CPU lourd (sert à générer de la charge)</li>
      <li><a href="/load?ms=500">/load?ms=500</a> — charge pendant 500 ms</li>
    </ul>
    <p>Lance plusieurs requêtes /load en parallèle puis observe les
    différents IDs d'instance : Cloud Run a "scalé" automatiquement.</p>
  `);
});

// Endpoint léger : retourne qui répond. Utile pour repérer les instances.
app.get("/info", (req, res) => {
  requestCount++;
  res.json({
    instance: INSTANCE_ID,
    startedAt: STARTED_AT,
    requestsHandledByThisInstance: requestCount,
    region: process.env.GOOGLE_CLOUD_REGION || "inconnue",
  });
});

// Endpoint lourd : occupe le CPU pendant `ms` millisecondes.
// Plus on l'appelle en parallèle, plus Cloud Run doit créer d'instances.
app.get("/load", (req, res) => {
  requestCount++;
  const ms = Math.min(parseInt(req.query.ms, 10) || 200, 5000);
  const start = Date.now();
  let iterations = 0;

  // Boucle CPU-bound : hachage en continu jusqu'à épuiser le délai.
  while (Date.now() - start < ms) {
    crypto.createHash("sha256").update(String(iterations)).digest("hex");
    iterations++;
  }

  res.json({
    instance: INSTANCE_ID,
    cpuTimeMs: Date.now() - start,
    iterations,
    requestsHandledByThisInstance: requestCount,
  });
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Instance ${INSTANCE_ID} à l'écoute sur le port ${PORT}`);
});
