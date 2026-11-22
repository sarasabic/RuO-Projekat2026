// Emoji Movie Quiz - frontend 

const express = require("express");
const path = require("path");

const PORT = Number(process.env.PORT || 3000);
const BACKEND_URL = process.env.BACKEND_URL || "http://backend:8000";

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

app.get("/healthz", (req, res) => res.json({ status: "ok" }));

// Reverse proxy: /api/puzzle?exclude=1 -> BACKEND_URL/api/puzzle?exclude=1
app.use("/api", async (req, res) => {
  try {
    const upstream = await fetch(BACKEND_URL + req.originalUrl, {
      method: req.method,
      headers: { "content-type": "application/json" },
      body: ["GET", "HEAD"].includes(req.method) ? undefined : JSON.stringify(req.body),
      signal: AbortSignal.timeout(5000),
    });
    res.status(upstream.status)
      .type(upstream.headers.get("content-type") || "application/json")
      .send(await upstream.text());
  } catch (err) {
    console.error(`backend unreachable: ${err.cause?.code || err.message}`);
    res.status(502).json({ error: "backend unreachable" });
  }
});

const server = app.listen(PORT, () => {
  console.log(`frontend listening on :${PORT}, backend = ${BACKEND_URL}`);
});

// "docker stop" salje SIGTERM
process.on("SIGTERM", () => server.close(() => process.exit(0)));