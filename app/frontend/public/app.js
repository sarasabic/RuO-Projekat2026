const ROUNDS = 5;
const $ = (id) => document.getElementById(id);
let state = null;

async function api(path, options = {}) {
  const res = await fetch(`/api${path}`, { headers: { "content-type": "application/json" }, ...options });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}

function show(section) {
  for (const id of ["start", "game", "over"]) $(id).hidden = id !== section;
}

async function startGame(event) {
  event.preventDefault();
  state = { player: $("player").value.trim(), round: 0, score: 0, seen: [] };
  show("game");
  await nextPuzzle();
}

async function nextPuzzle() {
  if (state.round === ROUNDS) return finishGame();
  state.round += 1;
  state.puzzle = await api(`/puzzle?exclude=${state.seen.join(",")}`);
  state.seen.push(state.puzzle.id);
  $("round").textContent = `Round ${state.round}/${ROUNDS}`;
  $("score").textContent = `${state.score} points`;
  $("emojis").textContent = state.puzzle.emojis;
  $("year").textContent = `Year: ${state.puzzle.year}`;
  $("feedback").textContent = "";
  $("guess").value = "";
  $("guess-form").hidden = false;
  $("next").hidden = true;
  $("guess").focus();
}

async function submitGuess(event, skipped = false) {
  event.preventDefault();
  const guess = skipped ? "" : $("guess").value;
  const result = await api("/guess", { method: "POST", body: JSON.stringify({ id: state.puzzle.id, guess }) });
  state.score += result.points;
  $("score").textContent = `${state.score} points`;
  $("feedback").textContent = result.correct
    ? `✅ Correct! It was "${result.title}" (+${result.points})`
    : `❌ It was "${result.title}"`;
  $("feedback").className = result.correct ? "good" : "bad";
  $("guess-form").hidden = true;
  $("next").textContent = state.round === ROUNDS ? "Finish 🏁" : "Next ➜";
  $("next").hidden = false;
  $("next").focus();
}

async function finishGame() {
  await api("/scores", { method: "POST", body: JSON.stringify({ player: state.player, points: state.score }) });
  $("final").textContent = `${state.player}, you scored ${state.score} points!`;
  show("over");
  await loadLeaderboard();
}

async function loadLeaderboard() {
  const rows = await api("/scores");
  const body = $("leaderboard");
  body.replaceChildren(...rows.map((row, i) => {
    const tr = document.createElement("tr");
    for (const value of [i + 1, row.player, row.points]) {
      const td = document.createElement("td");
      td.textContent = value;   // textContent, not innerHTML: a player name cannot inject HTML
      tr.append(td);
    }
    return tr;
  }));
  if (rows.length === 0) body.innerHTML = '<tr><td colspan="3">No scores yet. Be the first!</td></tr>';
}

async function loadInfo() {
  try {
    const info = await api("/info");
    $("info").textContent = `browser → frontend → backend (${info.backend}) → ${info.database} at ${info.db_host}`;
  } catch (err) {
    $("info").textContent = `backend or database not reachable: ${err.message}`;
  }
}

// Prikaz API errora
const safe = (fn) => (event) => fn(event).catch((err) => { $("feedback").textContent = `⚠️ ${err.message}`; });

$("start-form").addEventListener("submit", safe(startGame));
$("guess-form").addEventListener("submit", safe(submitGuess));
$("skip").addEventListener("click", safe((event) => submitGuess(event, true)));
$("next").addEventListener("click", safe(() => nextPuzzle()));
$("again").addEventListener("click", () => show("start"));

loadLeaderboard().catch(() => {});
loadInfo();