//routes/employee.js
const express = require("express");
const mongoose = require("mongoose");
const multer = require("multer");
const path = require("path");
const Attendance = require("../models/attendance");
const Employee = require("../models/employee"); // 🔹 merged schema we created earlier
const LeaveBalance = require("../models/leaveBalance");
const Profile = require("../models/profile");

const router = express.Router();
const fs = require("fs");

// Ensure uploads folder exists
const uploadDir = path.join(__dirname, "../uploads");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}


// ------------------ Multer Setup ------------------ //
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "uploads/"); // make sure this folder exists
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname).toLowerCase());
  },
});

// ✅ File filter: allow only jpg/jpeg images (case-insensitive)
const fileFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname).toLowerCase(); // lowercase extension
  if (ext === ".jpg" || ext === ".jpeg") {
    cb(null, true);
  } else {
    cb(new Error("Only .jpg or .jpeg files are allowed"), false);
  }
};

const upload = multer({ storage, fileFilter });

// 🔹 Utility: always return DD-MM-YYYY
function getToday() {
  const d = new Date();
  const day = String(d.getDate()).padStart(2, "0");
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const year = d.getFullYear();
  return `${day}-${month}-${year}`;
}

// ------------------ Routes ------------------ //

// ------------------ Employee Login ------------------ //
router.post("/employee-login", async (req, res) => {
  const { employeeId, employeeName, position,password } = req.body;

  if (!employeeId || !employeeName || !position || !password) {
    return res.status(400).json({ message: "All fields are required" });
  }

  try {
    // ✅ Case-insensitive search
    const employee = await Employee.findOne({
      employeeId: employeeId.trim(),
      employeeName: { $regex: `^${employeeName.trim()}$`, $options: "i" },
      position: { $regex: `^${position.trim()}$`, $options: "i" },
    });

    if (!employee) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    // ✅ Check password match
    if(employee.password !== password){
      return res.status(401).json({message:"Invalid password"});
    }


    // ✅ Ensure LeaveBalance exists
    await LeaveBalance.updateOne(
      { employeeId: employee.employeeId, year: new Date().getFullYear() },
      {
        $setOnInsert: {
          employeeId: employee.employeeId,
          year: new Date().getFullYear(),
          balances: {
            casual: { total: 12, taken: 0 },
            sick: { total: 12, taken: 0 },
            sad: { total: 12, taken: 0 },
          },
        },
      },
      { upsert: true }
    );

    res.status(201).json({
      message: "✅ Login Successful",
      employeeId: employee.employeeId,
      employeeName: employee.employeeName,
      position: employee.position,
      role: employee.role || "employee",
    });
  } catch (err) {
    console.error("❌ Error during login:", err);
    res.status(500).json({ message: "Server error", error: err.message });
  }
});

// ✅ Get all employees (today OR last working day)
router.get("/employees", async (req, res) => {
  try {
    const employees = await Employee.find().sort({ createdAt: -1 });
    const today = getToday();

    const result = await Promise.all(
      employees.map(async (emp) => {
        const lastAttendance = await Attendance.findOne({
          employeeId: emp.employeeId,
        }).sort({ createdAt: -1 });

        // Fetch Profile for extra details
        const profile = await Profile.findOne({ id: emp.employeeId }).select("date_of_appointment work_email_id");

        let status = "N/A";
        let loginTime = "Not logged in yet";
        let logoutTime = "Not logged out yet";
        let date = today;

        if (lastAttendance) {
          date = lastAttendance.date;
          status = lastAttendance.status;
          loginTime = lastAttendance.loginTime || loginTime;
          logoutTime = lastAttendance.logoutTime || logoutTime;
        }

        return {
          ...emp.toObject(),
          status,
          loginTime,
          logoutTime,
          date,
          dateOfAppointment: profile ? profile.date_of_appointment : "",
          workEmail: profile ? profile.work_email_id : "",
        };
      })
    );

    res.json(result);
  } catch (err) {
    console.error("❌ Error fetching employees with status:", err);
    res.status(500).json({ message: "Server error" });
  }
});

// ✅ Get employees by domain (for TL performance reviews)
router.get("/employees/domain/:domain", async (req, res) => {
  try {
    const { domain } = req.params;
    const employees = await Employee.find(
      {
        domain: domain,
        position: { $in: [/^employee$/i, /^intern$/i, /^tech trainee$/i] }, // ✅ Case-insensitive
      },
      "employeeId employeeName" // Select only these fields
    );
    res.json(employees);
  } catch (err) {
    res.status(500).json({ message: "❌ Server error fetching employees by domain" });
  }
});

// ✅ Get employees for Superadmin/HR review (only employees and interns)
router.get("/employees/for-review/:reviewerPosition", async (req, res) => {
  try {
    const reviewerPosition = (req.params.reviewerPosition || "").toLowerCase();
    let positionsToFind = [];

    if (reviewerPosition === 'founder') {
      // Founder reviews HR
      positionsToFind = [/^HR$/i,/^TL$/i];
    } else if (reviewerPosition === 'superadmin' || reviewerPosition === 'hr') {
      // Superadmin and HR review TLs and Admins
      positionsToFind = [/^TL$/i, /^Admin$/i];
    }

    const employees = await Employee.find({
      position: { $in: positionsToFind }
    }, "employeeId employeeName");
    res.json(employees);
  } catch (err) {
    res.status(500).json({ message: "❌ Server error fetching employees for review" });
  }
});


// ✅ Get single employee
router.get("/employees/:employeeId", async (req, res) => {
  try {
    const emp = await Employee.findOne({ employeeId: req.params.employeeId });
    if (!emp) {
      return res.status(404).json({ message: "❌ Employee not found" });
    }

    const today = getToday();
    const lastAttendance = await Attendance.findOne({
      employeeId: emp.employeeId,
    }).sort({ createdAt: -1 });

    let status = "Absent";
    let loginTime = "Not logged in yet";
    let logoutTime = "Not logged out yet";
    let date = today;

    if (lastAttendance) {
      date = lastAttendance.date;
      status = lastAttendance.status;
      loginTime = lastAttendance.loginTime || loginTime;
      logoutTime = lastAttendance.logoutTime || logoutTime;
    }

    res.json({
      ...emp.toObject(),
      status,
      loginTime,
      logoutTime,
      date,
    });
  } catch (err) {
    console.error("❌ Error fetching employee with status:", err);
    res.status(500).json({ message: "Server error" });
  }
});

// ✅ Add new employee + optional image
router.post("/employees", upload.single("employeeImage"), async (req, res) => {
  try {
    const { employeeId, employeeName, position, domain ,password, dateOfAppointment, workEmail } = req.body;

    if (!employeeId || !employeeName || !position || !domain || !password) {
      return res.status(400).json({ message: "⚠ All fields are required" });
    }

    const existing = await Employee.findOne({ employeeId });
    if (existing) {
      return res.status(409).json({ message: "❌ Employee ID already exists" });
    }

    const newEmployee = new Employee({
      employeeId,
      employeeName,
      position,
      domain,
      password,
      employeeImage: req.file ? `/uploads/${req.file.filename}` : null,
    });

    await newEmployee.save();
// Check if profile already exists
const existingProfile = await Profile.findOne({ id: employeeId });

if (!existingProfile) {
  await Profile.create({
    id: employeeId,
    full_name: employeeName,
    designation: position,
    department: domain,
    password: password,
    date_of_appointment: dateOfAppointment,
    work_email_id: workEmail
  });
}

    res.status(201).json({
      message: "✅ Employee added successfully",
      employee: newEmployee,
    });
  } catch (err) {
    console.error("❌ Error adding employee:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// ✅ Add new employees in bulk from Excel
router.post("/employees/bulk", async (req, res) => {
  const employeesData = req.body;
  if (!Array.isArray(employeesData) || employeesData.length === 0) {
    return res.status(400).json({ message: "Request body must be a non-empty array of employees." });
  }

  let successCount = 0;
  let failureCount = 0;
  const errors = [];

  for (const empData of employeesData) {
    try {
      const { employeeId, employeeName, position, domain, password, dateOfAppointment, workEmail } = empData;

      if (!employeeId || !employeeName || !position || !domain || !password) {
        failureCount++;
        errors.push(`Skipped row due to missing required fields (ID: ${employeeId || 'N/A'})`);
        continue;
      }

      const existing = await Employee.findOne({ employeeId });
      if (existing) {
        failureCount++;
        errors.push(`Employee ID ${employeeId} already exists.`);
        continue;
      }

      const newEmployee = new Employee({ employeeId, employeeName, position, domain, password, employeeImage: null });
      await newEmployee.save();

      const existingProfile = await Profile.findOne({ id: employeeId });
      if (!existingProfile) {
        await Profile.create({
          id: employeeId,
          full_name: employeeName,
          designation: position,
          department: domain,
          password: password,
          date_of_appointment: dateOfAppointment,
          work_email_id: workEmail
        });
      }
      successCount++;
    } catch (err) {
      failureCount++;
      const empId = empData.employeeId || 'unknown';
      errors.push(`Error for employee ${empId}: ${err.message}`);
    }
  }

  res.status(200).json({ message: "Bulk import process completed.", successCount, failureCount, errors });
});

// ✅ Update employee
router.put("/employees/:id", upload.single("employeeImage"), async (req, res) => {
  try {
    const { employeeName, position, domain  ,password, dateOfAppointment, workEmail} = req.body;

    const updateData = {};
    if (employeeName) updateData.employeeName = employeeName;
    if (position) updateData.position = position;
    if (domain) updateData.domain = domain;
    if (password) updateData.password = password;
    if (req.file) {
      updateData.employeeImage = `/uploads/${req.file.filename}`;
    }

    const updated = await Employee.findOneAndUpdate(
      { employeeId: req.params.id },
      { $set: updateData },
      { new: true }
    );

    // Update Profile
    const profileUpdate = {
      designation: updated.position,
      department: updated.domain,
      full_name: updated.employeeName
    };
    if (password) profileUpdate.password = password;
    if (dateOfAppointment) profileUpdate.date_of_appointment = dateOfAppointment;
    if (workEmail) profileUpdate.work_email_id = workEmail;

    await Profile.findOneAndUpdate({ id: req.params.id }, { $set: profileUpdate });

    if (!updated) {
      return res.status(404).json({ message: "Employee not found" });
    }


    // 🟢 Debugging start
    console.log("🟢 Reached update route for ID:", req.params.id);
    console.log("🟢 Request body received:", req.body);
    console.log("🟢 Password value:", req.body.password);

    res.json({
      message: "✅ Employee updated successfully",
      employee: updated,
    });
  } catch (err) {
    console.error("❌ Error updating employee:", err);
    res.status(500).json({ message: "❌ Error updating employee" });
  }
});

// ✅ Delete employee (and attendance)
router.delete("/employees/:id", async (req, res) => {
  try {
    const deleted = await Employee.findOneAndDelete({
      employeeId: req.params.id,
    });

    if (!deleted) {
      return res.status(404).json({ message: "Employee not found" });
    }

    await Attendance.deleteMany({ employeeId: req.params.id });

    res.json({
      message: "✅ Employee and attendance deleted successfully",
    });
  } catch (err) {
    console.error("❌ Error deleting employee:", err);
    res.status(500).json({ message: "❌ Error deleting employee" });
  }
});
// 🔍 Search employees by partial name
router.get("/employees/search/:query", async (req, res) => {
  try {
    const q = req.params.query;

    const employees = await Employee.find(
      {
        employeeName: { $regex: q, $options: "i" }, // case-insensitive search
      },
      "employeeId employeeName position employeeImage"
    );

    res.json(employees);
  } catch (err) {
    console.error("❌ Error searching employees:", err);
    res.status(500).json({ message: "Server error" });
  }
});



// ✅ Get all unique domains (for dropdowns / filters)
router.get("/domains", async (req, res) => {
  try {
    const domains = await Employee.distinct("domain");
    res.json(domains);
  } catch (err) {
    console.error("❌ Error fetching domains:", err);
    res.status(500).json({ message: "Server error fetching domains" });
  }
});

module.exports = router;