require('dotenv').config();

const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');

// ---------------- MODELS ---------------- //
const Employee = require('./models/employee');
const LeaveBalance = require('./models/leaveBalance');
const Payslip = require('./schema/payslip');

// ---------------- ROUTES ---------------- //
const employeeRoutes = require('./routes/employee');
const leaveRoutes = require('./routes/leave');
const profileRoutes = require('./routes/profile_route');
const todoRoutes = require('./routes/todo');
const attendanceRoutes = require('./routes/attendance');
const performanceRoutes = require('./routes/performance');
const reviewRiver = require('./routes/adminperformance');
const reviewscreen = require('./routes/reviewRoutes');
const reviewDecisionRoutes = require('./routes/performanceDecision');
const notificationRoutes = require('./routes/notifications');
const requestsRoutes = require('./routes/changeRequests');
const uploadRoutes = require('./routes/upload');
const payslipRoutes = require('./routes/payslip');

// ---------------- EXPRESS APP SETUP ---------------- //
const app = express();
const PORT =5000;
const MONGO_URI = 'mongodb://localhost:27017/Demo_Db';

// ---------------- MIDDLEWARE ---------------- //
app.use((req, res, next) => {
  console.log(`📥 ${req.method} ${req.originalUrl}`);
  next();
});

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// ---------------- ROUTES ---------------- //
app.use('/api', employeeRoutes);
app.use('/apply', leaveRoutes);
app.use('/profile', profileRoutes);
app.use('/todo_planner', todoRoutes);
app.use('/attendance', attendanceRoutes);
app.use('/perform', performanceRoutes);
app.use('/reviews', reviewRiver);
app.use('/reports', reviewscreen);
app.use('/review-decision', reviewDecisionRoutes);
app.use('/notifications', notificationRoutes);
app.use('/requests', requestsRoutes);
app.use('/upload', uploadRoutes);
app.use('/payslip', payslipRoutes);

// ---------------- PAYSLIP APIs ---------------- //
app.get('/get-payslip-details', async (req, res) => {
  try {
    const { employee_id, year, month } = req.query;
    const payslip = await Payslip.findOne({ employee_id });
    if (!payslip) return res.status(404).json({ message: 'Payslip not found' });

    const yearData = payslip.data_years.find(y => y.year === year);
    if (!yearData) return res.status(404).json({ message: 'Year not found' });

    const monthKey = month.toLowerCase().slice(0, 3);
    const monthData = yearData.months[monthKey];
    if (!monthData) return res.status(404).json({ message: 'Month data not found' });

    res.json({
      employee_name: payslip.employee_name,
      employee_id: payslip.employee_id,
      date_of_joining: payslip.date_of_joining,
      no_of_workdays: payslip.no_of_workdays,
      designation: payslip.designation,
      bank_name: payslip.bank_name,
      account_no: payslip.account_no,
      location: payslip.location,
      pan: payslip.pan,
      uan: payslip.uan,
      esic_no: payslip.esic_no,
      lop: payslip.lop,
      earnings: monthData.earnings,
      deductions: monthData.deductions,
    });
  } catch (error) {
    console.error('❌ Fetch Payslip Error:', error);
    res.status(500).json({ message: '❌ Failed to fetch payslip data', error: error.message });
  }
});

app.post('/get-multiple-payslips', async (req, res) => {
  try {
    const { employee_id, year, months } = req.body;
    if (!employee_id || !year || !Array.isArray(months)) {
      return res.status(400).json({ message: 'Missing or invalid fields' });
    }

    const payslip = await Payslip.findOne({ employee_id });
    if (!payslip) return res.status(404).json({ message: 'Employee not found' });

    const yearData = payslip.data_years.find(y => y.year === year);
    if (!yearData) return res.status(404).json({ message: 'Year not found' });

    const results = {};
    months.forEach(month => {
      const monthKey = month.toLowerCase().slice(0, 3);
      const monthData = yearData.months[monthKey];
      if (monthData) results[monthKey] = monthData;
    });

    res.status(200).json({
      employeeInfo: {
        employee_name: payslip.employee_name,
        employee_id: payslip.employee_id,
        date_of_joining: payslip.date_of_joining,
        no_of_workdays: payslip.no_of_workdays,
        designation: payslip.designation,
        bank_name: payslip.bank_name,
        account_no: payslip.account_no,
        location: payslip.location,
        pan: payslip.pan,
        uan: payslip.uan,
        esic_no: payslip.esic_no,
        lop: payslip.lop,
      },
      months: results,
    });
  } catch (error) {
    console.error('❌ Get Multiple Payslips Error:', error);
    res.status(500).json({ message: '❌ Failed to fetch payslip data', error: error.message });
  }
});

// ---------------- GET EMPLOYEE NAME ---------------- //
app.get('/get-employee-name/:employeeId', async (req, res) => {
  try {
    const employee = await Employee.findOne({ employeeId: req.params.employeeId.trim() });
    if (!employee) return res.status(404).json({ message: 'Employee not found' });

    res.status(200).json({
      employeeName: employee.employeeName,
      position: employee.position,
    });
  } catch (error) {
    console.error('❌ Get Employee Name Error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// ---------------- ROOT ROUTE (for testing Render) ---------------- //
app.get('/', (req, res) => {
  res.send('✅ HRM Backend is running successfully!');
});

// ---------------- CONNECT MONGODB & START SERVER ---------------- //
mongoose.connect(MONGO_URI)
  .then(() => {
    console.log('✅ MongoDB connected');
    app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
  })
  .catch(err => console.error('❌ MongoDB connection error:', err));
