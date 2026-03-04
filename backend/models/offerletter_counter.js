//backend/models/offerletter_counter.js
const mongoose = require("mongoose");

const counterSchema = new mongoose.Schema({
  key: { type: String, required: true, unique: true },
  lastNumber: { type: Number, default: 152 } // Starting number
});

module.exports = mongoose.model("Counter", counterSchema);
