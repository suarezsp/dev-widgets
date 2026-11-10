// Phase 4 mockups: GitHub row, action buttons, confirmation,
// alerts and Settings. Mirrors macOS/Shared/GitHubPresentation
// .swift, WidgetActionStyle.swift, Widgets/Views/
// WidgetActionButton.swift and App/Views/SettingsView.swift.
Object.assign(ICONS, {
  seal: '<path d="M12 2.5l2.4 1.8 3-.2.9 2.9 2.5 1.7-1 2.8 1 2.8' +
    '-2.5 1.7-.9 2.9-3-.2L12 21.5l-2.4-1.8-3 .2-.9-2.9-2.5-1.7' +
    ' 1-2.8-1-2.8 2.5-1.7.9-2.9 3 .2z"/><path d="M8.5 12l2.3 2.3' +
    ' 4.7-4.6"/>',
  stop: '<circle cx="12" cy="12" r="9"/><rect x="8.6" y="8.6"' +
    ' width="6.8" height="6.8" rx="1"/>',
  quit: '<circle cx="12" cy="12" r="9"/><path d="M9 9l6 6M15 9' +
    'l-6 6"/>',
  open: '<rect x="3" y="7" width="14" height="14" rx="3"/>' +
    '<path d="M11 13l9-9M14 4h6v6"/>',
  gear: '<circle cx="12" cy="12" r="3.2"/><path d="M12 2.5v3M12' +
    ' 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1' +
    ' 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1"/>',
  bell: '<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/>' +
    '<path d="M10 20a2 2 0 0 0 4 0"/>',
});

function actionButton(icon_Kind, is_Armed) {
  if (is_Armed) return `<span class="confirm">Confirm</span>`;
  return `<span class="action">` +
    `${iconSvg(icon_Kind, "var(--secondary)")}</span>`;
}

function describeRuns(runs) {
  const failed_Run = runs.find((run) => run.outcome === "failure");
  if (failed_Run) return `CI failing: ${failed_Run.workflow_Name}`;
  const running_Run = runs.find((run) => run.outcome === "pending");
  if (running_Run) return `CI running: ${running_Run.workflow_Name}`;
  const cancelled_Run = runs.find(
    (run) => run.outcome === "cancelled");
  if (cancelled_Run) {
    return `CI cancelled: ${cancelled_Run.workflow_Name}`;
  }
  return runs.length ? `CI passing (${runs.length})` : "No CI runs";
}

const REVIEW_NAMES = { approved: "Approved",
  changes_Requested: "Changes requested", none: "Awaiting review" };

function describePullRequest(pull_Request) {
  if (!pull_Request) return "No pull request";
  const state_Text = pull_Request.is_Draft ? "Draft"
    : REVIEW_NAMES[pull_Request.review];
  return `PR #${pull_Request.number} · ${state_Text}`;
}

function describeGitHub(github) {
  if (!github.available) {
    return { title: "GitHub", level: "normal",
      detail_Text: "Run gh auth login or add a token" };
  }
  const status = github.available.status;
  const outcomes = status.runs.map((run) => run.outcome);
  const review = status.pull_Request && status.pull_Request.review;
  const level = outcomes.includes("failure") ? "critical"
    : review === "changes_Requested" || outcomes.includes("pending")
      ? "elevated" : "normal";
  return { title: describePullRequest(status.pull_Request), level,
    detail_Text: describeRuns(status.runs) };
}

function projectRows(context) {
  return `<div class="git-line">` +
    contextRow("branch", describeGit(context.git)) +
    actionButton("open", false) + `</div>` +
    contextRow("seal", describeGitHub(context.github));
}

function notificationBanner(title, body_Text) {
  return `<div class="notification"><div class="app-icon">` +
    `${iconSvg("cpu", "#fff")}</div><div class="note-body">` +
    `<div class="note-head"><b>DevWidgets</b><span>now</span></div>` +
    `<div class="note-title">${title}</div>` +
    `<div class="note-text">${body_Text}</div></div></div>`;
}

const ALERT_ROWS = [
  ["CPU", true, 0.9, "90%"], ["Memory", true, 0.9, "90%"],
  ["Disk space", true, 0.9, "90%"],
  ["Temperature", true, 0.7, "95 °C"],
  ["Battery", false, 0.11, "10%"],
];

function alertRuleRow([name, is_Enabled, position, value_Text]) {
  return `<div class="form-row"><span class="toggle` +
    `${is_Enabled ? " on" : ""}"></span><span class="form-label">` +
    `${name}</span><span class="slider"><span style="left:` +
    `${position * 100}%"></span></span><span class="form-value">` +
    `${value_Text}</span></div>`;
}

function settingsWindow(selected_Tab, content_Html) {
  const tabs_Html = [["bell", "Alerts"], ["seal", "GitHub"],
    ["server", "Servers"], ["open", "Project"]]
    .map(([icon_Kind, name]) =>
    `<div class="tab${name === selected_Tab ? " selected" : ""}">` +
    `${iconSvg(icon_Kind, "var(--primary)")}${name}</div>`).join("");
  return `<div class="settings widget"><div class="traffic">` +
    `<i></i><i></i><i></i><span>${selected_Tab}</span></div>` +
    `<div class="tabs">${tabs_Html}</div>${content_Html}</div>`;
}

function alertSettings() {
  return `<div class="form-title">Notify me when</div>` +
    `<div class="form-group">` +
    ALERT_ROWS.map(alertRuleRow).join("") + `</div>` +
    `<div class="form-title">Avoid noise</div>` +
    `<div class="form-group">` +
    `<div class="form-row"><span class="form-label">Only after 30 s` +
    ` past the limit</span><span class="stepper">− +</span></div>` +
    `<div class="form-row"><span class="form-label">At most once` +
    ` every 15 min</span><span class="stepper">− +</span>` +
    `</div></div><div class="form-title">GitHub</div>` +
    `<div class="form-group"><div class="form-row"><span` +
    ` class="toggle on"></span><span class="form-label">When the` +
    ` project's branch CI fails</span></div></div>`;
}

function renderAlerts() {
  document.body.className = "dark wide";
  document.body.innerHTML =
    `<div class="banner"><span>MAQUETA HTML/CSS · no es una captura` +
    ` real</span><span>Alertas por umbral: avisos y ajustes ·` +
    ` valores de ejemplo</span></div><div class="desk split">` +
    `<div class="note-stack">` +
    notificationBanner("CPU at 97%",
      "Over your 90% limit for at least 30 s.") +
    notificationBanner("Battery at 9%",
      "Under your 10% limit for at least 30 s.") +
    `<div class="caption-note">Un aviso por métrica: el nuevo ` +
    `sustituye al anterior. Solo tras 30 s seguidos pasado el ` +
    `límite, y otra vez solo si el valor vuelve 5 puntos y pasan ` +
    `15 min.</div></div>` +
    settingsWindow("Alerts", alertSettings()) + `</div>`;
}

function githubSettings(context) {
  return `<div class="form-group"><div class="form-note">` +
    `CI and pull` +
    ` request of the project's branch, and pull requests awaiting` +
    ` your review. DevWidgets uses the token` +
    ` below if you save one, otherwise the gh command (run gh auth` +
    ` login once).</div></div><div class="form-title">Personal` +
    ` access token</div><div class="form-group"><div class="field">` +
    `github_pat_…</div><div class="form-row"><span class="button">` +
    `Save to Keychain</span><span class="form-value wide">No token` +
    `</span></div><div class="form-note hint">Read-only is enough:` +
    ` a fine-grained token with Actions and Pull requests set to` +
    ` Read. Reviews only list repositories the token can read.` +
    `</div></div><div class="form-title">Now</div>` +
    `<div class="form-group">` +
    contextRow("seal", describeGitHub(context.github)) + `</div>`;
}

function renderGitHubSettings(context) {
  document.body.className = "light";
  document.body.innerHTML =
    `<div class="banner"><span>MAQUETA HTML/CSS · no es una captura` +
    ` real</span><span>Ajustes · GitHub · estado real de un ` +
    `repositorio público</span></div><div class="desk">` +
    settingsWindow("GitHub", githubSettings(context)) + `</div>`;
}

function confirmationDialog(container) {
  return `<div class="dialog widget"><div class="dialog-title">` +
    `Stop ${container.identity.name}?</div>` +
    `<div class="dialog-text">` +
    `Docker asks it to stop and forces it after 10 seconds.</div>` +
    `<div class="dialog-buttons"><span class="button">Cancel</span>` +
    `<span class="button destructive">Stop ` +
    `${container.identity.name}</span></div></div>`;
}

function renderActions(context) {
  document.body.className = "dark wide";
  const example_Context = withExampleDocker(context);
  const first_Name = runningContainers(example_Context.docker)
    .sort((left, right) => right.cpu_Fraction - left.cpu_Fraction)[0];
  document.body.innerHTML =
    `<div class="banner"><span>MAQUETA HTML/CSS · no es una captura` +
    ` real</span><span>Confirmación de acciones · Docker: valores ` +
    `de ejemplo</span></div><div class="desk">` +
    `<div class="caption">1 · Widget: primer toque en el botón ` +
    `de parar del contenedor</div>` +
    mediumContext(example_Context, null) +
    `<div class="caption">2 · El botón pasa a «Confirm» ` +
    `durante 8 s;` +
    ` el segundo toque lo para</div>` +
    mediumContext(example_Context, first_Name.identity.name) +
    `<div class="caption">3 · En el panel de la barra de menús sí` +
    ` hay diálogo de confirmación</div>` +
    confirmationDialog(first_Name) + `</div>`;
}
