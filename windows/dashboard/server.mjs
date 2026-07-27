import { createServer } from "node:http";
import { createConnection } from "node:net";
import { copyFile, mkdir, readFile, rename, stat, writeFile } from "node:fs/promises";
import { extname, join, normalize, relative } from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const root = process.env.RELAYWATCH_PUBLIC_ROOT || "C:\\ProgramData\\daakLOLILE\\dashboard\\public";
const appRoot = process.env.RELAYWATCH_ROOT || "C:\\ProgramData\\daakLOLILE";
const torRoot = process.env.TOR_ROOT || "C:\\ProgramData\\TorRelay";
const torrcPath = join(torRoot, "torrc");
const torExe = join(torRoot, "tor", "tor.exe");
const controlCookiePath = join(torRoot, "data", "control_auth_cookie");
const fingerprintPath = process.env.TOR_FINGERPRINT_PATH || join(torRoot, "data", "fingerprint");
const trafficPath = join(appRoot, "data", "traffic.json");
const snowflakeTrafficPath = join(appRoot, "data", "snowflake-traffic.json");
const snowflakeLogPath = process.env.SNOWFLAKE_LOG_PATH || "C:\\ProgramData\\SnowflakeProxy\\logs\\snowflake.log";
const hardwareStatusPath = process.env.RELAYWATCH_HARDWARE_STATUS || join(appRoot, "hardware-status.json");
const powerManagerPath = process.env.daakLOLILE_POWER_MANAGER || join(appRoot, "power-manager.ps1");
const powerStatusPath = process.env.daakLOLILE_POWER_STATUS || join(appRoot, "power-status.json");
const memoryManagerPath = process.env.daakLOLILE_MEMORY_MANAGER || join(appRoot, "memory-manager.ps1");
const memoryStatusPath = process.env.daakLOLILE_MEMORY_STATUS || join(appRoot, "memory-status.json");
const port = Number(process.env.RELAYWATCH_PORT || 17657);
const orPort = Number(process.env.TOR_OR_PORT || 9001);
const configuredServiceName = String(process.env.TOR_SERVICE_NAME || "tor");
const torServiceName = /^[A-Za-z0-9_.-]+$/.test(configuredServiceName) ? configuredServiceName : "tor";
let onionooCache = { checkedAt: 0, found: false, running: false, flags: [] };
let controlCache = { checkedAt: 0, value: null, pending: null };
let settingsBusy = false;
const hardwareHistory = [];
let lastHardwareSample = "";

const mime = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".svg": "image/svg+xml",
};

async function text(path) {
  try { return await readFile(path, "utf8"); } catch { return ""; }
}

function configValue(config, key) {
  const match = config.match(new RegExp(`^\\s*${key}\\s+(.+)$`, "im"));
  return match?.[1]?.trim() ?? "";
}

function parseByteRate(value) {
  const match = value.match(/^([\d.]+)\s+(bytes|KBytes|MBytes|GBytes|TBytes|KBits|MBits|GBits|TBits)$/i);
  if (!match) return 0;
  const multipliers = {
    bytes: 1,
    kbytes: 1024,
    mbytes: 1024 ** 2,
    gbytes: 1024 ** 3,
    tbytes: 1024 ** 4,
    kbits: 1024 / 8,
    mbits: 1024 ** 2 / 8,
    gbits: 1024 ** 3 / 8,
    tbits: 1024 ** 4 / 8,
  };
  return Number(match[1]) * multipliers[match[2].toLowerCase()];
}

function parseByteSize(value) {
  const match = value.match(/^([\d.]+)(?:\s+(bytes|KBytes|MBytes|GBytes|TBytes))?$/i);
  if (!match) return 0;
  const multipliers = { bytes: 1, kbytes: 1024, mbytes: 1024 ** 2, gbytes: 1024 ** 3, tbytes: 1024 ** 4 };
  return Number(match[1]) * (multipliers[(match[2] || "bytes").toLowerCase()] || 1);
}

function stateSeries(state, key) {
  const match = state.match(new RegExp(`^${key}\\s+(.+)$`, "m"));
  return match ? match[1].split(",").map(Number).filter(Number.isFinite) : [];
}

function currentMonth() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

function isLoopback(address) {
  return address === "127.0.0.1" || address === "::1" || address === "::ffff:127.0.0.1";
}

function isTailscale(address = "") {
  const value = String(address).replace(/^::ffff:/i, "").toLowerCase();
  if (value.startsWith("fd7a:115c:a1e0:")) return true;
  const parts = value.split(".").map(Number);
  return parts.length === 4
    && parts.every(part => Number.isInteger(part) && part >= 0 && part <= 255)
    && parts[0] === 100
    && parts[1] >= 64
    && parts[1] <= 127;
}

function normalizeContact(value) {
  return value.replace(/^email:/i, "").trim();
}

async function relayFingerprint() {
  const configured = String(process.env.TOR_FINGERPRINT || "").replace(/\s/g, "").toUpperCase();
  if (/^[A-F0-9]{40}$/.test(configured)) return configured;
  const fromFile = (await text(fingerprintPath)).match(/\b([A-F0-9]{40})\b/i)?.[1] || "";
  return fromFile.toUpperCase();
}

async function systemStatus() {
  const command = [
    `$s=Get-CimInstance Win32_Service -Filter "Name='${torServiceName}'" -ErrorAction SilentlyContinue`,
    `$p=Get-NetTCPConnection -LocalPort ${orPort} -State Listen -ErrorAction SilentlyContinue`,
    "$ip=Get-NetIPAddress -InterfaceAlias Ethernet -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object IPAddress -notlike '169.254*' | Select-Object -First 1 -ExpandProperty IPAddress",
    "$ts=Get-NetIPAddress -InterfaceAlias Tailscale -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object IPAddress -like '100.*' | Select-Object -First 1 -ExpandProperty IPAddress",
    "[pscustomobject]@{running=($s.State -eq 'Running');startMode=$s.StartMode;listening=(@($p).Count -gt 0);localIp=$ip;tailscaleIp=$ts} | ConvertTo-Json -Compress",
  ].join("; ");
  try {
    const { stdout } = await execFileAsync("powershell.exe", ["-NoProfile", "-Command", command], {
      windowsHide: true,
      timeout: 5000,
    });
    return JSON.parse(stdout.trim());
  } catch {
    return { running: false, startMode: "Unknown", listening: false, localIp: "", tailscaleIp: "" };
  }
}

async function consensusStatus() {
  if (Date.now() - onionooCache.checkedAt < 300000) return onionooCache;
  const fingerprint = await relayFingerprint();
  if (!fingerprint) {
    onionooCache = { checkedAt: Date.now(), found: false, running: false, flags: [] };
    return onionooCache;
  }
  try {
    const response = await fetch(`https://onionoo.torproject.org/details?lookup=${fingerprint}`, {
      signal: AbortSignal.timeout(5000),
      headers: { "User-Agent": "daakLOLILE/2.0" },
    });
    const body = await response.json();
    const relay = body.relays?.[0];
    onionooCache = {
      checkedAt: Date.now(),
      found: Boolean(relay),
      running: Boolean(relay?.running),
      flags: relay?.flags ?? [],
    };
  } catch {
    onionooCache = { ...onionooCache, checkedAt: Date.now() };
  }
  return onionooCache;
}

async function queryControlInfo() {
  const cookie = await readFile(controlCookiePath);
  return await new Promise((resolve, reject) => {
    const socket = createConnection({ host: "127.0.0.1", port: 9051 });
    let body = "";
    const timer = setTimeout(() => socket.destroy(new Error("Tor control timeout")), 3500);
    socket.setEncoding("utf8");
    socket.on("connect", () => {
      socket.write(`AUTHENTICATE ${cookie.toString("hex")}\r\n`);
      socket.write("GETINFO traffic/read traffic/written uptime\r\n");
      socket.write("QUIT\r\n");
    });
    socket.on("data", chunk => { body += chunk; });
    socket.on("error", reject);
    socket.on("close", hadError => {
      clearTimeout(timer);
      if (hadError) return;
      if (!body.includes("250 OK")) {
        reject(new Error("Tor control authentication failed"));
        return;
      }
      const read = Number(body.match(/250-traffic\/read=(\d+)/)?.[1]);
      const write = Number(body.match(/250-traffic\/written=(\d+)/)?.[1]);
      const uptime = Number(body.match(/250-uptime=(\d+)/)?.[1]);
      if (![read, write, uptime].every(Number.isFinite)) {
        reject(new Error("Tor control response incomplete"));
        return;
      }
      resolve({ read, write, uptime });
    });
  });
}

async function controlInfo() {
  if (controlCache.value && Date.now() - controlCache.checkedAt < 9000) {
    return controlCache.value;
  }
  if (controlCache.pending) return controlCache.pending;
  controlCache.pending = queryControlInfo()
    .then(value => {
      controlCache.value = value;
      controlCache.checkedAt = Date.now();
      return value;
    })
    .finally(() => {
      controlCache.pending = null;
    });
  return controlCache.pending;
}

async function monthlyTraffic(fallbackRead, fallbackWrite) {
  let live;
  try { live = await controlInfo(); } catch { return { read: fallbackRead, write: fallbackWrite, source: "history" }; }

  let tracker = {};
  try { tracker = JSON.parse(await readFile(trafficPath, "utf8")); } catch {}
  const month = currentMonth();
  const sameMonth = tracker.month === month;
  let totalRead = sameMonth ? Number(tracker.totalRead) || 0 : 0;
  let totalWrite = sameMonth ? Number(tracker.totalWrite) || 0 : 0;

  if (!sameMonth || !Number.isFinite(Number(tracker.lastRead)) || !Number.isFinite(Number(tracker.lastWrite))) {
    totalRead = Math.max(fallbackRead, live.read);
    totalWrite = Math.max(fallbackWrite, live.write);
  } else {
    totalRead += live.read >= tracker.lastRead ? live.read - tracker.lastRead : live.read;
    totalWrite += live.write >= tracker.lastWrite ? live.write - tracker.lastWrite : live.write;
    totalRead = Math.max(totalRead, fallbackRead);
    totalWrite = Math.max(totalWrite, fallbackWrite);
  }

  tracker = {
    month,
    totalRead,
    totalWrite,
    lastRead: live.read,
    lastWrite: live.write,
    uptime: live.uptime,
    updatedAt: new Date().toISOString(),
  };
  try {
    await mkdir(join(appRoot, "data"), { recursive: true });
    await writeFile(trafficPath, JSON.stringify(tracker, null, 2), "utf8");
  } catch {}
  return { read: totalRead, write: totalWrite, source: "control" };
}

function prometheusTotal(metrics, name) {
  return metrics
    .split(/\r?\n/)
    .filter(line => line.startsWith(`${name} `) || line.startsWith(`${name}{`))
    .reduce((sum, line) => {
      const value = Number(line.trim().split(/\s+/).at(-1));
      return sum + (Number.isFinite(value) ? value : 0);
    }, 0);
}

async function snowflakeMonthly(live) {
  let tracker = {};
  try { tracker = JSON.parse(await readFile(snowflakeTrafficPath, "utf8")); } catch {}
  const month = currentMonth();
  const sameMonth = tracker.month === month;
  let inbound = sameMonth ? Number(tracker.inbound) || 0 : 0;
  let outbound = sameMonth ? Number(tracker.outbound) || 0 : 0;
  let connections = sameMonth ? Number(tracker.connections) || 0 : 0;
  let timeouts = sameMonth ? Number(tracker.timeouts) || 0 : 0;

  if (live) {
    if (!sameMonth || !Number.isFinite(Number(tracker.lastInbound))) {
      inbound = live.inbound;
      outbound = live.outbound;
      connections = live.connections;
      timeouts = live.timeouts;
    } else {
      inbound += live.inbound >= tracker.lastInbound ? live.inbound - tracker.lastInbound : live.inbound;
      outbound += live.outbound >= tracker.lastOutbound ? live.outbound - tracker.lastOutbound : live.outbound;
      connections += live.connections >= tracker.lastConnections ? live.connections - tracker.lastConnections : live.connections;
      timeouts += live.timeouts >= tracker.lastTimeouts ? live.timeouts - tracker.lastTimeouts : live.timeouts;
    }
    tracker = {
      month,
      inbound,
      outbound,
      connections,
      timeouts,
      lastInbound: live.inbound,
      lastOutbound: live.outbound,
      lastConnections: live.connections,
      lastTimeouts: live.timeouts,
      updatedAt: new Date().toISOString(),
    };
    try {
      await mkdir(join(appRoot, "data"), { recursive: true });
      await writeFile(snowflakeTrafficPath, JSON.stringify(tracker, null, 2), "utf8");
    } catch {}
  }

  return { inbound, outbound, total: inbound + outbound, connections, timeouts };
}

async function snowflakeStatus() {
  const log = await text(snowflakeLogPath);
  let running = false;
  let live = null;
  try {
    const response = await fetch("http://127.0.0.1:9999/internal/metrics", {
      signal: AbortSignal.timeout(2500),
      cache: "no-store",
    });
    if (response.ok) {
      running = true;
      const metrics = await response.text();
      live = {
        inbound: prometheusTotal(metrics, "tor_snowflake_proxy_traffic_inbound_bytes_total"),
        outbound: prometheusTotal(metrics, "tor_snowflake_proxy_traffic_outbound_bytes_total"),
        connections: prometheusTotal(metrics, "tor_snowflake_proxy_connections_total"),
        timeouts: prometheusTotal(metrics, "tor_snowflake_proxy_connection_timeouts_total"),
      };
    }
  } catch {}
  const traffic = await snowflakeMonthly(live);
  const natMatches = [...log.matchAll(/NAT type:\s*([a-z-]+)/gi)];
  return {
    running,
    capacity: 100,
    natType: natMatches.at(-1)?.[1]?.toLowerCase() ?? "checking",
    traffic,
    logs: log.split(/\r?\n/).filter(Boolean).slice(-12),
  };
}

async function hardwareStatus() {
  try {
    const value = JSON.parse(await readFile(hardwareStatusPath, "utf8"));
    const updated = Date.parse(value.updatedAt);
    const ageSeconds = Number.isFinite(updated) ? Math.max(0, (Date.now() - updated) / 1000) : null;
    const available = value.available === true && ageSeconds !== null && ageSeconds < 15;

    if (value.updatedAt && value.updatedAt !== lastHardwareSample) {
      lastHardwareSample = value.updatedAt;
      hardwareHistory.push({
        at: value.updatedAt,
        watts: Number(value.power?.wallEstimateWatts) || 0,
        cpu: Number(value.cpu?.loadPercent) || 0,
        gpu: Number(value.gpu?.loadPercent) || 0,
        memory: Number(value.memory?.loadPercent) || 0,
      });
      if (hardwareHistory.length > 120) hardwareHistory.splice(0, hardwareHistory.length - 120);
    }

    return {
      ...value,
      available,
      stale: !available,
      ageSeconds,
      history: [...hardwareHistory],
    };
  } catch {
    return {
      available: false,
      stale: true,
      updatedAt: null,
      ageSeconds: null,
      history: [...hardwareHistory],
    };
  }
}

async function powerStatus() {
  try {
    const value = JSON.parse((await readFile(powerStatusPath, "utf8")).replace(/^\uFEFF/, ""));
    const updated = Date.parse(value.updatedAt);
    return {
      ...value,
      available: value.available === true,
      ageSeconds: Number.isFinite(updated) ? Math.max(0, (Date.now() - updated) / 1000) : null,
    };
  } catch {
    return {
      available: false,
      controlMode: "unknown",
      effectiveMode: "unknown",
      nightStart: "00:00",
      nightEnd: "08:00",
      safeguards: { services: [], snowflake: false, sleepDisabled: true },
    };
  }
}

async function memoryStatus() {
  try {
    const value = JSON.parse((await readFile(memoryStatusPath, "utf8")).replace(/^\uFEFF/, ""));
    const updated = Date.parse(value.updatedAt);
    return {
      ...value,
      available: value.available === true,
      ageSeconds: Number.isFinite(updated) ? Math.max(0, (Date.now() - updated) / 1000) : null,
    };
  } catch {
    return {
      available: false,
      decision: "unknown",
      message: "Bellek bakımı henüz çalışmadı.",
      pressureDetected: false,
      schedule: { dailyAt: "04:30", runsWithoutLogin: true },
      policy: { automaticOnlyUnderPressure: true, protected: [] },
    };
  }
}

async function setPowerMode(input) {
  const mode = String(input.mode || "").toLowerCase();
  const nightStart = String(input.nightStart || "");
  const nightEnd = String(input.nightEnd || "");
  if (!["auto", "eco", "balanced", "performance"].includes(mode)) {
    throw new Error("Geçersiz güç modu.");
  }
  if (nightStart && !/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(nightStart)) {
    throw new Error("Gece başlangıcı SS:DD biçiminde olmalı.");
  }
  if (nightEnd && !/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(nightEnd)) {
    throw new Error("Gece bitişi SS:DD biçiminde olmalı.");
  }
  const args = [
    "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
    "-File", powerManagerPath, "-Action", "Set", "-Mode", mode, "-InstallRoot", appRoot,
  ];
  if (nightStart) args.push("-NightStart", nightStart);
  if (nightEnd) args.push("-NightEnd", nightEnd);
  await execFileAsync("powershell.exe", args, {
    windowsHide: true,
    timeout: 30000,
  });
  return powerStatus();
}

async function maintainMemory() {
  await execFileAsync("powershell.exe", [
    "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
    "-File", memoryManagerPath, "-Action", "Maintain", "-Force", "-InstallRoot", appRoot,
  ], {
    windowsHide: true,
    timeout: 30000,
  });
  return memoryStatus();
}

async function buildStatus(settingsAllowed = false, powerAllowed = false) {
  const [config, state, log, system, consensus, snowflake, hardware, power, memoryMaintenance, fingerprint] = await Promise.all([
    text(torrcPath),
    text(join(torRoot, "data", "state")),
    text(join(torRoot, "log", "notices.log")),
    systemStatus(),
    consensusStatus(),
    snowflakeStatus(),
    hardwareStatus(),
    powerStatus(),
    memoryStatus(),
    relayFingerprint(),
  ]);
  const readHistory = stateSeries(state, "BWHistoryReadValues");
  const writeHistory = stateSeries(state, "BWHistoryWriteValues");
  const length = Math.max(readHistory.length, writeHistory.length);
  const history = Array.from({ length }, (_, i) => (readHistory[i] || 0) + (writeHistory[i] || 0));
  const fallbackRead = readHistory.reduce((a, b) => a + b, 0);
  const fallbackWrite = writeHistory.reduce((a, b) => a + b, 0);
  const traffic = await monthlyTraffic(fallbackRead, fallbackWrite);
  const quota = parseByteSize(configValue(config, "AccountingMax"));
  const logLines = log
    .split(/\r?\n/)
    .filter(Boolean)
    .filter(line => !/New control connection opened from 127\.0\.0\.1\./i.test(line))
    .filter(line => !/Got authentication cookie with wrong length \(0\)/i.test(line));
  const bootstrapMatches = [...log.matchAll(/Bootstrapped\s+(\d+)%/g)].map(match => Number(match[1]));
  const bootstrap = bootstrapMatches.at(-1) || 0;
  const ipv4Reachable = /Self-testing indicates your (?:IPv4 )?ORPort (?!\[)[^\r\n]* is reachable from the outside/i.test(log);
  const ipv6Reachable = /Self-testing indicates your (?:IPv6 )?ORPort \[[0-9a-f:]+\]:\d+ is reachable from the outside/i.test(log);
  const checking = /Now checking whether .*ORPort/i.test(log) && !ipv4Reachable && !ipv6Reachable;
  const rateBytes = parseByteRate(configValue(config, "RelayBandwidthRate"));
  const burstBytes = parseByteRate(configValue(config, "RelayBandwidthBurst"));
  const total = traffic.read + traffic.write;

  return {
    updatedAt: new Date().toISOString(),
    product: "daakLOLILE",
    permissions: { settings: settingsAllowed, power: powerAllowed, memory: powerAllowed },
    service: { running: system.running, startMode: system.startMode },
    port: { listening: system.listening, number: orPort },
    localIp: system.localIp,
    tailscaleIp: system.tailscaleIp,
    bootstrap,
    reachability: ipv4Reachable ? "reachable" : ipv6Reachable ? "ipv6-only" : checking ? "checking" : "unknown",
    consensus,
    snowflake,
    hardware,
    power,
    memoryMaintenance,
    support: { total: total + snowflake.traffic.total },
    config: {
      nickname: configValue(config, "Nickname"),
      fingerprint,
      contactInfo: normalizeContact(configValue(config, "ContactInfo")),
      nonExit: /^0$/.test(configValue(config, "ExitRelay")) && /reject \*:\*/i.test(configValue(config, "ExitPolicy")),
      rateMbps: Math.round(rateBytes * 8 / 1_000_000),
      burstMbps: Math.round(burstBytes * 8 / 1_000_000),
    },
    traffic: {
      read: traffic.read,
      write: traffic.write,
      total,
      quota,
      unlimited: quota <= 0,
      percent: quota > 0 ? total / quota * 100 : 0,
      history,
      period: currentMonth(),
      source: traffic.source,
    },
    logs: logLines.slice(-30),
  };
}

function parseBody(req, limit = 65536) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", chunk => {
      body += chunk;
      if (body.length > limit) req.destroy(new Error("Request body too large"));
    });
    req.on("end", () => {
      try { resolve(JSON.parse(body || "{}")); } catch { reject(new Error("Geçersiz istek")); }
    });
    req.on("error", reject);
  });
}

function validateSettings(input) {
  const rateMbps = Number(input.rateMbps);
  const burstMbps = Number(input.burstMbps);
  const unlimited = input.unlimited === true;
  const quotaGB = unlimited ? 0 : Number(input.quotaGB);
  const contactInfo = String(input.contactInfo ?? "").trim();

  if (!Number.isFinite(rateMbps) || rateMbps < 1 || rateMbps > 1000) {
    throw new Error("Sürekli hız 1–1000 Mbps arasında olmalı.");
  }
  if (!Number.isFinite(burstMbps) || burstMbps < rateMbps || burstMbps > 1000) {
    throw new Error("Kısa süreli hız, sürekli hızdan düşük olamaz ve 1000 Mbps'i geçemez.");
  }
  if (!unlimited && (!Number.isFinite(quotaGB) || quotaGB < 10 || quotaGB > 1_000_000)) {
    throw new Error("Aylık kota en az 10 GB olmalı.");
  }
  if (contactInfo.length > 200 || /[\r\n]/.test(contactInfo)) {
    throw new Error("ContactInfo en fazla 200 karakter olabilir.");
  }
  if (contactInfo && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(contactInfo)) {
    throw new Error("ContactInfo için geçerli bir e-posta adresi yaz.");
  }
  return { rateMbps, burstMbps, unlimited, quotaGB, contactInfo };
}

function renderTorrc(config, settings) {
  const managed = /^(RelayBandwidthRate|RelayBandwidthBurst|AccountingMax|AccountingRule|AccountingStart|ContactInfo)\b/i;
  const lines = config
    .split(/\r?\n/)
    .filter(line => !managed.test(line.trim()))
    .filter(line => !/^# (Dashboard-managed|Public operator contact|Monthly traffic limit)/i.test(line.trim()));
  while (lines.at(-1) === "") lines.pop();

  const rateBytes = Math.round(settings.rateMbps * 1_000_000 / 8);
  const burstBytes = Math.round(settings.burstMbps * 1_000_000 / 8);
  lines.push(
    "",
    "# Dashboard-managed relay limits",
    `RelayBandwidthRate ${rateBytes} bytes`,
    `RelayBandwidthBurst ${burstBytes} bytes`,
  );
  if (!settings.unlimited) {
    lines.push(
      "",
      "# Monthly traffic limit",
      `AccountingMax ${Math.round(settings.quotaGB * 1_000_000_000)} bytes`,
      "AccountingRule sum",
      "AccountingStart month 1 00:00",
    );
  }
  if (settings.contactInfo) {
    lines.push("", "# Public operator contact", `ContactInfo email:${settings.contactInfo}`);
  }
  lines.push("");
  return lines.join("\r\n");
}

async function restartTor() {
  const command = [
    "Restart-Service -Name tor -Force -ErrorAction Stop",
    "$deadline=(Get-Date).AddSeconds(20)",
    "do { Start-Sleep -Milliseconds 500; $s=Get-Service -Name tor } while ($s.Status -ne 'Running' -and (Get-Date) -lt $deadline)",
    "if ($s.Status -ne 'Running') { throw 'Tor service did not start' }",
  ].join("; ");
  await execFileAsync("powershell.exe", ["-NoProfile", "-Command", command], {
    windowsHide: true,
    timeout: 30000,
  });
}

async function applySettings(input) {
  if (settingsBusy) throw new Error("Başka bir ayar işlemi sürüyor.");
  settingsBusy = true;
  const tempPath = `${torrcPath}.dashboard-new`;
  const backupPath = `${torrcPath}.dashboard-backup`;
  try {
    const settings = validateSettings(input);
    const current = await readFile(torrcPath, "utf8");
    const updated = renderTorrc(current, settings);
    await copyFile(torrcPath, backupPath);
    await writeFile(tempPath, updated, "utf8");
    await execFileAsync(torExe, ["--verify-config", "-f", tempPath], {
      windowsHide: true,
      timeout: 15000,
    });
    await rename(tempPath, torrcPath);
    try {
      await restartTor();
    } catch (error) {
      await copyFile(backupPath, torrcPath);
      await restartTor().catch(() => {});
      throw new Error(`Tor yeniden başlatılamadı; önceki ayarlar geri yüklendi. ${error.message}`);
    }
    return settings;
  } finally {
    settingsBusy = false;
  }
}

function send(res, statusCode, body, contentType) {
  res.writeHead(statusCode, {
    "Content-Type": contentType,
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Content-Security-Policy": "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'",
  });
  res.end(body);
}

function sendJson(res, statusCode, value) {
  send(res, statusCode, JSON.stringify(value), "application/json; charset=utf-8");
}

const server = createServer(async (req, res) => {
  const localRequest = isLoopback(req.socket.remoteAddress);
  const tailscaleRequest = isTailscale(req.socket.remoteAddress);
  const powerAllowed = localRequest || tailscaleRequest;
  try {
    const url = new URL(req.url || "/", `http://${req.headers.host || "127.0.0.1"}`);
    if (url.pathname === "/api/status" && req.method === "GET") {
      sendJson(res, 200, await buildStatus(localRequest, powerAllowed));
      return;
    }
    if (url.pathname === "/api/power" && req.method === "POST") {
      if (!powerAllowed) {
        sendJson(res, 403, { error: "Güç modu yalnızca bu bilgisayardan veya özel Tailscale ağından değiştirilebilir." });
        return;
      }
      const power = await setPowerMode(await parseBody(req));
      sendJson(res, 200, { ok: true, power });
      return;
    }
    if (url.pathname === "/api/memory/maintain" && req.method === "POST") {
      if (!powerAllowed) {
        sendJson(res, 403, { error: "Bellek bakımı yalnızca bu bilgisayardan veya özel Tailscale ağından başlatılabilir." });
        return;
      }
      const memoryMaintenance = await maintainMemory();
      sendJson(res, 200, { ok: true, memoryMaintenance });
      return;
    }
    if (url.pathname === "/api/settings" && req.method === "POST") {
      if (!localRequest) {
        sendJson(res, 403, { error: "Ayarlar güvenlik nedeniyle yalnızca Windows bilgisayarındaki localhost panelinden değiştirilebilir." });
        return;
      }
      await applySettings(await parseBody(req));
      sendJson(res, 200, { ok: true, status: await buildStatus(true, true) });
      return;
    }
    if (req.method !== "GET" && req.method !== "HEAD") {
      sendJson(res, 405, { error: "Method not allowed" });
      return;
    }
    const requested = url.pathname === "/" ? "dashboard.html" : decodeURIComponent(url.pathname.slice(1));
    const safePath = normalize(requested);
    const filePath = join(root, safePath);
    const relativePath = relative(normalize(root), filePath);
    if (relativePath.startsWith("..") || relativePath.includes(":")) {
      send(res, 403, "Forbidden", "text/plain; charset=utf-8");
      return;
    }
    await stat(filePath);
    const body = req.method === "HEAD" ? "" : await readFile(filePath);
    send(res, 200, body, mime[extname(filePath).toLowerCase()] || "application/octet-stream");
  } catch (error) {
    if (req.url?.startsWith("/api/")) {
      sendJson(res, 400, { error: error.message || "İşlem tamamlanamadı." });
    } else {
      send(res, 404, "Not found", "text/plain; charset=utf-8");
    }
  }
});

server.listen(port, "0.0.0.0", () => {
  console.log(`daakLOLILE: http://127.0.0.1:${port} (power control is limited to localhost and Tailscale)`);
});
