// Large and extra-large dashboard mockups. Mirrors
// macOS/Widgets/Views/DashboardView.swift, Shared/HistoryChart.swift
// and Shared/ProcessList.swift.
const LARGE_PROCESS_COUNT = 3;
const TOP_COUNT = 5;
const SIDE_KINDS = ["disk", "gpu", "thermal", "battery"];
const SERIES_COLORS = ["", "var(--blue)"];

function withExampleHardware(snapshot) {
  const hardware = snapshot.readings.hardware || {};
  const filled_Hardware = {
    gpu_Fraction:
      hardware.gpu_Fraction ?? EXAMPLE_HARDWARE.gpu_Fraction,
    thermal: hardware.thermal ?? EXAMPLE_HARDWARE.thermal,
    battery: hardware.battery ?? EXAMPLE_HARDWARE.battery,
  };
  const readings = {
    ...snapshot.readings, hardware: filled_Hardware,
  };
  return { ...snapshot, readings };
}

function historySeries(kind, history) {
  if (kind === "cpu") {
    return [{ name: "CPU", values: history.cpu_Buffer.elements }];
  }
  if (kind === "memory") {
    const memory_Values = history.memory_Buffer.elements;
    return [{ name: "Memory", values: memory_Values }];
  }
  return [
    { name: "Down", values: history.download_Buffer.elements },
    { name: "Up", values: history.upload_Buffer.elements },
  ];
}

function seriesPath(values, upper_Bound, size) {
  const step_Width = size.width / Math.max(1, values.length - 1);
  return values.map((value, index) => {
    const x_Position = (index * step_Width).toFixed(1);
    const y_Position = (size.height -
      (Math.min(value, upper_Bound) / upper_Bound) * size.height)
      .toFixed(1);
    return `${index === 0 ? "M" : "L"}${x_Position} ${y_Position}`;
  }).join(" ");
}

function chartSvg(presentation, series, size) {
  const peak = Math.max(1, ...series.flatMap((line) => line.values));
  const upper_Bound = presentation.fraction === null ? peak : 1;
  const lines_Svg = series.map((line, index) => {
    const color = index === 0 ? LEVEL_COLORS[presentation.level]
      : SERIES_COLORS[index];
    const line_Path = seriesPath(line.values, upper_Bound, size);
    const area_Path = `${line_Path} L${size.width} ${size.height}` +
      ` L0 ${size.height} Z`;
    return `<path d="${area_Path}" fill="${color}"` +
      ` fill-opacity="0.22"/><path d="${line_Path}" fill="none"` +
      ` stroke="${color}" stroke-width="1.6"` +
      ` stroke-linejoin="round"/>`;
  }).join("");
  return `<svg class="chart" viewBox="0 0 ${size.width}` +
    ` ${size.height}" preserveAspectRatio="none">${lines_Svg}</svg>`;
}

function legendHtml(series) {
  if (series.length < 2) return "";
  return `<div class="legend"><span class="dot first"></span>` +
    `${series[0].name}<span class="dot second"></span>` +
    `${series[1].name}</div>`;
}

function historyChart(kind, snapshot, size) {
  const presentation = presentMetric(kind, snapshot.readings);
  const series = historySeries(kind, snapshot.history);
  const color = LEVEL_COLORS[presentation.level];
  return `<div class="history" style="--first:${color}">` +
    `<div class="history-head"><div class="header"` +
    ` style="color:${color}">${iconSvg(kind, color)}` +
    `${presentation.title}</div><span>${presentation.value_Text}` +
    `</span></div>${chartSvg(presentation, series, size)}` +
    `${legendHtml(series)}</div>`;
}

function processList(processes, row_Limit) {
  const rows_Html = processes.slice(0, row_Limit).map((process) =>
    `<div class="process"><span class="name">` +
    `${process.identity.name}</span><span>` +
    `${describeCoreShare(process.cpu_Fraction)}</span>` +
    `<span class="memory">${describeBytes(process.resident_Bytes)}` +
    `</span>${actionButton("quit", false)}</div>`).join("");
  return `<div class="processes"><div class="list-title">` +
    `Top processes</div>${rows_Html}</div>`;
}

function dashboardHeader(snapshot) {
  const address = snapshot.readings.local_Address || "";
  return `<div class="dash-head"><div class="header">` +
    `${iconSvg("cpu", "var(--primary)")}DevWidgets</div>` +
    `<span class="address">${address}</span>` +
    `<span class="time">15:30</span></div>`;
}

const CPU_CHART_HEIGHT = 96;
const PAIR_CHART_HEIGHT = 62;
const CHART_GAP = 12;

function chartStack(snapshot, chart_Width) {
  const full_Size = { width: chart_Width, height: CPU_CHART_HEIGHT };
  const half_Size = { width: (chart_Width - CHART_GAP) / 2,
    height: PAIR_CHART_HEIGHT };
  return `<div class="chart-stack">` +
    historyChart("cpu", snapshot, full_Size) +
    `<div class="chart-pair">` +
    historyChart("memory", snapshot, half_Size) +
    historyChart("network", snapshot, half_Size) +
    `</div></div>`;
}

function largeWidget(snapshot) {
  return `<div class="widget large">${dashboardHeader(snapshot)}` +
    chartStack(snapshot, 332) +
    processList(
      snapshot.readings.top_Processes, LARGE_PROCESS_COUNT) +
    `</div>`;
}

function extraLargeWidget(snapshot) {
  const rows_Html = SIDE_KINDS.map((kind) =>
    metricRow(presentMetric(kind, snapshot.readings))).join("");
  return `<div class="widget xlarge">${dashboardHeader(snapshot)}` +
    `<div class="xl-columns">${chartStack(snapshot, 340)}` +
    `<div class="side">${rows_Html}` +
    processList(snapshot.readings.top_Processes, TOP_COUNT) +
    `</div></div></div>`;
}

function renderDashboards(snapshot, mode) {
  document.body.className = mode;
  const example_Snapshot = withExampleHardware(snapshot);
  document.body.innerHTML =
    `<div class="banner"><span>MAQUETA HTML/CSS · no es una ` +
    `captura real de macOS</span><span>Modo ${MODE_NAMES[mode]}` +
    ` · historial real de Linux · GPU/batería/temperatura: valores` +
    ` de ejemplo</span></div><div class="desk">` +
    `<div class="caption">Grande (historial + procesos)</div>` +
    largeWidget(example_Snapshot) +
    `<div class="caption">Extra grande (historial, hardware y` +
    ` procesos)</div>${extraLargeWidget(example_Snapshot)}</div>`;
}
