// backend/models/draft.js
const mongoose = require("mongoose");

const AttachmentSchema = new mongoose.Schema({
  filename: String,
  originalName: String,
  size: Number,
  mimeType: String,
  path: String,
}, { _id: false });

const DraftSchema = new mongoose.Schema({
  from: { type: String, required: true }, // employeeId
  to: [String], // employeeIds
  cc: [String],
  bcc: [String],
  subject: { type: String, default: "" },
  body: { type: String, default: "" },
  attachments: [AttachmentSchema],
}, { timestamps: true });

module.exports = mongoose.model("Draft", DraftSchema);