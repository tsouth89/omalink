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

function batteryText(device) {
  if (!device || !device.battery || device.battery.charge === null || device.battery.charge === undefined)
    return "Battery unavailable"
  return device.battery.charge + "%" + (device.battery.charging ? " · Charging" : "")
}

function connectivityText(device) {
  if (!device || !device.connectivity) return ""
  var type = String(device.connectivity.type || "")
  var strength = Number(device.connectivity.strength)
  var parts = []
  if (type !== "" && type !== "Unknown") parts.push(type)
  if (isFinite(strength) && strength >= 0) parts.push("Signal " + strength + "/4")
  return parts.join(" · ")
}

function parseConversations(raw) {
  try {
    var parsed = JSON.parse(String(raw || "[]"))
    return Array.isArray(parsed) ? parsed : []
  } catch (error) {
    return []
  }
}

function conversationTitle(conversation) {
  if (!conversation || !Array.isArray(conversation.addresses) || conversation.addresses.length === 0)
    return "Unknown sender"
  if (conversation.addresses.length === 1) return conversation.addresses[0]
  return conversation.addresses[0] + " +" + (conversation.addresses.length - 1)
}

function relativeTime(timestamp, now) {
  var value = Number(timestamp)
  if (!isFinite(value) || value <= 0) return ""
  var elapsed = Math.max(0, Number(now || Date.now()) - value)
  var minutes = Math.floor(elapsed / 60000)
  if (minutes < 1) return "Now"
  if (minutes < 60) return minutes + "m"
  var hours = Math.floor(minutes / 60)
  if (hours < 24) return hours + "h"
  var days = Math.floor(hours / 24)
  if (days < 7) return days + "d"
  var date = new Date(value)
  return (date.getMonth() + 1) + "/" + date.getDate()
}

if (typeof module !== "undefined") {
  module.exports = {
    defaultStatus: defaultStatus,
    parseStatus: parseStatus,
    deviceSummary: deviceSummary,
    batteryText: batteryText,
    connectivityText: connectivityText,
    parseConversations: parseConversations,
    conversationTitle: conversationTitle,
    relativeTime: relativeTime
  }
}
