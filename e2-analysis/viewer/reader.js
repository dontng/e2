(() => {
  "use strict";

  const paper = window.E2_PAPER;
  const notes = window.E2_NOTES || [];
  const $ = (id) => document.getElementById(id);
  if (!paper?.pages?.length || !paper?.spreads?.length) {
    $("spread").textContent = "试卷数据未能加载。请从完整的仓库目录打开本页。";
    return;
  }

  const storageKey = `e2-paper-${paper.year}-attempt-v1`;
  const emptyAttempt = () => ({
    answers: {}, first: {}, changed: {}, unsure: {}, late: {}, review: {}, writing: {},
    timer: { elapsed: 0, startedAt: null }, mode: "exam", createdAt: new Date().toISOString(),
  });
  let attempt = emptyAttempt();
  let historyRecords = [];
  try {
    const saved = JSON.parse(localStorage.getItem(storageKey));
    historyRecords = JSON.parse(localStorage.getItem(`${storageKey}-history`)) || [];
    if (saved?.answers && saved?.first) {
      attempt = { ...attempt, ...saved, timer: { ...attempt.timer, ...saved.timer } };
    }
  } catch (_) { /* In private mode the attempt stays in memory. */ }

  let spreadIndex = 0;
  let selectedQuestion = 1;
  let selectedNote = null;
  const openedNotes = new Set();
  let currentNotes = [];
  const save = () => { try { localStorage.setItem(storageKey, JSON.stringify(attempt)); } catch (_) {} };

  function elapsedMs() {
    return attempt.timer.elapsed + (attempt.timer.startedAt ? Date.now() - attempt.timer.startedAt : 0);
  }

  function updateClock() {
    const minutes = Math.floor(elapsedMs() / 60000);
    const seconds = Math.floor(elapsedMs() / 1000) % 60;
    $("clock").textContent = `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
    $("clockToggle").textContent = attempt.timer.startedAt ? "暂停计时" : (elapsedMs() ? "继续计时" : "开始计时");
  }

  function pauseClock() {
    if (!attempt.timer.startedAt) return;
    attempt.timer.elapsed = elapsedMs();
    attempt.timer.startedAt = null;
    save();
    updateClock();
  }

  function setMode(mode, { submit = false } = {}) {
    const reviewing = mode === "review";
    if (reviewing) pauseClock();
    if (reviewing && !attempt.seenAnalysisAt) attempt.seenAnalysisAt = new Date().toISOString();
    if (submit && !attempt.submittedAt) attempt.submittedAt = new Date().toISOString();
    attempt.mode = reviewing ? "review" : "exam";
    document.body.classList.toggle("review-mode", reviewing);
    $("noteHint").hidden = !(reviewing && currentNotes.length);
    $("modeToggle").textContent = reviewing ? "回到原卷" : "交卷复盘";
    $("modeToggle").setAttribute("aria-pressed", String(reviewing));
    updateGuide();
    renderQuestionEditor();
    save();
  }

  function renderNote(data, semantic = false) {
    const details = document.createElement("details");
    details.className = semantic ? "note analysis-note" : "note";
    details.dataset.noteId = data.id;
    details.open = openedNotes.has(data.id);
    const summary = document.createElement("summary");
    if (semantic) {
      const kicker = document.createElement("span");
      kicker.className = "note-kicker";
      kicker.textContent = data.label;
      const caption = document.createElement("span");
      caption.className = "note-title";
      caption.textContent = data.title;
      summary.append(kicker, caption);
    } else summary.textContent = data.label;
    summary.title = data.title;
    summary.setAttribute("aria-label", `${data.label}：${data.title}`);
    summary.addEventListener("focus", () => { selectedNote = details; });
    summary.addEventListener("click", () => {
      selectedNote = details;
      summary.focus({ preventScroll: true });
    });
    details.addEventListener("toggle", () => {
      if (details.open) openedNotes.add(data.id);
      else openedNotes.delete(data.id);
    });

    const content = document.createElement("div");
    content.className = semantic ? "analysis-content" : "note-content";
    const title = document.createElement("h3");
    title.textContent = data.title;
    if (!semantic) content.append(title);
    const body = document.createElement("div");
    body.innerHTML = data.content; // The checked-in, local review notes are trusted content.
    content.append(body);
    details.append(summary, content);
    currentNotes.push(details);
    return details;
  }

  function renderSheet(pageIndex) {
    const page = paper.pages[pageIndex];
    const sheet = document.createElement("article");
    sheet.className = "sheet";
    sheet.dataset.printed = page.printed || "cover";
    sheet.setAttribute("aria-label", page.printed ? `原卷第 ${page.printed} 页` : "原卷封面");
    const anchors = notes.filter((note) => note.page === page.printed).sort((a, b) => a.at - b.at);
    sheet.dataset.annotated = String(anchors.length > 0);
    const semanticPage = window.E2_SEMANTIC_PAGES?.[page.printed];
    if (semanticPage) {
      sheet.classList.add("paper", semanticPage.className);
      sheet.innerHTML = semanticPage.html;
      sheet.querySelectorAll(".note-slot").forEach((slot) => {
        const data = anchors.find((note) => note.id === slot.dataset.noteId);
        if (data) slot.replaceWith(renderNote(data, true));
      });
      return sheet;
    }
    const textPage = window.E2_TEXT_PAGES?.[page.index];
    if (textPage) {
      sheet.classList.add("paper", "native-page");
      sheet.innerHTML = textPage;
      return sheet;
    }
    // The last source page is a scan containing the chart. Its OCR layer is selectable.
    const scan = document.createElement("img");
    scan.className = "full-page";
    scan.src = page.image;
    scan.alt = `${paper.year} 英语（二）第 ${page.printed} 页扫描图表`;
    sheet.append(scan);
    if (window.E2_SCAN_TEXT) {
      const layer = document.createElement("div");
      layer.className = "scan-layer";
      layer.innerHTML = window.E2_SCAN_TEXT;
      sheet.append(layer);
    }
    return sheet;
  }

  function updateGuide() {
    const guide = paper.spreads[spreadIndex];
    $("guideTitle").textContent = guide.title;
    $("guideExam").textContent = guide.exam;
    $("guideReview").textContent = guide.review;
  }

  function renderSpread() {
    const spread = paper.spreads[spreadIndex];
    const main = $("spread");
    main.replaceChildren();
    main.classList.toggle("cover", spread.pages.length === 1);
    currentNotes = [];
    selectedNote = null;
    spread.pages.forEach((index) => main.append(renderSheet(index)));
    currentNotes.sort((a, b) => {
      if (a.dataset.noteId === "stem-preview") return -1;
      if (b.dataset.noteId === "stem-preview") return 1;
      return 0;
    });
    $("noteHint").hidden = !(attempt.mode === "review" && currentNotes.length);
    $("spreadLabel").textContent = spread.label;
    $("prevPage").disabled = spreadIndex === 0;
    $("nextPage").disabled = spreadIndex === paper.spreads.length - 1;
    updateGuide();
  }

  function hashSpread() {
    const match = location.hash.match(/^#spread=(\d+)$/);
    return match ? Math.min(paper.spreads.length - 1, Number(match[1])) : 0;
  }

  function goToSpread(index) {
    const next = Math.max(0, Math.min(paper.spreads.length - 1, index));
    if (spreadIndex === next && $("spread").firstElementChild?.classList.contains("sheet")) return;
    spreadIndex = next;
    try { history.replaceState(null, "", `#spread=${next}`); }
    catch (_) { location.hash = `spread=${next}`; }
    renderSpread();
    window.scrollTo({ top: 0, left: 0, behavior: "auto" });
  }

  function spreadForQuestion(number) {
    return paper.questionSpreads?.find((range) => number >= range.from && number <= range.to)?.spread ?? spreadIndex;
  }

  function updateProgress() {
    const answered = Object.keys(attempt.first).length;
    const reviewed = Object.values(attempt.review).filter((r) => r.outcome && r.evidence && r.next).length;
    $("progress").textContent = `首次答案 ${answered}/45 · 完整复盘 ${reviewed}`;
  }

  function renderQuestionGrid() {
    const grid = $("questionGrid");
    grid.replaceChildren();
    for (let q = 1; q <= 45; q++) {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = String(q);
      button.title = `第 ${q} 题${attempt.first[q] ? `，首次选 ${attempt.first[q].choice}` : attempt.late[q] ? "，复盘后补录" : "，尚未作答"}`;
      if (attempt.answers[q]) button.classList.add("answered");
      if (attempt.unsure[q]) button.classList.add("unsure");
      if (selectedQuestion === q) button.classList.add("current");
      button.addEventListener("click", () => {
        selectedQuestion = q;
        goToSpread(spreadForQuestion(q));
        renderQuestionGrid();
        renderQuestionEditor();
      });
      grid.append(button);
    }
    updateProgress();
  }

  function renderQuestionEditor() {
    const root = $("questionEditor");
    root.replaceChildren();
    const q = selectedQuestion;
    const heading = document.createElement("h3");
    heading.textContent = `第 ${q} 题 · ${q <= 20 ? "完形" : q <= 40 ? "阅读 Part A" : "阅读 Part B"}`;
    root.append(heading);

    const row = document.createElement("div");
    row.className = "choice-row";
    for (const choice of (q >= 41 ? "ABCDEFG" : "ABCD")) {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = choice;
      button.setAttribute("aria-pressed", String(attempt.answers[q] === choice));
      button.addEventListener("click", () => {
        if (!attempt.first[q]) {
          if (attempt.submittedAt || attempt.seenAnalysisAt) attempt.late[q] = true;
          else attempt.first[q] = { choice, elapsedMs: elapsedMs() };
        }
        if (attempt.answers[q] && attempt.answers[q] !== choice) attempt.changed[q] = (attempt.changed[q] || 0) + 1;
        attempt.answers[q] = choice;
        save();
        renderQuestionGrid();
        renderQuestionEditor();
      });
      row.append(button);
    }
    root.append(row);

    const first = document.createElement("p");
    first.className = "first-answer";
    first.textContent = attempt.first[q]
      ? `首次选 ${attempt.first[q].choice} · 当前选 ${attempt.answers[q]}${attempt.changed[q] ? ` · 改过 ${attempt.changed[q]} 次` : ""}`
      : attempt.late[q] ? `看过解析后补选 ${attempt.answers[q]}，不计入首次答案。` : "选项记录第一次判断；以后修改仍会保留首次选择。";
    root.append(first);

    const uncertain = document.createElement("button");
    uncertain.type = "button";
    uncertain.textContent = attempt.unsure[q] ? "取消犹豫标记" : "标记犹豫 / 猜测";
    uncertain.addEventListener("click", () => {
      attempt.unsure[q] = !attempt.unsure[q];
      save(); renderQuestionGrid(); renderQuestionEditor();
    });
    root.append(uncertain);

    if (attempt.mode !== "review") return;
    const record = attempt.review[q] || {};
    const fields = document.createElement("div");
    fields.className = "review-fields";
    const title = document.createElement("h3");
    title.textContent = "核对后只留下有用的证据";
    fields.append(title);

    const outcome = document.createElement("select");
    [["", "核对结果"], ["right", "正确"], ["wrong", "错误"], ["pending", "暂未核对"]].forEach(([value, label]) => {
      const option = document.createElement("option");
      option.value = value; option.textContent = label; outcome.append(option);
    });
    outcome.value = record.outcome || "";
    fields.append(outcome);
    outcome.addEventListener("change", () => updateReview("outcome", outcome.value));

    for (const [name, caption, placeholder] of [
      ["evidence", "英文证据在哪里？", "原文位置或关键词；不要只写选项字母"],
      ["confusion", "当时为什么犹豫或选错？", "词义、关系、对象、范围、证据身份……"],
      ["next", "下次碰到同类题，先检查什么？", "留下一个可以在新材料中执行的动作"],
    ]) {
      const label = document.createElement("label");
      label.textContent = caption;
      const input = document.createElement("textarea");
      input.rows = 2;
      input.placeholder = placeholder;
      input.value = record[name] || "";
      input.addEventListener("input", () => updateReview(name, input.value));
      label.append(input); fields.append(label);
    }
    root.append(fields);

    function updateReview(name, value) {
      attempt.review[q] ||= {};
      attempt.review[q][name] = value;
      save(); updateProgress();
    }
  }

  function toggleDrawer(show) {
    $("recordDrawer").hidden = !show;
    $("drawerBackdrop").hidden = !show;
    $("recordToggle").setAttribute("aria-expanded", String(show));
    document.body.classList.toggle("drawer-open", show);
    if (show) renderQuestionGrid();
  }

  function exportRecord() {
    const payload = { paper: `${paper.year} 英语（二）`, source: paper.source, spread: spreadIndex, exportedAt: new Date().toISOString(), attempt, history: historyRecords };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `e2-${paper.year}-attempt-${new Date().toISOString().slice(0, 10)}.json`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  $("sourcePdf").href = paper.source;
  $("prevPage").addEventListener("click", () => goToSpread(spreadIndex - 1));
  $("nextPage").addEventListener("click", () => goToSpread(spreadIndex + 1));
  $("clockToggle").addEventListener("click", () => {
    if (attempt.timer.startedAt) pauseClock();
    else { attempt.timer.startedAt = Date.now(); save(); updateClock(); }
  });
  $("modeToggle").addEventListener("click", () => setMode(attempt.mode === "exam" ? "review" : "exam", { submit: attempt.mode === "exam" }));
  $("guideToggle").addEventListener("click", () => {
    $("guidePanel").hidden = !$("guidePanel").hidden;
    $("guideToggle").setAttribute("aria-expanded", String(!$("guidePanel").hidden));
  });
  $("recordToggle").addEventListener("click", () => toggleDrawer($("recordDrawer").hidden));
  $("drawerClose").addEventListener("click", () => toggleDrawer(false));
  $("drawerBackdrop").addEventListener("click", () => toggleDrawer(false));
  $("exportRecord").addEventListener("click", exportRecord);
  $("newAttempt").addEventListener("click", () => {
    pauseClock();
    historyRecords.push(attempt);
    try { localStorage.setItem(`${storageKey}-history`, JSON.stringify(historyRecords)); } catch (_) {}
    attempt = emptyAttempt();
    selectedQuestion = 1;
    document.querySelectorAll("[data-writing]").forEach((input) => { input.value = ""; });
    save();
    setMode("exam");
    goToSpread(0);
    renderQuestionGrid();
    renderQuestionEditor();
    updateClock();
  });
  document.querySelectorAll("[data-writing]").forEach((input) => {
    input.value = attempt.writing[input.dataset.writing] || "";
    input.addEventListener("input", () => { attempt.writing[input.dataset.writing] = input.value; save(); });
  });

  document.addEventListener("keydown", (event) => {
    if (event.isComposing || event.ctrlKey || event.altKey || event.metaKey) return;
    if (event.key === "Escape") {
      if (!$("recordDrawer").hidden) { toggleDrawer(false); return; }
      if (!$("guidePanel").hidden) { $("guidePanel").hidden = true; $("guideToggle").setAttribute("aria-expanded", "false"); return; }
      if (selectedNote?.open) { selectedNote.open = false; selectedNote.querySelector("summary").focus({ preventScroll: true }); }
      return;
    }
    if (event.target.closest("input, textarea, select, [contenteditable]")) return;
    const summary = event.target.closest("summary");
    if (event.key === "Enter" && summary?.parentElement?.classList.contains("note")) {
      event.preventDefault();
      summary.parentElement.open = !summary.parentElement.open;
      return;
    }
    if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
      event.preventDefault();
      goToSpread(spreadIndex + (event.key === "ArrowRight" ? 1 : -1));
      return;
    }
    if (!document.body.classList.contains("review-mode") || !currentNotes.length || !$("recordDrawer").hidden) return;
    const key = event.key.toLowerCase();
    if (key !== "x" && key !== "c") return;
    event.preventDefault();
    const direction = key === "c" ? 1 : -1;
    const index = currentNotes.indexOf(selectedNote);
    const next = index === -1
      ? currentNotes[direction === 1 ? 0 : currentNotes.length - 1]
      : currentNotes[Math.max(0, Math.min(currentNotes.length - 1, index + direction))];
    next.querySelector("summary").focus({ preventScroll: true });
    next.scrollIntoView({ block: "center", behavior: "smooth" });
  });

  window.addEventListener("hashchange", () => {
    spreadIndex = hashSpread();
    renderSpread();
  });
  spreadIndex = hashSpread();
  const text1DeepLink = new URLSearchParams(location.search).get("review") === "text1";
  if (text1DeepLink) openedNotes.add("stem-preview");
  renderSpread();
  setMode(text1DeepLink ? "review" : attempt.mode);
  if (text1DeepLink) history.replaceState(null, "", `${location.pathname}#spread=${spreadIndex}`);
  renderQuestionGrid();
  updateClock();
  setInterval(updateClock, 1000);
})();
