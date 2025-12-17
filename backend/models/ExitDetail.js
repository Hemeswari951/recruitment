// models/ExitDetail.js
const mongoose = require('mongoose');

const ExitDetailSchema = new mongoose.Schema({
  employeeId: { type: String, required: true, index: true },
  name: { type: String, required: false },
  position: { type: String, required: false },
  resignationDate: { type: Date, required: false },
  acceptanceDate: { type: Date, required: false },
  noticePeriod: { type: String, required: false },
  experience: { type: String, required: false },
  reason: { type: String, required: false },
  createdBy: { type: String, required: false } // optional
}, {
  timestamps: true
});

module.exports = mongoose.model('ExitDetail', ExitDetailSchema);
