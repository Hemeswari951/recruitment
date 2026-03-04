const mongoose = require("mongoose");

const RevisedOfferLetterSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: true,
    },
    employeeId: {
      type: String,
      required: true,
      unique: true,
    },
    position: {
      type: String,
      required: true,
    },
    fromposition: {
      type: String,
      required: true,
    },
    stipend: { type: String, required: true },
    ctc: { type: String, required: true },
    doj: { type: String, required: true },
    signdate: { type: String, required: true },
    salaryFrom: { type: String, required: true },
    pdfFile: { type: String, required: true }, // Stores the Base64 encoded PDF
  },
  { timestamps: true }
);

module.exports = mongoose.model("RevisedOfferLetter", RevisedOfferLetterSchema);