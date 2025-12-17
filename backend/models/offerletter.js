const mongoose = require("mongoose");

const offerLetterSchema = new mongoose.Schema(
  {
    fullName: String,
    employeeId: String,
    position: String,
    stipend: String,
    joiningDate: String,
    signedDate: String,
    pdfUrl: String,
  },
  { timestamps: true }
);

module.exports =
  mongoose.models.OfferLetter ||
  mongoose.model("OfferLetter", offerLetterSchema);
