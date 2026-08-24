const assert = require("node:assert/strict")
const model = require("../Model.js")

assert.deepEqual(model.parseStatus(""), model.defaultStatus())
assert.equal(model.parseStatus("not json").ok, false)
assert.equal(model.deviceSummary([]), "No phone connected")
assert.equal(model.deviceSummary([{ name: "Pixel" }]), "Pixel")
assert.equal(model.deviceSummary([{ name: "Pixel" }, { name: "Tablet" }]), "2 phones connected")
assert.equal(model.batteryText({ battery: { charge: 71, charging: false } }), "71%")
assert.equal(model.batteryText({ battery: { charge: 42, charging: true } }), "42% · Charging")
assert.equal(model.connectivityText({ connectivity: { strength: 3, type: "5G" } }), "5G")
assert.equal(model.signalStrength({ connectivity: { strength: 3, type: "5G" } }), 3)
assert.equal(model.signalStrength({ connectivity: { strength: 4, type: "5G" } }), 4)
assert.equal(model.signalStrength({}), -1)
assert.equal(model.visibleNotifications([
  { appName: "Spotify", isConversation: false },
  { appName: "Messages", isConversation: true }
]).length, 1)
const searchableConversations = [
  { names: ["Alex Rivera"], addresses: ["+15550000001"], preview: "Dinner tonight" },
  { names: ["Sam"], addresses: ["+15550000002"], preview: "Project update" }
]
assert.equal(model.filterConversations(searchableConversations, "rivera").length, 1)
assert.equal(model.filterConversations(searchableConversations, "0002")[0].names[0], "Sam")
assert.equal(model.filterConversations(searchableConversations, "project").length, 1)
assert.equal(model.filterConversations(searchableConversations, "missing").length, 0)
const contacts = [{ name: "Alex Rivera", number: "+15550000001" }, { name: "Sam", number: "+15550000002" }]
assert.equal(model.parseContacts(JSON.stringify(contacts)).length, 2)
assert.equal(model.filterContacts(contacts, "rivera")[0].number, "+15550000001")
assert.equal(model.filterContacts(contacts, "0002")[0].name, "Sam")
assert.equal(model.filterContacts(contacts, "").length, 0)
assert.deepEqual(model.parseConversations("not json"), [])
assert.equal(model.parseConversations('[{"threadId":1}]').length, 1)
assert.equal(model.parseMessages('[{"body":"Hello"}]')[0].body, "Hello")
const updatedConversations = model.updateConversationAfterSend([
  { threadId: 1, preview: "Old", timestamp: 1000, incoming: true, unread: true },
  { threadId: 2, preview: "Other", timestamp: 1500 }
], 1, "Sent", 2000)
assert.equal(updatedConversations[0].threadId, 1)
assert.equal(updatedConversations[0].preview, "Sent")
assert.equal(updatedConversations[0].incoming, false)
assert.equal(updatedConversations[0].unread, false)
const smsUpdated = model.upsertConversationAfterSms([
  { threadId: 9, addresses: ["(555) 000-0001"], names: ["Becca"], preview: "Old", timestamp: 1000 }
], "+1 555 000 0001", "Becca", "New", 2000)
assert.equal(smsUpdated[0].threadId, 9)
assert.equal(smsUpdated[0].preview, "New")
assert.equal(smsUpdated[0].pendingSync, true)
const newSms = model.upsertConversationAfterSms([], "+15550000002", "New person", "Hello", 2000)[0]
assert.equal(newSms.pending, true)
assert.equal(newSms.threadId, null)
const staleMerge = model.mergePendingConversation([
  { threadId: 9, addresses: ["+15550000001"], preview: "Old", timestamp: 1000 }
], smsUpdated[0])
assert.equal(staleMerge.resolved, false)
assert.equal(staleMerge.conversations[0].preview, "New")
const freshMerge = model.mergePendingConversation([
  { threadId: 9, addresses: ["+15550000001"], preview: "New", timestamp: 2000 }
], smsUpdated[0])
assert.equal(freshMerge.resolved, true)
const pendingOutgoing = { body: "On my way", timestamp: 2000 }
const pendingMessageMerge = model.mergePendingOutgoing([
  { body: "Earlier", timestamp: 1000, incoming: true }
], pendingOutgoing)
assert.equal(pendingMessageMerge.resolved, false)
assert.equal(pendingMessageMerge.messages.length, 2)
assert.equal(pendingMessageMerge.messages[1].body, "On my way")
assert.equal(pendingMessageMerge.messages[1].pending, true)
const confirmedMessageMerge = model.mergePendingOutgoing([
  { body: "On my way", timestamp: 2500, incoming: false }
], pendingOutgoing)
assert.equal(confirmedMessageMerge.resolved, true)
assert.equal(confirmedMessageMerge.messages.length, 1)
const oldDuplicateMerge = model.mergePendingOutgoing([
  { body: "On my way", timestamp: 200000, incoming: false }
], pendingOutgoing)
assert.equal(oldDuplicateMerge.resolved, false)
assert.equal(oldDuplicateMerge.messages.length, 2)
assert.equal(model.findConversationByTitle(searchableConversations, "alex rivera").addresses[0], "+15550000001")
assert.equal(model.findConversationByTitle(searchableConversations, "+15550000002").names[0], "Sam")
assert.equal(model.findConversationByTitle(searchableConversations, "Nobody"), null)
assert.equal(model.findConversationByTitle(searchableConversations, ""), null)
assert.equal(model.conversationTitle({ addresses: ["+15551234567"] }), "+15551234567")
assert.equal(model.conversationTitle({ addresses: ["+15551234567"], names: ["Alex"] }), "Alex")
assert.equal(model.conversationTitle({ addresses: ["Alex", "Sam"] }), "Alex +1")
assert.equal(model.relativeTime(1000, 61000), "1m")

console.log("model tests passed")
