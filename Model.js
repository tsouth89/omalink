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
  return type !== "Unknown" ? type : ""
}

function signalStrength(device) {
  if (!device || !device.connectivity) return -1
  var strength = Number(device.connectivity.strength)
  return isFinite(strength) && strength >= 0 ? Math.floor(strength) : -1
}

function visibleNotifications(notifications) {
  if (!Array.isArray(notifications)) return []
  return notifications.filter(function(notification) {
    var app = String((notification && notification.appName) || "").toLowerCase()
    return !(app === "spotify" && !notification.isConversation)
  })
}

function filterConversations(conversations, query) {
  if (!Array.isArray(conversations)) return []
  var needle = String(query || "").trim().toLowerCase()
  if (needle === "") return conversations
  return conversations.filter(function(conversation) {
    var values = []
    if (conversation && conversation.names) values = values.concat(conversation.names)
    if (conversation && conversation.addresses) values = values.concat(conversation.addresses)
    values.push(conversation ? conversation.preview : "")
    return values.join("\n").toLowerCase().indexOf(needle) !== -1
  })
}

function parseContacts(raw) {
  return parseConversations(raw)
}

function filterContacts(contacts, query) {
  if (!Array.isArray(contacts)) return []
  var needle = String(query || "").trim().toLowerCase()
  if (needle === "") return []
  return contacts.filter(function(contact) {
    return (String(contact.name || "") + "\n" + String(contact.number || ""))
      .toLowerCase().indexOf(needle) !== -1
  })
}

function parseConversations(raw) {
  try {
    var parsed = JSON.parse(String(raw || "[]"))
    return Array.isArray(parsed) ? parsed : []
  } catch (error) {
    return []
  }
}

function parseMessages(raw) {
  return parseConversations(raw)
}

function updateConversationAfterSend(conversations, threadId, body, timestamp) {
  if (!Array.isArray(conversations)) return []
  var updated = null
  var remaining = []
  for (var i = 0; i < conversations.length; i++) {
    var conversation = conversations[i]
    if (!updated && Number(conversation.threadId) === Number(threadId)) {
      updated = {}
      for (var key in conversation) updated[key] = conversation[key]
      updated.preview = String(body || "")
      updated.timestamp = Number(timestamp)
      updated.incoming = false
      updated.unread = false
    } else {
      remaining.push(conversation)
    }
  }
  return updated ? [updated].concat(remaining) : conversations.slice()
}

function phoneKey(value) {
  var digits = String(value || "").replace(/[^0-9]/g, "")
  return digits.length > 10 ? digits.slice(-10) : digits
}

function conversationMatchesNumber(conversation, number) {
  if (!conversation || !Array.isArray(conversation.addresses)) return false
  var key = phoneKey(number)
  if (key === "") return false
  for (var i = 0; i < conversation.addresses.length; i++) {
    if (phoneKey(conversation.addresses[i]) === key) return true
  }
  return false
}

function upsertConversationAfterSms(conversations, number, name, body, timestamp) {
  var current = Array.isArray(conversations) ? conversations : []
  var updated = null
  var remaining = []
  for (var i = 0; i < current.length; i++) {
    var conversation = current[i]
    if (!updated && conversationMatchesNumber(conversation, number)) {
      updated = {}
      for (var key in conversation) updated[key] = conversation[key]
    } else {
      remaining.push(conversation)
    }
  }
  if (!updated) {
    updated = {
      threadId: null,
      addresses: [String(number || "")],
      names: [String(name || number || "")],
      attachmentCount: 0,
      pending: true
    }
  }
  updated.preview = String(body || "")
  updated.timestamp = Number(timestamp)
  updated.incoming = false
  updated.unread = false
  updated.pendingSync = true
  return [updated].concat(remaining)
}

function mergePendingConversation(conversations, pending) {
  var current = Array.isArray(conversations) ? conversations : []
  if (!pending || !pending.addresses || pending.addresses.length === 0)
    return { conversations: current, resolved: true }

  var matchIndex = -1
  for (var i = 0; i < current.length; i++) {
    if (conversationMatchesNumber(current[i], pending.addresses[0])) {
      matchIndex = i
      break
    }
  }
  if (matchIndex >= 0) {
    var match = current[matchIndex]
    if (Number(match.timestamp) >= Number(pending.timestamp) || match.preview === pending.preview)
      return { conversations: current, resolved: true }
    var withoutStale = current.slice()
    withoutStale.splice(matchIndex, 1)
    return { conversations: [pending].concat(withoutStale), resolved: false }
  }
  return { conversations: [pending].concat(current), resolved: false }
}

function mergePendingOutgoing(messages, pending) {
  var current = Array.isArray(messages) ? messages : []
  if (!pending) return { messages: current, resolved: true }

  for (var i = 0; i < current.length; i++) {
    var message = current[i]
    if (message && message.incoming === false
        && String(message.body || "") === String(pending.body || "")
        && Math.abs(Number(message.timestamp) - Number(pending.timestamp)) <= 120000)
      return { messages: current, resolved: true }
  }

  var optimistic = {
    body: String(pending.body || ""),
    timestamp: Number(pending.timestamp),
    incoming: false,
    attachmentCount: 0,
    pending: true
  }
  var merged = current.concat([optimistic])
  merged.sort(function(left, right) { return Number(left.timestamp) - Number(right.timestamp) })
  return { messages: merged, resolved: false }
}

function findConversationByTitle(conversations, title) {
  if (!Array.isArray(conversations)) return null
  var needle = String(title || "").trim().toLowerCase()
  if (needle === "") return null
  for (var i = 0; i < conversations.length; i++) {
    var conversation = conversations[i]
    if (!conversation) continue
    var values = []
    if (conversation.names) values = values.concat(conversation.names)
    if (conversation.addresses) values = values.concat(conversation.addresses)
    for (var j = 0; j < values.length; j++) {
      if (String(values[j]).trim().toLowerCase() === needle) return conversation
    }
  }
  return null
}

function conversationTitle(conversation) {
  if (!conversation) return "Unknown sender"
  var values = conversation.names && conversation.names.length ? conversation.names : conversation.addresses
  if (!values || !values.length)
    return "Unknown sender"
  if (values.length === 1) return String(values[0])
  return String(values[0]) + " +" + (values.length - 1)
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
    signalStrength: signalStrength,
    visibleNotifications: visibleNotifications,
    filterConversations: filterConversations,
    parseContacts: parseContacts,
    filterContacts: filterContacts,
    parseConversations: parseConversations,
    parseMessages: parseMessages,
    updateConversationAfterSend: updateConversationAfterSend,
    phoneKey: phoneKey,
    conversationMatchesNumber: conversationMatchesNumber,
    upsertConversationAfterSms: upsertConversationAfterSms,
    mergePendingConversation: mergePendingConversation,
    mergePendingOutgoing: mergePendingOutgoing,
    findConversationByTitle: findConversationByTitle,
    conversationTitle: conversationTitle,
    relativeTime: relativeTime
  }
}
