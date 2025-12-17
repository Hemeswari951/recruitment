const mongoose = require("mongoose");

const ExitDetailsSchema = new mongoose.Schema({
  employeeId: { type: String, required: true },
  name: { type: String, required: true },
  position: { type: String, required: true },

  resignationDate: { type: Date },
  acceptanceDate: { type: Date },

  noticePeriod: { type: String },
  experience: { type: String },
  reason: { type: String },

  exitDocument: { type: String },  // <--- FIXED (Missing field)

  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model("ExitDetails", ExitDetailsSchema);