// models/changeRequest.js
const mongoose = require('mongoose');

const changeRequestSchema = new mongoose.Schema({
  employeeId: { type: String, required: true, index: true },
  full_name: { type: String },   // name of the employee whose profile is changing
  field: { type: String, required: true },         // e.g., "mobile_number", "dob"
  oldValue: { type: String },
  newValue: { type: String, required: true },
  requestedBy: { type: String },   // id of who requested the change
  requestedByName: { type: String }, // human name of requester
  requestedByRole: { type: String }, // role of who requested (employee/hr/founder/etc)
  approverRole: { type: String }, // who should approve (hr/founder/superadmin)
  status: { type: String, enum: ['pending','approved','declined'], default: 'pending' },
  createdAt: { type: Date, default: Date.now },
  resolvedAt: { type: Date },
  resolvedBy: { type: String }
});

// Keep model name consistent
const ChangeRequest = mongoose.models.ChangeRequest || mongoose.model('change_request', changeRequestSchema);
module.exports = ChangeRequest;