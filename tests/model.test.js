const assert = require("node:assert/strict")
const model = require("../Model.js")

assert.deepEqual(model.parseStatus(""), model.defaultStatus())
assert.equal(model.parseStatus("not json").ok, false)
assert.equal(model.deviceSummary([]), "No phone connected")
assert.equal(model.deviceSummary([{ name: "Pixel" }]), "Pixel")
assert.equal(model.deviceSummary([{ name: "Pixel" }, { name: "Tablet" }]), "2 phones connected")

console.log("model tests passed")
