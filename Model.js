function defaultStatus() {
  return {
    ok: true,
    installed: false,
    devices: [],
    statusText: "KDE Connect is not installed"
  }
}

function parseStatus(raw) {
  var text = String(raw || "").trim()
  if (text === "") return defaultStatus()

  try {
    var parsed = JSON.parse(text)
    if (!parsed || typeof parsed !== "object") return defaultStatus()
    parsed.devices = Array.isArray(parsed.devices) ? parsed.devices : []
    return parsed
  } catch (error) {
    var failed = defaultStatus()
    failed.ok = false
    failed.statusText = "Could not read phone status"
    return failed
  }
}

function deviceSummary(devices) {
  if (!devices || devices.length === 0) return "No phone connected"
  if (devices.length === 1) return devices[0].name
  return devices.length + " phones connected"
}

if (typeof module !== "undefined") {
  module.exports = {
    defaultStatus: defaultStatus,
    parseStatus: parseStatus,
    deviceSummary: deviceSummary
  }
}
