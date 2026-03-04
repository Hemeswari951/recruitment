// backend/models/offerletter.js
const mongoose = require("mongoose");

const offerLetterSchema = new mongoose.Schema(
  {
    fullName: String,
    employeeId: String,
    position: String,
    stipend: String,
    joiningDate: String,
    // New: store salaryFrom (camelCase) — keep legacy `salaryfrom` too for backwards compatibility
    salaryFrom: String,
    signedDate: String,
    pdfUrl: String,
    email: String, // <-- ADD THIS
  },
  { timestamps: true }
);

module.exports =
  mongoose.models.OfferLetter ||
  mongoose.model("OfferLetter", offerLetterSchema);
