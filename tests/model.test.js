const assert = require("node:assert/strict")
const model = require("../Model.js")

assert.deepEqual(model.parseStatus(""), model.defaultStatus())
assert.equal(model.parseStatus("not json").ok, false)
assert.equal(model.deviceSummary([]), "No phone connected")
assert.equal(model.deviceSummary([{ name: "Pixel" }]), "Pixel")
assert.equal(model.deviceSummary([{ name: "Pixel" }, { name: "Tablet" }]), "2 phones connected")
assert.equal(model.batteryText({ battery: { charge: 71, charging: false } }), "71%")
assert.equal(model.batteryText({ battery: { charge: 42, charging: true } }), "42% · Charging")
assert.equal(model.connectivityText({ connectivity: { strength: 3, type: "5G" } }), "5G · Signal 3/4")
assert.deepEqual(model.parseConversations("not json"), [])
assert.equal(model.parseConversations('[{"threadId":1}]').length, 1)
assert.equal(model.parseMessages('[{"body":"Hello"}]')[0].body, "Hello")
assert.deepEqual(model.appendSentMessage([], "Sent", 2000), [{ body: "Sent", timestamp: 2000, incoming: false, attachmentCount: 0 }])
const updatedConversations = model.updateConversationAfterSend([
  { threadId: 1, preview: "Old", timestamp: 1000, incoming: true, unread: true },
  { threadId: 2, preview: "Other", timestamp: 1500 }
], 1, "Sent", 2000)
assert.equal(updatedConversations[0].threadId, 1)
assert.equal(updatedConversations[0].preview, "Sent")
assert.equal(updatedConversations[0].incoming, false)
assert.equal(updatedConversations[0].unread, false)
assert.equal(model.conversationTitle({ addresses: ["+15551234567"] }), "+15551234567")
assert.equal(model.conversationTitle({ addresses: ["+15551234567"], names: ["Alex"] }), "Alex")
assert.equal(model.conversationTitle({ addresses: ["Alex", "Sam"] }), "Alex +1")
assert.equal(model.relativeTime(1000, 61000), "1m")

console.log("model tests passed")
