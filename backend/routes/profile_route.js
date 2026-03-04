// routes/profile_route.js
const express = require('express');
const router = express.Router();
const Profile = require('../models/profile');
const ExcelJS = require('exceljs');

// --- CREATE EMPLOYEE ---
router.post('/', async (req, res) => {
  try {
    const employee = new Profile(req.body);
    await employee.save();
    res.status(201).json({ message: '✅ Employee created successfully', employee });
  } catch (error) {
    console.error('❌ Failed to create employee:', error.message);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.get('/:id/excel', async (req, res) => {
  try {
    const profile = await Profile.findOne({ id: req.params.id }).lean();
    if (!profile) return res.status(404).send("Not found");

    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Full Profile');

    worksheet.columns = [
      { header: 'Field', key: 'field', width: 30 },
      { header: 'Value', key: 'value', width: 50 },
    ];

    const excludedFields = ['_id', '__v', 'createdAt', 'updatedAt'];

    Object.keys(profile).forEach(key => {
      if (excludedFields.includes(key)) return;

      const value = profile[key];

      if (key === "experiences" && Array.isArray(value)) {
        value.forEach((exp, index) => {
          Object.keys(exp).forEach(expKey => {
            if (expKey !== "_id") {
              worksheet.addRow({
                field: `Experience ${index + 1} - ${formatKey(expKey)}`,
                value: exp[expKey]
              });
            }
          });
        });
      }

      else if (typeof value === "object" && value !== null) {
        Object.keys(value).forEach(subKey => {
          worksheet.addRow({
            field: `${formatKey(key)} - ${formatKey(subKey)}`,
            value: value[subKey]
          });
        });
      }

      else {
        worksheet.addRow({
          field: formatKey(key),
          value: value || "Not Provided"
        });
      }
    });

    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    );

    res.setHeader(
      'Content-Disposition',
      `attachment; filename=${profile.full_name}_profile.xlsx`
    );

    await workbook.xlsx.write(res);
    res.end();

  } catch (error) {
    console.error("Excel export error:", error);
    res.status(500).send("Server Error");
  }
});
// --- GET EMPLOYEE BY ID (Flatten profileDocs for Flutter) ---
router.get('/:id', async (req, res) => {
  try {
    const employee = await Profile.findOne({ id: req.params.id }).lean();

    // if (!employee) {
    //   return res.status(404).json({ message: '❌ Employee not found' });
    // }
    if (!employee) {
  const Employee = require('../models/employee');
  const emp = await Employee.findOne({ employeeId: req.params.id });

  if (!emp) {
    return res.status(404).json({ message: '❌ Employee not found' });
  }

  const newProfile = await Profile.create({
    id: emp.employeeId,
    full_name: emp.employeeName,
    designation: emp.position,
    department: emp.domain,
    password: emp.password
  });

  return res.status(200).json(newProfile);
}

    res.status(200).json(employee);
  } catch (error) {
    console.error('❌ Failed to fetch employee:', error.message);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});


    
// --- GET ALL EMPLOYEES ---
router.get('/', async (req, res) => {
  try {
    const employees = await Profile.find().lean();
    res.status(200).json(employees);
  } catch (error) {
    console.error('❌ Failed to fetch all employees:', error.message);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// --- FULL UPDATE EMPLOYEE ---
router.put('/:id', async (req, res) => {
  try {
    const updatedEmployee = await Profile.findOneAndUpdate(
      { id: req.params.id },
      req.body,
      { new: true }
    );

    if (!updatedEmployee) {
      return res.status(404).json({ message: '❌ Employee not found' });
    }



    // 🟢 Debug logs
    console.log("🟢 Profile update request received for ID:", req.params.id);
    console.log("🟢 Body received:", req.body);
    console.log("🟢 Password value:", req.body.password);


    // 🔴 ADD THIS PART BELOW - to sync password to Employee collection
    if (req.body.password  !== undefined) {
      const Employee = require('../models/employee');
      const result = await Employee.findOneAndUpdate(
        { employeeId: req.params.id },
        { $set: { password: req.body.password } }
      );

      if (result) {
        console.log("✅ Password synced successfully to Employee collection");
      } else {
        console.warn("⚠️ Employee not found in Employee collection during sync");
      }
    }
    

    res.status(200).json({ message: '✅ Employee updated', employee: updatedEmployee });
  } catch (error) {
    console.error('❌ Failed to update employee:', error.message);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

router.get('/:id/download', async (req, res) => {
  try {
    const profile = await Profile.findOne({ id: req.params.id }).lean();
    if (!profile) return res.status(404).send("Not found");

    const PDFDocument = require('pdfkit');
    const doc = new PDFDocument({ margin: 40 });

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename=${profile.full_name}_profile.pdf`
    );

    doc.pipe(res);

    // Title
    doc.fontSize(20).fillColor('#4B0082')
       .text("ZeAISoft - Employee Full Profile", { align: "center" });
    doc.moveDown(2);
    doc.fillColor('black');

    // Remove unwanted fields
    const excludedFields = ['_id', '__v', 'createdAt', 'updatedAt'];

    Object.keys(profile).forEach(key => {
      if (excludedFields.includes(key)) return;

      const value = profile[key];

      // Handle experiences array
      if (key === "experiences" && Array.isArray(value)) {
        doc.moveDown().fontSize(14).text("Experiences:", { underline: true });
        value.forEach((exp, index) => {
          doc.moveDown(0.5);
          doc.fontSize(12).text(`Experience ${index + 1}`);
          Object.keys(exp).forEach(expKey => {
            if (expKey !== "_id") {
              doc.text(`${formatKey(expKey)}: ${exp[expKey]}`);
            }
          });
        });
      }

      // Handle nested objects (profileDocs)
      else if (typeof value === "object" && value !== null) {
        doc.moveDown().fontSize(14).text(`${formatKey(key)}:`, { underline: true });
        Object.keys(value).forEach(subKey => {
          doc.fontSize(12).text(`${formatKey(subKey)}: ${value[subKey]}`);
        });
      }

      // Normal fields
      else {
        doc.fontSize(12).text(`${formatKey(key)}: ${value || "Not Provided"}`);
      }
    });

    doc.end();

  } catch (error) {
    console.error("PDF export error:", error);
    res.status(500).send("Server Error");
  }
});

// helper function
function formatKey(key) {
  return key
    .replace(/_/g, " ")
    .replace(/\b\w/g, l => l.toUpperCase());
}

// --- PATCH SINGLE FIELD ---
router.patch('/:id', async (req, res) => {
  try {
    const updateData = req.body; // { field: value }
    const updatedEmployee = await Profile.findOneAndUpdate(
      { id: req.params.id },
      { $set: updateData },
      { new: true }
    );

    if (!updatedEmployee) {
      return res.status(404).json({ message: '❌ Employee not found' });
    }


    // 🟢 Debug logs
    console.log("🟢 Field update request:", updateData);
    console.log("🟢 For ID:", req.params.id);
    console.log("🟢 Password value:", req.body.password);

    // 🔴 ADD THIS PART TOO - sync to Employee collection
    if (updateData.password !== undefined) {
      const Employee = require('../models/employee');
      console.log("🔍 Trying to sync password for:", req.params.id);
      await Employee.findOneAndUpdate(
        { employeeId: req.params.id },
        { $set: { password: updateData.password } }
      );
      if (result) {
        console.log("✅ Password synced successfully to Employee collection");
      } else {
        console.warn("⚠️ Employee not found in Employee collection during sync");
      }
    }

    res.status(200).json({ message: '✅ Field updated', employee: updatedEmployee });
  } catch (error) {
    console.error('❌ Failed to patch employee:', error.message);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// --- ADD EXPERIENCE ---
router.post('/:id/experience', async (req, res) => {
  try {
    const experience = req.body; // { company_name, role, start_date, end_date, description }
    const updatedEmployee = await Profile.findOneAndUpdate(
      { id: req.params.id },
      { $push: { experiences: experience } },
      { new: true }
    );

    if (!updatedEmployee) {
      return res.status(404).json({ message: '❌ Employee not found' });
    }

    res.status(200).json({ message: '✅ Experience added', employee: updatedEmployee });
  } catch (error) {
    console.error('❌ Failed to add experience:', error.message);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// Update experience by expId
router.put('/:employeeId/experience/:expId', async (req, res) => {
  try {
    const { employeeId, expId } = req.params;
    const updatedExp = req.body;

    const employee = await Profile.findOneAndUpdate(
      { id: employeeId, "experiences._id": expId },
      {
        $set: {
          "experiences.$.company_name": updatedExp.company_name,
          "experiences.$.role": updatedExp.role,
          "experiences.$.start_date": updatedExp.start_date,
          "experiences.$.end_date": updatedExp.end_date,
          "experiences.$.description": updatedExp.description,
        },
      },
      { new: true }
    );

    if (!employee) return res.status(404).json({ message: "❌ Experience not found" });
    res.json({ message: "✅ Experience updated", employee });
  } catch (err) {
    console.error("Error updating experience:", err);
    res.status(500).json({ message: err.message });
  }
});

// Delete experience by expId
router.delete('/:employeeId/experience/:expId', async (req, res) => {
  try {
    const { employeeId, expId } = req.params;

    const employee = await Profile.findOneAndUpdate(
      { id: employeeId },
      { $pull: { experiences: { _id: expId } } },
      { new: true }
    );

    if (!employee) return res.status(404).json({ message: "❌ Experience not found" });
    res.json({ message: "✅ Experience deleted", employee });
  } catch (err) {
    console.error("Error deleting experience:", err);
    res.status(500).json({ message: err.message });
  }
});

// --- DELETE EMPLOYEE ---
router.delete('/:id', async (req, res) => {
  try {
    const deletedEmployee = await Profile.findOneAndDelete({ id: req.params.id });

    if (!deletedEmployee) {
      return res.status(404).json({ message: '❌ Employee not found' });
    }

    res.status(200).json({ message: '✅ Employee deleted successfully' });
  } catch (error) {
    console.error('❌ Failed to delete employee:', error.message);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});


module.exports = router;