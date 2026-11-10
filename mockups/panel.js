// Menu bar panel mockup: metric cards on the left, processes and
// the developer context on the right. Mirrors
// macOS/App/Views/MenuBarPanel.swift and DeveloperSection.swift.
function metricCards(readings) {
  return METRIC_KINDS.concat(HARDWARE_KINDS)
    .map((kind) => presentMetric(kind, readings))
    .filter((presentation) => presentation.is_Available !== false)
    .map((presentation) =>
      `<div class="card">${metricRow(presentation)}</div>`).join("");
}

const PANEL_SERVER_COUNT = 4;
const PANEL_REVIEW_COUNT = 3;

function serverSection(overview) {
  return `<div class="card"><div class="list-title">Servers</div>` +
    serverReports(overview).slice(0, PANEL_SERVER_COUNT)
      .map(serverRow).join("") + `</div>`;
}

function contextColumn(readings, context, queue) {
  return processList(readings.top_Processes, TOP_COUNT) +
    contextRow("branch", describeGit(context.git)) +
    contextRow("seal", describeGitHub(context.github)) +
    `<div>${reviewList(queue, PANEL_REVIEW_COUNT)}</div>` +
    `<div>${containerList(context.docker, 4, null, true)}</div>` +
    portList(context.ports, 6) +
    `<div class="buttons"><div class="button">Choose Project…` +
    `</div><div class="button">Open Project</div></div>`;
}

function renderPanel(snapshot, context, extras) {
  document.body.className = "dark wide";
  const readings = withExampleHardware(snapshot).readings;
  const cpu_Text = describePercent(readings.cpu.total_Fraction);
  document.body.innerHTML =
    `<div class="menubar"><span>  Finder  Archivo  Edición</span>` +
    `<span>${iconSvg("cpu", "#fff")} ${cpu_Text}   mar 10 nov` +
    `  15:30</span></div><div class="banner">MAQUETA HTML/CSS · ` +
    `no es una captura real · panel de la barra de menús · ` +
    `GPU/batería/temperatura, Docker y servidores web-1, db-1 y ` +
    `ci-runner: ejemplo · Git, GitHub y devwidgets-test (SSH): ` +
    `reales · revisiones: fixture grabado</div>` +
    `<div class="panel two-columns widget">` +
    `<div class="panel-title"><span>DevWidgets</span>` +
    `<span class="address">${readings.local_Address || ""}  ` +
    `${iconSvg("gear", "var(--primary)")}</span>` +
    `</div><div class="columns">` +
    `<div class="column">${metricCards(readings)}` +
    `${serverSection(extras.servers)}</div><div class="column">` +
    contextColumn(readings, withExampleDocker(context),
      extras.reviews) +
    `</div></div><div class="divider"></div>` +
    `<div class="quit">Quit DevWidgets</div></div>`;
}
