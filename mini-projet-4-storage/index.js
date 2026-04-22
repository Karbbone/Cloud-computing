const express = require("express");
const { Storage } = require("@google-cloud/storage");
const fs = require("fs");

const app = express();
const storage = new Storage();
const BUCKET = process.env.BUCKET_NAME || `benchmark-${process.env.GOOGLE_CLOUD_PROJECT || "local"}`;
const BLOCK_PATH = "/tmp/benchmark.txt";

app.use(express.urlencoded({ extended: true }));

async function ensureBucket() {
  const bucket = storage.bucket(BUCKET);
  const [exists] = await bucket.exists();
  if (!exists) {
    await bucket.create({ location: "europe-west1" });
    console.log(`Bucket ${BUCKET} créé`);
  }
}

app.get("/", (req, res) => {
  res.send(`
    <h1>Benchmark – Stockage Block vs Objet</h1>
    <form method="POST" action="/benchmark">
      <label>Taille des données :</label><br/>
      <select name="taille">
        <option value="1">1 Ko</option>
        <option value="100">100 Ko</option>
        <option value="1000">1 Mo</option>
      </select>
      <br/><br/>
      <button type="submit">Lancer le benchmark</button>
    </form>
  `);
});

app.post("/benchmark", async (req, res) => {
  const ko = parseInt(req.body.taille, 10);
  const data = Buffer.alloc(ko * 1024, "x").toString();

  // --- Block storage (filesystem /tmp, simule un disque persistant) ---
  const t1 = Date.now();
  fs.writeFileSync(BLOCK_PATH, data);
  const blockWrite = Date.now() - t1;

  const t2 = Date.now();
  fs.readFileSync(BLOCK_PATH, "utf8");
  const blockRead = Date.now() - t2;

  // --- Object storage (Google Cloud Storage) ---
  const file = storage.bucket(BUCKET).file("benchmark.txt");

  const t3 = Date.now();
  await file.save(data);
  const objectWrite = Date.now() - t3;

  const t4 = Date.now();
  await file.download();
  const objectRead = Date.now() - t4;

  res.send(`
    <h1>Résultats – ${ko} Ko</h1>
    <table border="1" cellpadding="8">
      <tr><th>Opération</th><th>Block /tmp (ms)</th><th>Objet GCS (ms)</th></tr>
      <tr><td>Écriture</td><td>${blockWrite}</td><td>${objectWrite}</td></tr>
      <tr><td>Lecture</td><td>${blockRead}</td><td>${objectRead}</td></tr>
    </table>
    <br/>
    <p><strong>Interprétation :</strong> Le block storage est plus rapide (accès disque local).
    Le stockage objet ajoute une latence réseau mais est bien moins cher à grande échelle.</p>
    <br/><a href="/">← Nouveau test</a>
  `);
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, async () => {
  await ensureBucket();
  console.log(`Listening on port ${PORT}`);
});
