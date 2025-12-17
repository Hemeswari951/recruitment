// backend/models/onCampusDrive.js
const mongoose = require('mongoose');

const StudentSchema = new mongoose.Schema({
  name: { type: String, default: '' },
  mobile: { type: String, default: '' },
  email: { type: String, default: '' },
  resumePath: { type: String, default: '' }, // relative path to uploaded file
  createdAt: { type: Date, default: Date.now }
});

const OnCampusDriveSchema = new mongoose.Schema({
  dateOfRecruitment: { type: Date, required: true },
  collegeName: { type: String, required: true },
  totalStudents: { type: Number, default: 0 },
  aptitudeSelected: { type: Number, default: 0 },
  techSelected: { type: Number, default: 0 },
  hrSelected: { type: Number, default: 0 },
  bgVerificationStatus: { type: String, enum: ['Pending', 'In Progress', 'Verified', 'Unable to Verify'], default: 'Pending' },
  selectedPosition: { type: String, enum: ['Intern', 'Tech Trainee'], default: 'Intern' },
  contactPerson: { type: String, default: '' },
  students: [StudentSchema],
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

OnCampusDriveSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model('OnCampusDrive', OnCampusDriveSchema);
