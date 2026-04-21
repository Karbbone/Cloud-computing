const express = require("express");
const { Firestore } = require("@google-cloud/firestore");

const app = express();
const db = new Firestore();

app.use(express.urlencoded({ extended: true }));

app.get("/", async (req, res) => {
  const snapshot = await db.collection("messages").orderBy("date", "desc").get();
  const messages = snapshot.docs.map((d) => d.data().texte);

  res.send(`
    <h1>Livre d'or – BaaS demo</h1>
    <form method="POST" action="/add">
      <input name="texte" placeholder="Votre message" required />
      <button type="submit">Envoyer</button>
    </form>
    <ul>${messages.map((m) => `<li>${m}</li>`).join("")}</ul>
  `);
});

app.post("/add", async (req, res) => {
  await db.collection("messages").add({ texte: req.body.texte, date: new Date() });
  res.redirect("/");
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`Listening on port ${PORT}`));
