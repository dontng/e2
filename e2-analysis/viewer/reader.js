(() => {
  "use strict";
  const paper = window.E2_PAPER;
  const notes = window.E2_NOTES || [];
  const text1 = window.E2_SEMANTIC_PAGES || {};
  const full = window.E2_FULL_PAGES || {};
  const spread = document.getElementById("spread");
  if (!paper?.spreads?.length || !text1[3] || !full[5]) {
    spread.textContent = "原题未能装入，请从完整的 e2 仓库打开。";
    return;
  }

  let spreadIndex = 0;
  let selected = null;
  let currentNotes = [];
  const openNotes = new Set();
  const buttons = [...document.querySelectorAll("[data-mode]")];

  function mode(value) {
    document.body.classList.toggle("review-mode", value === "review");
    buttons.forEach(button => button.setAttribute("aria-pressed", String(button.dataset.mode === value)));
    try { localStorage.setItem("e2-reading-mode", value); } catch (_) {}
  }

  function note(data) {
    const details = document.createElement("details");
    details.className = "analysis-note";
    details.dataset.noteId = data.id;
    details.open = openNotes.has(data.id);
    const summary = document.createElement("summary");
    const kicker = document.createElement("span");
    kicker.className = "note-kicker";
    kicker.textContent = data.label;
    const title = document.createElement("span");
    title.className = "note-title";
    title.textContent = data.title;
    summary.append(kicker, title);
    summary.title = data.title;
    summary.setAttribute("aria-label", data.label + "：" + data.title);
    const content = document.createElement("div");
    content.className = "analysis-content";
    content.innerHTML = data.content;
    details.append(summary, content);
    details.addEventListener("toggle", () => {
      if (details.open) openNotes.add(data.id);
      else openNotes.delete(data.id);
    });
    summary.addEventListener("focus", () => { selected = details; });
    summary.addEventListener("click", () => {
      selected = details;
      summary.focus({ preventScroll: true });
    });
    currentNotes.push(details);
    return details;
  }

  function renderPage(index) {
    const page = paper.pages[index];
    const data = text1[page.printed];
    const other = full[page.index];
    const article = document.createElement("article");
    article.className = "paper " + (data ? data.className + " legacy-text1" : other?.[0] || "");
    article.setAttribute("aria-label", page.printed ? "原卷第 " + page.printed + " 页" : "原卷封面");
    article.innerHTML = data ? data.html : other?.[1] || "";
    if (data) {
      article.querySelectorAll(".note-slot").forEach(slot => {
        const entry = notes.find(item => item.id === slot.dataset.noteId);
        if (entry) slot.replaceWith(note(entry));
      });
    }
    return article;
  }

  function readHash() {
    const match = location.hash.match(/^#spread=(\d+)/);
    return match ? Math.min(paper.spreads.length - 1, Number(match[1])) : 0;
  }

  function render() {
    const group = paper.spreads[spreadIndex];
    spread.classList.toggle("cover", group.pages.length === 1);
    currentNotes = [];
    selected = null;
    spread.replaceChildren(...group.pages.map(renderPage));
    currentNotes.sort((a, b) => {
      if (a.dataset.noteId === "stem-preview") return -1;
      if (b.dataset.noteId === "stem-preview") return 1;
      return 0;
    });
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

  buttons.forEach(button => button.addEventListener("click", () => mode(button.dataset.mode)));
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
    if (!document.body.classList.contains("review-mode") || !currentNotes.length) return;
    const summary = event.target.closest("summary");
    if (event.key === "Enter" && summary?.parentElement?.classList.contains("analysis-note")) {
      event.preventDefault();
      summary.parentElement.open = !summary.parentElement.open;
      return;
    }
    if (event.key === "Escape" && selected?.open) {
      selected.open = false;
      selected.querySelector("summary").focus({ preventScroll: true });
      return;
    }
    const key = event.key.toLowerCase();
    if (key !== "x" && key !== "c") return;
    event.preventDefault();
    const direction = key === "c" ? 1 : -1;
    const at = currentNotes.indexOf(selected);
    const next = at < 0 ? currentNotes[direction === 1 ? 0 : currentNotes.length - 1]
      : currentNotes[Math.max(0, Math.min(currentNotes.length - 1, at + direction))];
    next.querySelector("summary").focus({ preventScroll: true });
    next.scrollIntoView({ block: "center", behavior: "smooth" });
  });

  window.addEventListener("hashchange", () => { spreadIndex = readHash(); render(); });
  spreadIndex = readHash();
  const deepLink = new URLSearchParams(location.search).get("review") === "text1";
  if (deepLink) openNotes.add("stem-preview");
  render();
  let saved = "exam";
  try { saved = localStorage.getItem("e2-reading-mode") || "exam"; } catch (_) {}
  mode(deepLink || saved === "review" ? "review" : "exam");
  if (deepLink) history.replaceState(null, "", location.pathname + "#spread=" + spreadIndex);
})();
