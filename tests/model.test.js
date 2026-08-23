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

console.log("model tests passed")
