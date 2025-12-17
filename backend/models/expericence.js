// backend/model/expericence.js
const mongoose = require('mongoose');

const ExperienceSchema = new mongoose.Schema({
  companyName: { type: String, default: 'ZeAI Soft' },
  fullName: { type: String, required: true },
  position: { type: String, required: true },
  startDate: { type: String, required: true }, // dd/MM/yyyy or ISO string
  endDate: { type: String, required: true },
  issuedAt: { type: Date, default: Date.now },
  pdfPath: { type: String }, // optional: file path or URL
}, {
  timestamps: true
});

module.exports = mongoose.model('Expericence', ExperienceSchema);
