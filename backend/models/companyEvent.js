//companyEvent.js

const mongoose = require('mongoose');

const companyEventSchema = new mongoose.Schema({
  title: { type: String, required: true },
  company: { type: String, default: 'ZeAI Soft' },
  description: { type: String },
  venue: { type: String, required: true },
  dateTime: { type: Date, required: true },
  specialGuest: { type: String },
  bannerUrl: { type: String },
}, { timestamps: true });

module.exports = mongoose.model('CompanyEvent', companyEventSchema);
