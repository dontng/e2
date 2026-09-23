(() => {
  "use strict";
  const paper = window.E2_PAPER;
  const full = window.E2_FULL_PAGES || {};
  const spread = document.getElementById("spread");
  // These two nodes are the unmodified passage and question pages from the
  // hand-set Text 1 HTML. Keep the nodes themselves, not a reconstruction.
  const text1 = [...spread.children];
  const notes = [
    text1[1]?.querySelector("#stem-preview"),
    ...(text1[0]?.querySelectorAll(".analysis-note") || []),
    ...(text1[1]?.querySelectorAll(".question .analysis-note") || []),
  ].filter(Boolean);
  if (!paper?.spreads?.length || text1.length !== 2 || !full[5]) {
    spread.textContent = "原卷未能装入，请从完整的 e2 仓库打开。";
    return;
  }
  const buttons = [...document.querySelectorAll("[data-mode]")];
  let spreadIndex = 0;
  let selected = null;
  let modeValue = "exam";

  function setMode(value) {
    modeValue = value === "review" ? "review" : "exam";
    document.body.classList.toggle("review-mode", modeValue === "review");
    buttons.forEach(button =>
      button.setAttribute("aria-pressed", String(button.dataset.mode === modeValue))
    );
    try { localStorage.setItem("e2-reading-mode", modeValue); } catch (_) {}
  }

  notes.forEach(note => {
    const summary = note.querySelector("summary");
    summary.addEventListener("focus", () => { selected = note; });
    summary.addEventListener("click", () => {
      selected = note;
      summary.focus({ preventScroll: true });
    });
  });

  function renderPage(index) {
    const page = paper.pages[index];
    if (index === 3 || index === 4) return text1[index - 3];
    const data = full[index];
    const node = document.createElement("article");
    node.className = "paper " + (data?.[0] || "");
    node.setAttribute("aria-label", index ? "原卷第 " + index + " 页" : "原卷封面");
    node.innerHTML = data?.[1] || "";
    return node;
  }

  function hashSpread() {
    const match = location.hash.match(/^#spread=(\d+)/);
    return match ? Math.min(paper.spreads.length - 1, Number(match[1])) : 0;
  }

  function render() {
    const group = paper.spreads[spreadIndex];
    spread.classList.toggle("cover", group.pages.length === 1);
    spread.replaceChildren(...group.pages.map(renderPage));
    document.getElementById("spreadLabel").textContent = group.label;
    document.getElementById("prevPage").disabled = spreadIndex === 0;
    document.getElementById("nextPage").disabled = spreadIndex === paper.spreads.length - 1;
  }

  function go(index) {
    spreadIndex = Math.max(0, Math.min(paper.spreads.length - 1, index));
    history.replaceState(null, "", "#spread=" + spreadIndex);
    render();
    window.scrollTo({ top: 0, left: 0, behavior: "auto" });
  }

  buttons.forEach(button => button.addEventListener("click", () => setMode(button.dataset.mode)));
  document.getElementById("prevPage").addEventListener("click", () => go(spreadIndex - 1));
  document.getElementById("nextPage").addEventListener("click", () => go(spreadIndex + 1));
  document.addEventListener("keydown", event => {
    if (event.isComposing || event.ctrlKey || event.altKey || event.metaKey) return;
    if (event.target.closest("input, textarea, select, [contenteditable]")) return;
    if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
      event.preventDefault();
      go(spreadIndex + (event.key === "ArrowRight" ? 1 : -1));
      return;
    }
    if (modeValue !== "review" || spreadIndex !== 2) return;
    const summary = event.target.closest("summary");
    if (event.key === "Enter" && summary?.parentElement?.matches(".analysis-note")) {
      event.preventDefault();
      summary.parentElement.open = !summary.parentElement.open;
      selected = summary.parentElement;
      return;
    }
    if (event.key === "Escape") {
      if (!selected?.open) return;
      selected.open = false;
      selected.querySelector("summary").focus({ preventScroll: true });
      return;
    }
    const key = event.key.toLowerCase();
    if (key !== "x" && key !== "c") return;
    event.preventDefault();
    const direction = key === "c" ? 1 : -1;
    const index = notes.indexOf(selected);
    const next = index < 0 ? notes[direction === 1 ? 0 : notes.length - 1]
      : notes[Math.max(0, Math.min(notes.length - 1, index + direction))];
    next.querySelector("summary").focus({ preventScroll: true });
    next.scrollIntoView({ block: "center", behavior: "smooth" });
  });

  window.addEventListener("hashchange", () => {
    spreadIndex = hashSpread();
    render();
  });
  spreadIndex = hashSpread();
  const directReview = new URLSearchParams(location.search).get("review") === "text1";
  if (directReview) notes[0].open = true;
  render();
  let saved = "exam";
  try { saved = localStorage.getItem("e2-reading-mode") || "exam"; } catch (_) {}
  setMode(directReview ? "review" : saved);
  if (directReview) history.replaceState(null, "", location.pathname + "#spread=" + spreadIndex);
})();
