//models/employee.js
const mongoose = require("mongoose");

// --- Experience Schema ---
const experienceSchema = new mongoose.Schema({
  company_name: { type: String, required: true },
  role: { type: String, required: true },
  start_date: { type: String, required: true },
  end_date: { type: String, required: true },
  description: { type: String },
}, { _id: false });

// --- Employee Schema ---
const employeeSchema = new mongoose.Schema({
  employeeId: { type: String, required: true, unique: true, trim: true }, // unified from both schemas
  employeeName: { type: String, required: true, trim: true }, // from addemployee
  position: { type: String, required: true, trim: true },    // from addemployee
  domain: { type: String, required: true, trim: true },
  password: { type: String, required: true, trim: true },      // from addemployee
  employeeImage: { type: String, default: null },            // from addemployee

  
}, { timestamps: true });

// --- Model Export ---
const Employee = mongoose.models.Employee || mongoose.model("Employee", employeeSchema, "employees");
module.exports = Employee;