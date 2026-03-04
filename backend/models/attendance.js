// models/attendance.js
const mongoose = require("mongoose");

const attendanceSchema = new mongoose.Schema(
  {
    employeeId: {
      type: String,
      required: true,
      trim: true,
    },

    // ✅ Always store date as DD-MM-YYYY string (to match frontend)
    date: {
      type: String,
      required: true,
      trim: true,
    },

    // ✅ Time fields as formatted strings (e.g. "09:02:45 AM")
    loginTime: {
      type: String,
      default: "",
    },
    logoutTime: {
      type: String,
      default: "",
    },

    // ✅ Reasons — keep optional but default to "-"
    loginReason: {
      type: String,
      default: "-",
      trim: true,
    },
    logoutReason: {
      type: String,
      default: "-",
      trim: true,
    },

    // ✅ Stores all breaks (e.g. "10:15 AM to 10:30 AM (15 mins), 1:00 PM to 1:10 PM (10 mins) (Total: 25 mins)")
    breakTime: {
      type: String,
      default: "-",
    },

    // ✅ Temporary field used while a break is in progress
    breakInProgress: {
      type: String,
      default: null, // null when not on break
    },

    // ✅ Dynamic attendance state
    status: {
      type: String,
      enum: ["None", "Login", "Logout", "Break"],
      default: "None",
    },
    attendanceType: {
      type: String,
      enum: ["P", "HL", "A"],
      default: "P", // 🔥 important
    },
  },
  { timestamps: true } // ✅ createdAt & updatedAt for sorting
);

module.exports = mongoose.model("Attendance", attendanceSchema);