(() => {
  "use strict";
  const paper = window.E2_PAPER;
  const full = window.E2_FULL_PAGES || {};
  const spread = document.getElementById("spread");
  let statusTimer;
  function fullscreenError() {
    let status = document.getElementById("fullscreenStatus");
    if (!status) {
      status = document.createElement("div");
      status.id = "fullscreenStatus";
      status.setAttribute("role", "status");
      document.body.append(status);
    }
    status.textContent = "当前预览环境不允许网页全屏。请在 Chrome 标签页打开试卷后按 F，或使用 F11。";
    status.classList.add("visible");
    window.clearTimeout(statusTimer);
    statusTimer = window.setTimeout(() => status.classList.remove("visible"), 5000);
  }

  // Register before loading the paper: F remains usable even if a page asset fails.
  window.addEventListener("keydown", event => {
    if (event.key?.toLowerCase() !== "f" || event.repeat || event.isComposing ||
        event.ctrlKey || event.altKey || event.metaKey ||
        event.target?.closest?.("input, textarea, select, [contenteditable]")) return;
    event.preventDefault();
    try {
      const action = document.fullscreenElement
        ? document.exitFullscreen()
        : document.documentElement.requestFullscreen();
      Promise.resolve(action).catch(fullscreenError);
    } catch (_) { fullscreenError(); }
  }, true);
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
  let turning = false;

  function updateFullscreenLayout() {
    // F11 is a browser command, so it does not set document.fullscreenElement.
    const browserFullscreen = document.fullscreenElement ||
      window.matchMedia("(display-mode: fullscreen)").matches ||
      (window.innerHeight >= window.screen.availHeight - 24 &&
        window.outerHeight - window.innerHeight < 55);
    document.documentElement.classList.toggle("browser-fullscreen", Boolean(browserFullscreen));
    const pageWidth = 535.748 * 96 / 72;
    const pages = paper.spreads[spreadIndex].pages.length;
    const spreadWidth = pages * pageWidth + (pages === 2 ? 24 : 0) + 32;
    const fit = Math.min(1, (window.innerWidth - 16) / spreadWidth);
    document.documentElement.style.setProperty("--fullscreen-paper-zoom", String(fit));
  }

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
    updateFullscreenLayout();
  }

  function go(index) {
    const next = Math.max(0, Math.min(paper.spreads.length - 1, index));
    if (next === spreadIndex || turning) return;
    const direction = next > spreadIndex ? "next" : "prev";
    const commit = () => {
      spreadIndex = next;
      history.replaceState(null, "", "#spread=" + spreadIndex);
      render();
      window.scrollTo({ top: 0, left: 0, behavior: "auto" });
    };
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      commit();
      return;
    }
    if (!document.startViewTransition) {
      commit();
      spread.animate([
        { opacity: .45, transform: `translateX(${direction === "next" ? 30 : -30}px)` },
        { opacity: 1, transform: "translateX(0)" },
      ], { duration: 400, easing: "ease-out" });
      return;
    }
    turning = true;
    document.documentElement.dataset.turn = direction;
    const transition = document.startViewTransition(commit);
    transition.finished.catch(() => {}).finally(() => {
      turning = false;
      delete document.documentElement.dataset.turn;
    });
  }

  buttons.forEach(button => button.addEventListener("click", event => {
    setMode(button.dataset.mode);
    if (event.detail > 0) button.blur();
  }));
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
  window.addEventListener("resize", updateFullscreenLayout);
  document.addEventListener("fullscreenchange", updateFullscreenLayout);
  spreadIndex = hashSpread();
  const directReview = new URLSearchParams(location.search).get("review") === "text1";
  if (directReview) notes[0].open = true;
  render();
  let saved = "exam";
  try { saved = localStorage.getItem("e2-reading-mode") || "exam"; } catch (_) {}
  setMode(directReview ? "review" : saved);
  if (directReview) history.replaceState(null, "", location.pathname + "#spread=" + spreadIndex);
})();
