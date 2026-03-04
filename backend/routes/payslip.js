// routes/payslip.js
const express = require("express");
const router = express.Router();
const Payslip = require("../schema/payslip");
 // ✅ importing from your existing file



router.get('/hr/employees', async (req, res) => {
  try {
    const employees = await Payslip.find({}, {
      employee_id: 1,
      employee_name: 1,
      designation: 1,
      location: 1
    });

    res.json(employees);
  } catch (err) {
    res.status(500).json({ message: "Failed to fetch employees" });
  }
});

module.exports = router;