// models/inviteTracker.js
const mongoose = require("mongoose");

const InviteTrackerSchema = new mongoose.Schema(
  {
    dateOfInvite: {
      type: String,     // Format: yyyy-MM-dd
      required: true,
    },

    collegeName: {
      type: String,
      required: true,
      trim: true,
    },

    totalStudents: {
      type: Number,
      default: 0,
    },

    contactPerson: {
      type: String,
      default: "",
    },

    dateOfRecruitment: {
      type: String,     // Format: yyyy-MM-dd
      default: "",
    },

    mode: {
      type: String,
      enum: ["On-campus", "Off-campus"],
      required: true,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("InviteTracker", InviteTrackerSchema);