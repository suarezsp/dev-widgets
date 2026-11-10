// Phase 5 mockups: servers over SSH, the review queue, failed-CI
// notifications and restart buttons. Mirrors macOS/Shared/
// ServerPresentation.swift, ServerViews.swift,
// ReviewQueuePresentation.swift, Widgets/ServersWidget.swift and
// App/Views/ServersSettingsView.swift.
Object.assign(ICONS, {
  server: '<rect x="3" y="4" width="18" height="7" rx="2"/>' +
    '<rect x="3" y="13" width="18" height="7" rx="2"/>' +
    '<path d="M7 7.5h.01M7 16.5h.01"/>',
  restart: '<circle cx="12" cy="12" r="9"/><path d="M15.5 9.2A4.2' +
    ' 4.2 0 1 0 16.2 13"/><path d="M15.8 6.5v2.9h-2.9"/>',
  review: '<path d="M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5' +
    ' 6.5-9.5 6.5S2.5 12 2.5 12z"/><circle cx="12" cy="12"' +
    ' r="2.8"/>',
});
const MEDIUM_SERVER_COUNT = 2;
const LARGE_SERVER_COUNT = 6;
const REVIEW_COUNT = 2;
const LEVEL_ORDER = ["normal", "elevated", "critical"];
// Only devwidgets-test (a real sshd on the build box) and
// devwidgets-closed (a real refused port) come from the probe.
// These hosts are example values and every image says so.
const EXAMPLE_SERVERS = [
  { host: { alias: "web-1" }, example_Status: { cpu: 0.42,
    memory: 0.71, disk: 0.58, cores: 8, load: 3.1,
    uptime_Seconds: 1900800 } },
  { host: { alias: "db-1" }, state: { failed: { problem: {
    authentication_Failed: {} } } } },
  { host: { alias: "ci-runner" }, example_Status: { cpu: 0.93,
    memory: 0.64, disk: 0.91, cores: 16, load: 15.2,
    uptime_Seconds: 223200 } },
];

function fractionOf(usage) {
  return usage.total_Bytes ? usage.used_Bytes / usage.total_Bytes
    : null;
}

// Turns a probe report or an example host into plain numbers.
function measureServer(report) {
  if (report.example_Status) return report.example_Status;
  const status = report.state.available.status;
  const snapshot = status.snapshot;
  return { cpu: status.cpu_Fraction ?? null,
    memory: fractionOf(snapshot.memory.physical),
    disk: fractionOf(snapshot.disk_Space),
    cores: snapshot.cpu.cores.length,
    load: snapshot.load_Average.one_Minute,
    uptime_Seconds: snapshot.uptime_Seconds };
}

function describeUptime(seconds) {
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  return hours < 48 ? `${hours} h` : `${Math.floor(hours / 24)} d`;
}

const PROBLEM_TEXTS = {
  ssh_Missing: () => "ssh not found",
  host_Key_Rejected: () => "Unknown host key: connect once in" +
    " Terminal",
  authentication_Failed: () => "Key refused: is it in ssh-agent?",
  unreachable: (problem) => problem.reason,
  not_Linux: (problem) => `${problem.system} is not supported yet`,
};

function describeProblem(problem) {
  const [kind, detail] = Object.entries(problem)[0];
  return PROBLEM_TEXTS[kind](detail);
}

function describeServer(report) {
  const alias = report.host.alias;
  if (report.state && report.state.failed) {
    return { alias, level: "critical", gauges: [],
      detail_Text: describeProblem(report.state.failed.problem) };
  }
  const numbers = measureServer(report);
  const gauges = [["CPU", numbers.cpu],
    ["Memory", numbers.memory], ["Disk", numbers.disk]]
    .map(([title, fraction]) => ({ title, fraction,
      level: fraction === null ? "normal" : levelFor(fraction) }));
  const level = LEVEL_ORDER.filter((name) =>
    gauges.some((gauge) => gauge.level === name)).pop();
  return { alias, level, gauges, detail_Text:
    `${numbers.cores} cores · load ${numbers.load.toFixed(2)}` +
    ` · up ${describeUptime(numbers.uptime_Seconds)}` };
}

function serverGauge(gauge) {
  const color = LEVEL_COLORS[gauge.level];
  const value_Text = gauge.fraction === null ? UNAVAILABLE_TEXT
    : describePercent(gauge.fraction);
  const width = (gauge.fraction || 0) * 100;
  return `<div class="gauge"><div class="gauge-head"><span>` +
    `${gauge.title}</span><span>${value_Text}</span></div>` +
    `<div class="bar"><div style="width:${width}%;` +
    `background:${color}"></div></div></div>`;
}

function serverRow(report) {
  const line = describeServer(report);
  const gauges_Html = line.gauges.length
    ? `<div class="gauges">${line.gauges.map(serverGauge)
      .join("")}</div>` : "";
  return `<div class="server"><div class="server-head"><span` +
    ` class="dot" style="background:${LEVEL_COLORS[line.level]}">` +
    `</span><b>${line.alias}</b><span class="detail">` +
    `${line.detail_Text}</span></div>${gauges_Html}</div>`;
}

function serverReports(overview) {
  return overview.reports.slice(0, 1).concat(EXAMPLE_SERVERS)
    .concat(overview.reports.slice(1));
}

function serversWidget(overview, size, row_Limit) {
  // The widget shows local time; the box's user is in Madrid.
  const time_Text = new Date(overview.captured_At)
    .toLocaleTimeString("es-ES", { timeZone: "Europe/Madrid",
      hour: "2-digit", minute: "2-digit" });
  return `<div class="widget ${size} servers">` +
    `<div class="dash-head">` +
    `<div class="header">${iconSvg("server", "var(--primary)")}` +
    `Servers</div><span class="time">${time_Text}</span></div>` +
    serverReports(overview).slice(0, row_Limit).map(serverRow)
      .join("") + `</div>`;
}

function renderServers(overview, mode) {
  document.body.className = mode;
  document.body.innerHTML =
    `<div class="banner"><span>MAQUETA HTML/CSS · no es una ` +
    `captura real de macOS</span><span>Modo ${MODE_NAMES[mode]}` +
    ` · devwidgets-test y devwidgets-closed: SSH real · resto:` +
    ` ejemplo</span></div><div class="desk">` +
    `<div class="caption">Mediano (dos servidores)</div>` +
    serversWidget(overview, "medium", MEDIUM_SERVER_COUNT) +
    `<div class="caption">Grande (hasta seis; el peor indicador ` +
    `colorea el punto)</div>` +
    serversWidget(overview, "large", LARGE_SERVER_COUNT) + `</div>`;
}

function serverSettings(overview) {
  const rows_Html = serverReports(overview).map((report) =>
    `<div class="form-row">${serverRow(report)}<span class="button` +
    ` destructive">Remove</span></div>`).join("");
  return `<div class="form-group"><div class="form-note">` +
    `DevWidgets runs your own ssh with your ~/.ssh/config and keys.` +
    ` It never asks for or stores a password: hosts must log in` +
    ` with a key (ssh-agent) and be Linux.</div></div>` +
    `<div class="form-title">Hosts</div><div class="form-group">` +
    rows_Html + `<div class="form-row"><div class="field grow">` +
    `Host alias, as in ~/.ssh/config</div><span class="button">` +
    `Add</span></div><div class="form-note hint">From ` +
    `~/.ssh/config: devwidgets-test · devwidgets-closed</div>` +
    `</div>`;
}

function renderServerSettings(overview) {
  document.body.className = "light";
  document.body.innerHTML =
    `<div class="banner"><span>MAQUETA HTML/CSS · no es una captura` +
    ` real</span><span>Ajustes · Servers · devwidgets-test: SSH ` +
    `real · web-1, db-1, ci-runner: ejemplo</span></div>` +
    `<div class="desk">` +
    settingsWindow("Servers", serverSettings(overview)) + `</div>`;
}

function describeReviews(queue) {
  if (queue.total_Count === 0) {
    return { title: "Reviews", level: "normal",
      detail_Text: "Nothing awaits your review" };
  }
  const noun = queue.total_Count === 1 ? "request" : "requests";
  return { title: "Reviews", level: "elevated",
    detail_Text: `${queue.total_Count} ${noun} await you` };
}

function reviewList(queue, row_Limit) {
  const rows_Html = queue.requests.slice(0, row_Limit)
    .map((request) => `<div class="process indent review"><span` +
      ` class="name">${request.repository.name} #${request.number}` +
      `</span><span class="clip">${request.title}</span></div>`)
    .join("");
  return contextRow("review", describeReviews(queue)) + rows_Html;
}

function restartDialog(container) {
  const name = container.identity.name;
  return `<div class="dialog widget"><div class="dialog-title">` +
    `Restart ${name}?</div><div class="dialog-text">Docker stops` +
    ` it, forcing it after 10 seconds, then starts it again.` +
    `</div>` +
    `<div class="dialog-buttons"><span class="button">Cancel</span>` +
    `<span class="button destructive">Restart ${name}</span>` +
    `</div></div>`;
}

// The CI alert reuses the threshold alerts' debounce: one banner
// per repository and branch, again at most every 5 min.
function ciNotification(github) {
  const status = github.available.status;
  const workflow_Names = status.runs
    .filter((run) => run.outcome === "failure")
    .map((run) => run.workflow_Name).join(", ");
  const full_Name =
    `${status.repository.owner}/${status.repository.name}`;
  return notificationBanner(`CI failed on ${status.branch_Name}`,
    `${workflow_Names} · ${full_Name}`);
}

function renderReviewsAndCI(context, queue) {
  document.body.className = "dark wide";
  const example_Context = withExampleDocker(context);
  const first_Container =
    runningContainers(example_Context.docker)[0];
  document.body.innerHTML =
    `<div class="banner"><span>MAQUETA HTML/CSS · no es una captura` +
    ` real</span><span>CI fallido: estado real de un repo público ·` +
    ` revisiones: fixture grabado · Docker: ejemplo</span></div>` +
    `<div class="desk split"><div class="note-stack">` +
    ciNotification(context.github) +
    `<div class="caption-note">Aviso al pasar a fallo; la primera ` +
    `lectura de una rama no avisa. Pulsarlo abre la ejecución.` +
    `</div><div class="card wide-card">` +
    reviewList(queue, 4) + `</div><div class="caption-note">PRs ` +
    `que esperan tu revisión (borradores excluidos).</div>` +
    restartDialog(first_Container) + `</div>` +
    largeContext({ ...example_Context, review_Queue: queue }) +
    `</div>`;
}
