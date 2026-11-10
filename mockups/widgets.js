// Mockup renderer. The presentation rules below mirror
// macOS/Shared/MetricPresentation.swift, HardwarePresentation.swift
// and DevWidgetsCore MetricFormatting.
const UNIT_NAMES = ["B", "KB", "MB", "GB", "TB", "PB"];
const DEFAULT_THRESHOLDS = { elevated: 0.6, critical: 0.85 };
const LEVEL_COLORS = {
  normal: "var(--green)", elevated: "var(--orange)",
  critical: "var(--red)",
};
const ICONS = {
  cpu: '<rect x="5" y="5" width="14" height="14" rx="3"/>' +
    '<rect x="9" y="9" width="6" height="6" rx="1"/>' +
    '<path d="M9 2v3M15 2v3M9 19v3M15 19v3M2 9h3M2 15h3' +
    'M19 9h3M19 15h3"/>',
  memory: '<rect x="2" y="7" width="20" height="10" rx="2"/>' +
    '<path d="M6 17v3M10 17v3M14 17v3M18 17v3"/>' +
    '<rect x="5" y="10" width="3" height="4"/>' +
    '<rect x="10.5" y="10" width="3" height="4"/>' +
    '<rect x="16" y="10" width="3" height="4"/>',
  disk: '<rect x="2" y="6" width="20" height="12" rx="3"/>' +
    '<circle cx="17" cy="12" r="1.3"/><path d="M5 12h7"/>',
  network: '<circle cx="12" cy="12" r="9.5"/>' +
    '<path d="M2.5 12h19M12 2.5c3 3 3 16 0 19' +
    'M12 2.5c-3 3-3 16 0 19"/>',
  gpu: '<rect x="3" y="4" width="8" height="7" rx="1.5"/>' +
    '<rect x="13" y="4" width="8" height="7" rx="1.5"/>' +
    '<rect x="3" y="13" width="18" height="7" rx="1.5"/>',
  thermal: '<path d="M12 3a2.5 2.5 0 0 0-2.5 2.5v8.2a4.5 4.5 0' +
    ' 1 0 5 0V5.5A2.5 2.5 0 0 0 12 3z"/><path d="M12 10v7"/>',
  battery: '<rect x="2" y="7" width="17" height="10" rx="2.5"/>' +
    '<path d="M22 10.5v3"/><rect x="4.5" y="9.5" width="9"' +
    ' height="5" rx="1"/>',
};
const UNAVAILABLE_TEXT = "—";
// The Linux VM that captured snapshot.json has no GPU, battery or
// temperature sensor; these example values fill those tiles and
// every image that uses them says so.
const EXAMPLE_HARDWARE = {
  gpu_Fraction: 0.31,
  thermal: { level: "normal", celsius: 64 },
  battery: { charge_Fraction: 0.76, power_Source: "battery",
    minutes_Remaining: 245 },
};

function describeBytes(byte_Count) {
  let scaled_Value = Math.max(0, byte_Count);
  let unit_Index = 0;
  while (scaled_Value >= 1024 && unit_Index < UNIT_NAMES.length - 1) {
    scaled_Value /= 1024;
    unit_Index += 1;
  }
  const number_Text = unit_Index === 0
    ? String(Math.floor(scaled_Value))
    : scaled_Value < 10 ? scaled_Value.toFixed(1)
      : String(Math.round(scaled_Value));
  return `${number_Text} ${UNIT_NAMES[unit_Index]}`;
}

function describePercent(fraction) {
  const clamped_Fraction = Math.min(1, Math.max(0, fraction));
  return `${Math.round(clamped_Fraction * 100)}%`;
}

function levelFor(fraction, thresholds = DEFAULT_THRESHOLDS) {
  if (fraction >= thresholds.critical) return "critical";
  if (fraction >= thresholds.elevated) return "elevated";
  return "normal";
}

function describeMinutes(minutes) {
  if (minutes < 60) return `${Math.max(0, minutes)} min`;
  const minute_Text = String(minutes % 60).padStart(2, "0");
  return `${Math.floor(minutes / 60)} h ${minute_Text} min`;
}

function describeCoreShare(fraction) {
  return `${Math.round(Math.max(0, fraction) * 100)}%`;
}

const TITLES = { gpu: "GPU", thermal: "Thermal", battery: "Battery" };

function unavailable(kind) {
  return { kind, title: TITLES[kind], fraction: null,
    is_Available: false,
    value_Text: UNAVAILABLE_TEXT, detail_Text: "Not available",
    level: "normal" };
}

function presentHardware(kind, hardware) {
  if (kind === "gpu") {
    const gpu_Fraction = hardware.gpu_Fraction;
    if (gpu_Fraction == null) return unavailable(kind);
    return { kind, title: "GPU", fraction: gpu_Fraction,
      value_Text: describePercent(gpu_Fraction),
      detail_Text: "Busy", level: levelFor(gpu_Fraction) };
  }
  if (kind === "thermal") return presentThermal(hardware.thermal);
  return presentBattery(hardware.battery);
}

const STATE_NAMES = {
  normal: "Nominal", elevated: "Warm", critical: "Throttling",
};

function presentThermal(thermal) {
  if (!thermal) return unavailable("thermal");
  const state_Text = STATE_NAMES[thermal.level];
  const has_Celsius = thermal.celsius != null;
  return { kind: "thermal", title: "Thermal", fraction: null,
    level: thermal.level,
    value_Text: has_Celsius ? `${Math.round(thermal.celsius)} °C`
      : state_Text,
    detail_Text: has_Celsius ? state_Text : "Thermal state" };
}

const MISSING_CHARGE_THRESHOLDS = { elevated: 0.8, critical: 0.9 };

function presentBattery(battery) {
  if (!battery) return unavailable("battery");
  const on_Battery = battery.power_Source === "battery";
  const level = on_Battery
    ? levelFor(1 - battery.charge_Fraction,
      MISSING_CHARGE_THRESHOLDS) : "normal";
  const detail_Text = {
    charging: "Charging", plugged: "On power adapter",
    battery: battery.minutes_Remaining
      ? `${describeMinutes(battery.minutes_Remaining)} left`
      : "On battery",
  }[battery.power_Source];
  return { kind: "battery", title: "Battery", level, detail_Text,
    fraction: battery.charge_Fraction,
    value_Text: describePercent(battery.charge_Fraction) };
}

function presentMetric(kind, readings) {
  if (kind in TITLES) {
    return presentHardware(kind, readings.hardware);
  }
  if (kind === "cpu") {
    const cpu_Fraction = readings.cpu.total_Fraction;
    return { kind, title: "CPU", fraction: cpu_Fraction,
      value_Text: describePercent(cpu_Fraction),
      detail_Text: `${readings.cpu.core_Fractions.length} cores`,
      level: levelFor(cpu_Fraction) };
  }
  if (kind === "memory") {
    const physical = readings.memory.physical;
    const used_Fraction = physical.used_Bytes / physical.total_Bytes;
    return { kind, title: "Memory", fraction: used_Fraction,
      value_Text: describePercent(used_Fraction),
      detail_Text: `${describeBytes(physical.used_Bytes)} of ` +
        describeBytes(physical.total_Bytes),
      level: readings.memory.pressure };
  }
  if (kind === "disk") {
    const space = readings.disk.space;
    const used_Fraction = space.used_Bytes / space.total_Bytes;
    return { kind, title: "Disk", fraction: used_Fraction,
      value_Text: describePercent(used_Fraction),
      detail_Text: `${describeBytes(space.total_Bytes -
        space.used_Bytes)} free`, level: levelFor(used_Fraction) };
  }
  const network = readings.network;
  return { kind, title: "Network", fraction: null, level: "normal",
    value_Text: `↓ ${describeBytes(
      network.download_Bytes_Per_Second)}/s`,
    detail_Text: `↑ ${describeBytes(
      network.upload_Bytes_Per_Second)}/s` };
}

function iconSvg(kind, color) {
  return `<svg viewBox="0 0 24 24" fill="none" stroke="${color}"` +
    ` stroke-width="1.8" stroke-linecap="round">${ICONS[kind]}</svg>`;
}

function ringSvg(fraction, color) {
  const RADIUS = 40;
  const circumference = 2 * Math.PI * RADIUS;
  const dash_Length = circumference * Math.min(1, fraction);
  return `<svg viewBox="0 0 96 96"><circle cx="48" cy="48"` +
    ` r="${RADIUS}" fill="none" stroke="var(--track)"` +
    ` stroke-width="9"/><circle cx="48" cy="48" r="${RADIUS}"` +
    ` fill="none" stroke="${color}" stroke-width="9"` +
    ` stroke-linecap="round" transform="rotate(-90 48 48)"` +
    ` stroke-dasharray="${dash_Length} ${circumference}"/></svg>`;
}

function smallMetric(presentation) {
  const color = LEVEL_COLORS[presentation.level];
  const header = `<div class="header" style="color:${color}">` +
    `${iconSvg(presentation.kind, color)}${presentation.title}</div>`;
  if (presentation.fraction === null) {
    return `<div class="metric">${header}<div class="rates">` +
      `<div class="down">${presentation.value_Text}</div>` +
      `<div class="up">${presentation.detail_Text}</div></div></div>`;
  }
  return `<div class="metric">${header}<div class="ring">` +
    ringSvg(presentation.fraction, color) +
    `<div class="value">${presentation.value_Text}</div></div>` +
    `<div class="detail">${presentation.detail_Text}</div></div>`;
}

function metricRow(presentation) {
  const color = LEVEL_COLORS[presentation.level];
  const extra_Html = presentation.fraction === null
    ? `<div class="detail">${presentation.detail_Text}</div>`
    : `<div class="bar"><div style="width:` +
      `${Math.min(1, presentation.fraction) * 100}%;` +
      `background:${color}"></div></div>`;
  return `<div class="row">${iconSvg(presentation.kind, color)}` +
    `<div class="body"><div class="line"><span>` +
    `${presentation.title}</span><span>${presentation.value_Text}` +
    `</span></div>${extra_Html}</div></div>`;
}

const METRIC_KINDS = ["cpu", "memory", "disk", "network"];
const HARDWARE_KINDS = ["gpu", "thermal", "battery"];
const COMPANION_COUNT = 3;

function smallWidget(kind, readings) {
  return `<div class="widget small">` +
    `${smallMetric(presentMetric(kind, readings))}</div>`;
}

function mediumWidget(kind, readings) {
  const rows_Html = METRIC_KINDS.filter((other) => other !== kind)
    .slice(0, COMPANION_COUNT)
    .map((other) => metricRow(presentMetric(other, readings)))
    .join("");
  return `<div class="widget medium">` +
    `${smallMetric(presentMetric(kind, readings))}` +
    `<div class="rows">${rows_Html}</div></div>`;
}

const MODE_NAMES = {
  light: "Claro", dark: "Oscuro", tinted: "Tintado",
};

function renderGallery(snapshot, mode) {
  document.body.className = mode;
  const readings = snapshot.readings;
  const smalls_Html = METRIC_KINDS
    .map((kind) => smallWidget(kind, readings)).join("");
  document.body.innerHTML =
    `<div class="banner"><span>MAQUETA HTML/CSS · no es una ` +
    `captura real de macOS</span><span>Modo ${MODE_NAMES[mode]}` +
    ` · datos reales de Linux</span></div><div class="desk">` +
    `<div class="caption">Pequeño (una métrica, elegible)</div>` +
    smalls_Html +
    `<div class="caption">Mediano (métrica destacada + resto)` +
    `</div>` +
    mediumWidget("cpu", readings) + mediumWidget("memory", readings) +
    `</div>`;
}

function renderSingle(snapshot, mode, size, kind) {
  document.body.className = mode;
  const widget_Html = size === "small"
    ? smallWidget(kind, snapshot.readings)
    : mediumWidget(kind, snapshot.readings);
  document.body.innerHTML = `<div class="desk" id="single">` +
    `${widget_Html}</div>`;
}
