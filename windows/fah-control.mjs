const command = process.argv[2] || "status";
const endpoint = "ws://127.0.0.1:7396/api/websocket";
const timeout = setTimeout(() => {
  console.error("Folding@home control connection timed out.");
  process.exit(2);
}, 7000);

function summarize(data) {
  const group = data.groups?.[""]?.config || {};
  const units = Array.isArray(data.units) ? data.units : [];
  const working = units.filter(unit =>
    ["ASSIGN", "DOWNLOAD", "CORE", "RUN", "UPLOAD"].includes(String(unit.state || "").toUpperCase())
  );
  return {
    connected: true,
    paused: group.paused === true,
    onIdle: group.on_idle === true,
    cpuThreads: Number(group.cpus) || 0,
    gpuEnabled: Object.values(group.gpus || {}).some(gpu => gpu?.enabled === true),
    units: units.length,
    workingUnits: working.length,
    progressPercent: Math.max(0, ...units.map(unit => Number(unit.progress ?? unit.wu_progress) || 0)) * 100,
    pointsPerDay: units.reduce((sum, unit) => sum + (Number(unit.ppd) || 0), 0),
  };
}

const socket = new WebSocket(endpoint);
let handled = false;

socket.onerror = () => {
  clearTimeout(timeout);
  console.error("Folding@home control connection failed.");
  process.exit(1);
};

socket.onmessage = event => {
  if (handled || String(event.data) === "\"ping\"") return;
  const data = JSON.parse(String(event.data));
  handled = true;

  if (command === "configure") {
    const supported = Object.entries(data.info?.gpus || {})
      .filter(([, value]) => value?.supported === true)
      .map(([id]) => id);
    const gpus = Object.fromEntries(supported.map(id => [id, { enabled: true }]));
    socket.send(JSON.stringify({
      cmd: "config",
      config: {
        groups: {
          "": {
            on_idle: true,
            on_battery: false,
            keep_awake: false,
            cpus: 2,
            gpus,
          },
        },
      },
    }));
    socket.send(JSON.stringify({ cmd: "state", state: "fold" }));
  } else if (command === "pause") {
    socket.send(JSON.stringify({ cmd: "state", state: "pause" }));
  } else if (command === "fold") {
    socket.send(JSON.stringify({ cmd: "state", state: "fold" }));
  }

  console.log(JSON.stringify(summarize(data)));
  clearTimeout(timeout);
  setTimeout(() => process.exit(0), command === "status" ? 0 : 600);
};
