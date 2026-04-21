const functions = require("@google-cloud/functions-framework");

functions.http("helloWorld", (req, res) => {
  const name = req.query.name || "monde";
  res.send(`Bonjour ${name} ! Il est ${new Date().toLocaleTimeString("fr-FR")}.`);
});
