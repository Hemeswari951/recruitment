// backend/models/mailThread.js
const mongoose = require("mongoose");

const AttachmentSchema = new mongoose.Schema({
  filename: String,
  originalName: String,
  size: Number,
  mimeType: String,
  path: String,
}, { _id: false });

const RecipientSchema = new mongoose.Schema({
  employeeId: { type: String, required: true },
  employeeName: { type: String },
  employeeImage: { type: String },
}, { _id: false });

const MessageSchema = new mongoose.Schema({
  from: {
    employeeId: { type: String, required: true },
    employeeName: String,
    employeeImage: String,
  },
  to: [RecipientSchema],
  cc: [RecipientSchema],
  body: { type: String, default: "" },
  attachments: [AttachmentSchema],
}, { timestamps: true }); // creates createdAt for each message

const MailThreadSchema = new mongoose.Schema({
  subject: { type: String, default: "" },
  participants: [String], // array of employeeIds (uniq)
  messages: [MessageSchema],
  lastUpdated: { type: Date, default: Date.now },
  lastMessagePreview: { type: String, default: "" },
  readBy: [String],    // per-thread read state (optional)
  trashedBy: [String], // per-user trash at thread level (optional)
}, { timestamps: true });

module.exports = mongoose.model("MailThread", MailThreadSchema);