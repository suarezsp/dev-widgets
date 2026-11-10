// Developer-context mockups and the menu bar panel. Mirrors
// macOS/Shared/ContextPresentation.swift, DeveloperContextViews.swift
// and Widgets/Views/DeveloperContextView.swift.
Object.assign(ICONS, {
  branch: '<circle cx="6" cy="5" r="2.2"/><circle cx="6" cy="19"' +
    ' r="2.2"/><circle cx="18" cy="7" r="2.2"/><path d="M6 7.2v9.6' +
    'M18 9.2c0 5-12 3-12 7.6"/>',
  container: '<path d="M3 7.5 12 3l9 4.5v9L12 21l-9-4.5z"/>' +
    '<path d="M3 7.5 12 12l9-4.5M12 12v9"/>',
  ports: '<circle cx="5" cy="12" r="2.2"/><circle cx="19" cy="5"' +
    ' r="2.2"/><circle cx="19" cy="19" r="2.2"/>' +
    '<path d="M7 11l10-5M7 13l10 5"/>',
});
const OTHER_OWNER_NAME = "other users";
const MEDIUM_CONTAINER_COUNT = 1;
const MEDIUM_PORT_GROUP_COUNT = 2;
const LARGE_CONTAINER_COUNT = 3;
const LARGE_PORT_GROUP_COUNT = 4;
const LARGE_REVIEW_COUNT = 2;
// The build box has no Docker: these containers mirror the
// hand-written fixtures in Tests/Fixtures/docker and are labeled
// as example values in every image that shows them.
const EXAMPLE_CONTAINERS = [
  { identity: { name: "api-db-1", image: "postgres:16" },
    state: "running", cpu_Fraction: 0.0085, memory_Bytes: 80111206 },
  { identity: { name: "api-cache-1", image: "redis:7-alpine" },
    state: "running", cpu_Fraction: 1.523, memory_Bytes: 9961472 },
  { identity: { name: "web-old", image: "node:22" },
    state: "exited" },
];

function withExampleDocker(context) {
  if (context.docker.available) return context;
  return { ...context,
    docker: { available: { containers: EXAMPLE_CONTAINERS } } };
}

function describeChanges(changes, branch) {
  const arrow_Parts = [[branch.ahead_Count, "↑"],
    [branch.behind_Count, "↓"]]
    .filter(([total]) => total > 0)
    .map(([total, arrow]) => `${arrow}${total}`);
  const change_Parts = [[changes.conflicted, "conflicted"],
    [changes.staged, "staged"], [changes.modified, "modified"],
    [changes.untracked, "untracked"]]
    .filter(([total]) => total > 0)
    .map(([total, word]) => `${total} ${word}`);
  const parts = arrow_Parts.concat(change_Parts);
  return parts.length ? parts.join(" · ") : "Clean";
}

function describeGit(git) {
  if (git.not_Configured) {
    return { title: "No project", level: "normal",
      detail_Text: "Choose one in the menu bar" };
  }
  if (git.not_A_Repository) {
    return { title: git.not_A_Repository.project_Name,
      detail_Text: "Not a Git repository", level: "elevated" };
  }
  if (!git.available) {
    return { title: "Git", detail_Text: "Git not found",
      level: "normal" };
  }
  const status = git.available.status;
  const changes = status.changes;
  const is_Clean = changes.staged + changes.modified +
    changes.untracked + changes.conflicted === 0;
  const level = changes.conflicted > 0 ? "critical"
    : is_Clean ? "normal" : "elevated";
  const branch_Name = status.branch.name ||
    `detached at ${(status.branch.commit_ID || "?").slice(0, 7)}`;
  return { title: `${status.project_Name} · ${branch_Name}`, level,
    detail_Text: describeChanges(changes, status.branch) };
}

function runningContainers(docker) {
  if (!docker.available) return [];
  return docker.available.containers
    .filter((container) => container.state === "running");
}

function describeDocker(docker) {
  if (docker.not_Installed) return "Not installed";
  if (docker.not_Running) return "Not running";
  return `${runningContainers(docker).length} running of ` +
    `${docker.available.containers.length}`;
}

function groupPorts(ports) {
  const groups = [];
  for (const port of ports) {
    const owner_Name = port.owner ? port.owner.name
      : OTHER_OWNER_NAME;
    const group = groups.find(
      (item) => item.owner_Name === owner_Name);
    if (group) group.ports.push(port.port);
    else groups.push({ owner_Name, ports: [port.port] });
  }
  return groups;
}

function contextRow(icon_Kind, line) {
  const color = LEVEL_COLORS[line.level];
  return `<div class="row ctx">${iconSvg(icon_Kind, color)}` +
    `<div class="body"><div class="line"><span class="clip">` +
    `${line.title}</span></div><div class="detail wrap">` +
    `${line.detail_Text}</div></div></div>`;
}

// Large widgets and the panel also offer restart.
function containerButtons(container, armed_Name, shows_Restart) {
  const restart_Html = shows_Restart
    ? actionButton("restart", false) : "";
  return restart_Html + actionButton("stop",
    container.identity.name === armed_Name);
}

function containerList(docker, row_Limit, armed_Name,
  shows_Restart = false) {
  const rows_Html = runningContainers(docker)
    .sort((left, right) => right.cpu_Fraction - left.cpu_Fraction)
    .slice(0, row_Limit)
    .map((container) => `<div class="process indent"><span` +
      ` class="name">${container.identity.name}</span><span>` +
      `${describeCoreShare(container.cpu_Fraction)}</span><span` +
      ` class="memory">${describeBytes(container.memory_Bytes)}` +
      `</span>${containerButtons(container, armed_Name,
        shows_Restart)}</div>`).join("");
  return contextRow("container", { title: "Docker", level: "normal",
    detail_Text: describeDocker(docker) }) + rows_Html;
}

function portList(ports, row_Limit) {
  const rows_Html = groupPorts(ports).slice(0, row_Limit)
    .map((group) => `<div class="process"><span class="name">` +
      `${group.owner_Name}</span><span class="port-list">` +
      group.ports.map((port) => `:${port}`).join(" ") +
      `</span></div>`).join("");
  return `<div class="processes"><div class="list-title">` +
    `Listening ports</div>${rows_Html}</div>`;
}

function mediumContext(context, armed_Name) {
  return `<div class="widget medium ctx-medium"><div class="col">` +
    projectRows(context) + `</div><div class="col">` +
    containerList(context.docker, MEDIUM_CONTAINER_COUNT,
      armed_Name) +
    portList(context.ports, MEDIUM_PORT_GROUP_COUNT) +
    `</div></div>`;
}

function largeContext(context) {
  const reviews_Html = context.review_Queue
    ? `<div>${reviewList(context.review_Queue,
      LARGE_REVIEW_COUNT)}</div>` : "";
  return `<div class="widget large ctx-large">` +
    projectRows(context) + reviews_Html +
    `<div>${containerList(context.docker, LARGE_CONTAINER_COUNT,
      null, true)}</div>` +
    `${portList(context.ports, LARGE_PORT_GROUP_COUNT)}</div>`;
}

function renderContext(context, mode, queue) {
  document.body.className = mode;
  const example_Context = { ...withExampleDocker(context),
    review_Queue: queue };
  document.body.innerHTML =
    `<div class="banner"><span>MAQUETA HTML/CSS · no es una ` +
    `captura real de macOS</span><span>Modo ${MODE_NAMES[mode]}` +
    ` · Git, GitHub y puertos reales · Docker: ejemplo` +
    ` · revisiones: fixture grabado` +
    `</span></div><div class="desk">` +
    `<div class="caption">Mediano (Git, GitHub, Docker y puertos)` +
    `</div>${mediumContext(example_Context, null)}` +
    `<div class="caption">Grande (revisiones pendientes, ` +
    `reiniciar y parar contenedores, puertos)` +
    `</div>${largeContext(example_Context)}</div>`;
}
