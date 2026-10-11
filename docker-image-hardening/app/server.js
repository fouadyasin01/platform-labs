const express = require("express");

const app = express();
const port = 3000;

app.get("/", (req, res) => {
  res.json({
    service: "docker-image-hardening-demo",
    status: "running"
  });
});

app.get("/health", (req, res) => {
  res.json({
    status: "healthy"
  });
});

app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});
