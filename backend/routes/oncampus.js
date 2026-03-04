//backend/routes/oncampus.js
const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const PDFDocument = require('pdfkit');
const ExcelJS = require('exceljs'); // keep if you use excel export elsewhere

const OnCampusDrive = require('../models/onCampusDrive');

// ----------------------------------------
// MULTER CONFIGURATION
// ----------------------------------------
const uploadDir = path.join(__dirname, '..', 'uploads', 'resumes');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, Date.now().toString() + '-' + Math.round(Math.random()*1e6) + ext);
  },
});
const upload = multer({ storage });

// ==========================================================
// 0️⃣ EXPORT ALL DRIVES — SINGLE PDF (NEW)
// ==========================================================
router.get('/export-all', async (req, res) => {
  try {
    const drives = await OnCampusDrive.find().sort({ dateOfRecruitment: -1 });

    // Prepare PDF
    const doc = new PDFDocument({ margin: 30, size: 'A4' });

    res.setHeader('Content-Disposition', `attachment; filename=oncampus_all_drives.pdf`);
    res.setHeader('Content-Type', 'application/pdf');

    doc.pipe(res);

    // Title page / header
    doc.fontSize(20).text('On Campus Recruitment — All Drives Report', { align: 'center' });
    doc.moveDown(0.5);
    doc.fontSize(10).text(`Generated on: ${new Date().toISOString().slice(0,10)}`, { align: 'center' });
    doc.moveDown(1.2);

    drives.forEach((drive, driveIndex) => {
      // Per-drive header (Title B style)
      doc.moveDown(0.5);
      doc.fontSize(12).fillColor('black').text(`===== DRIVE ${driveIndex+1} =====`, { continued: false });
      doc.moveDown(0.2);
      doc.fontSize(14).font('Helvetica-Bold').text(`College: ${drive.collegeName || '-'}`);
      doc.fontSize(11).font('Helvetica').text(`Date: ${drive.dateOfRecruitment ? drive.dateOfRecruitment.toISOString().slice(0,10) : '-'}`);
      doc.text(`Position: ${drive.selectedPosition || '-'}`);
      doc.text(`BG Verification: ${drive.bgVerificationStatus || '-'}`);
      doc.text(`Contact Person: ${drive.contactPerson || '-'}`);
      doc.moveDown(0.4);

      // Summary counts
      doc.fontSize(12).font('Helvetica-Bold').text('Summary:');
      doc.fontSize(11).font('Helvetica').list([
        `Total Students: ${drive.totalStudents ?? 0}`,
        `Aptitude Selected: ${drive.aptitudeSelected ?? 0}`,
        `Tech Selected: ${drive.techSelected ?? 0}`,
        `HR Selected: ${drive.hrSelected ?? 0}`,
      ]);
      doc.moveDown(0.4);

      // Student contact details (if any)
      if (drive.studentContactDetails) {
        doc.fontSize(11).font('Helvetica-Bold').text('Student Contact Details:');
        doc.fontSize(10).font('Helvetica').text(`${drive.studentContactDetails}`, { width: 480 });
        doc.moveDown(0.4);
      }

      // Full students table header
      doc.fontSize(12).font('Helvetica-Bold').text('Students:', { underline: true });
      doc.moveDown(0.2);

      // Table columns (Name, Mobile, Email)
      const tableTop = doc.y;
      const colWidths = { sn: 30, name: 220, mobile: 120, email: 180 };
      // Header row
      doc.fontSize(10).font('Helvetica-Bold');
      doc.text('S.No', { continued: true, width: colWidths.sn });
      doc.text('Name', { continued: true, width: colWidths.name });
      doc.text('Mobile', { continued: true, width: colWidths.mobile });
      doc.text('Email', { width: colWidths.email });
      doc.moveDown(0.2);

      // Students rows
      doc.font('Helvetica').fontSize(10);
      (drive.students || []).forEach((s, idx) => {
        // If approaching bottom, add new page
        if (doc.y > doc.page.height - 100) {
          doc.addPage();
        }
        doc.text((idx + 1).toString(), { continued: true, width: colWidths.sn });
        const nameText = s.name || '-';
        doc.text(nameText.length > 40 ? nameText.slice(0, 40) + '...' : nameText, { continued: true, width: colWidths.name });
        doc.text(s.mobile || '-', { continued: true, width: colWidths.mobile });
        doc.text(s.email || '-', { width: colWidths.email });
      });

      // Separator between drives
      doc.moveDown(1);
      doc.strokeColor('#cccccc').moveTo(doc.page.margins.left, doc.y).lineTo(doc.page.width - doc.page.margins.right, doc.y).stroke();
      doc.moveDown(0.6);
    });

    doc.end();
  } catch (err) {
    console.error("EXPORT ALL PDF ERROR:", err);
    res.status(500).json({ error: err.message });
  }
});

// ==========================================================
// 1️⃣ STUDENT ROUTES — MUST ALWAYS COME FIRST (most specific)
// ==========================================================
router.post('/:id/students', upload.single('resume'), async (req, res) => {
  try {
    const drive = await OnCampusDrive.findById(req.params.id);
    if (!drive) return res.status(404).json({ message: 'Drive not found' });

    const student = {
      name: req.body.name || '',
      mobile: req.body.mobile || '',
      email: req.body.email || '',
      resumePath: req.file ? path.join('uploads', 'resumes', req.file.filename) : ''
    };

    drive.students.push(student);
    drive.totalStudents = (drive.totalStudents || 0) + 1;
    await drive.save();

    res.status(201).json(drive);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id/students/:studentId', upload.single('resume'), async (req, res) => {
  try {
    const drive = await OnCampusDrive.findById(req.params.id);
    if (!drive) return res.status(404).json({ message: 'Drive not found' });

    const s = drive.students.id(req.params.studentId);
    if (!s) return res.status(404).json({ message: 'Student not found' });

    s.name = req.body.name ?? s.name;
    s.mobile = req.body.mobile ?? s.mobile;
    s.email = req.body.email ?? s.email;

    if (req.file) {
      // Delete previous resume
      if (s.resumePath) {
        const prev = path.join(__dirname, '..', s.resumePath);
        if (fs.existsSync(prev)) fs.unlinkSync(prev);
      }
      s.resumePath = path.join('uploads', 'resumes', req.file.filename);
    }

    await drive.save();
    res.json(drive);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// router.delete('/:id/students/:studentId', async (req, res) => {
//   try {
//     const drive = await OnCampusDrive.findById(req.params.id);
//     if (!drive) return res.status(404).json({ message: 'Drive not found' });

//     const s = drive.students.id(req.params.studentId);
//     if (!s) return res.status(404).json({ message: 'Student not found' });

//     if (s.resumePath) {
//       const fp = path.join(__dirname, '..', s.resumePath);
//       if (fs.existsSync(fp)) fs.unlinkSync(fp);
//     }

//     s.remove();
//     drive.totalStudents = Math.max(0, (drive.totalStudents || 1) - 1);
//     await drive.save();

//     res.json({ message: 'Student deleted', drive });
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

router.delete('/:id/students/:studentId', async (req, res) => {
  try {
    const drive = await OnCampusDrive.findById(req.params.id);
    if (!drive) return res.status(404).json({ message: 'Drive not found' });

    const studentId = req.params.studentId;
    // try Mongoose subdocument lookup first
    let s = typeof drive.students.id === 'function' ? drive.students.id(studentId) : null;

    // If not found via subdoc API, fallback to find by matching _id (string or ObjectId)
    if (!s) {
      const idx = drive.students.findIndex(st => {
        // handle both string ids and ObjectId-like objects
        if (!st) return false;
        if (st._id == null) return false;
        return st._id.toString() === studentId.toString();
      });

      if (idx === -1) {
        return res.status(404).json({ message: 'Student not found' });
      }

      // `s` is plain object reference from the array
      s = drive.students[idx];

      // delete resume file if present
      if (s.resumePath) {
        const fp = path.join(__dirname, '..', s.resumePath);
        if (fs.existsSync(fp)) {
          try { fs.unlinkSync(fp); }
          catch (e) { console.warn('Failed removing resume file', fp, e); }
        }
      }

      // remove by index
      drive.students.splice(idx, 1);
    } else {
      // we found a mongoose subdocument
      if (s.resumePath) {
        const fp = path.join(__dirname, '..', s.resumePath);
        if (fs.existsSync(fp)) {
          try { fs.unlinkSync(fp); }
          catch (e) { console.warn('Failed removing resume file', fp, e); }
        }
      }

      // If subdocument has remove() (Mongoose), use it
      if (typeof s.remove === 'function') {
        s.remove();
      } else {
        // fallback: filter out by id
        drive.students = drive.students.filter(st => st._id.toString() !== studentId.toString());
      }
    }

    // Recompute totalStudents from array length (safer)
    drive.totalStudents = Array.isArray(drive.students) ? drive.students.length : 0;

    await drive.save();

    console.log('Student removed and drive saved. driveId=', drive._id, 'totalStudents=', drive.totalStudents);
    res.json({ message: 'Student deleted', drive });
  } catch (err) {
    console.error('DELETE student error:', err);
    res.status(500).json({ error: err.message || err });
  }
});

// ==========================================================
// 2️⃣ EXPORT PDF ROUTE — single drive (existing)
// ==========================================================
router.get('/:id/export', async (req, res) => {
  console.log("⚡ PDF ROUTE HIT:", req.params.id);

  try {
    const drive = await OnCampusDrive.findById(req.params.id);
    if (!drive) return res.status(404).json({ message: 'Drive not found' });

    const doc = new PDFDocument({ margin: 30 });

    res.setHeader('Content-Disposition', `attachment; filename=drive-${drive._id}.pdf`);
    res.setHeader('Content-Type', 'application/pdf');

    doc.pipe(res);

    // HEADER
    doc.fontSize(18).text(`On-Campus Drive: ${drive.collegeName}`, { underline: true });
    doc.moveDown();
    doc.fontSize(12).text(`Date: ${drive.dateOfRecruitment ? drive.dateOfRecruitment.toISOString().slice(0,10) : '-'}`);
    doc.text(`Selected Position: ${drive.selectedPosition}`);
    doc.text(`BG Verification: ${drive.bgVerificationStatus}`);
    doc.text(`Contact Person: ${drive.contactPerson}`);
    doc.moveDown();

    // SUMMARY
    doc.fontSize(14).text("Summary", { underline: true });
    doc.fontSize(12).list([
      `Total Students: ${drive.totalStudents}`,
      `Aptitude Selected: ${drive.aptitudeSelected}`,
      `Tech Selected: ${drive.techSelected}`,
      `HR Selected: ${drive.hrSelected}`
    ]);
    doc.moveDown();

    // STUDENTS
    doc.fontSize(14).text("Students", { underline: true });

    drive.students.forEach((s, idx) => {
      doc.fontSize(12).text(`${idx + 1}. ${s.name || '-'} — ${s.mobile || '-'} — ${s.email || '-'}`);
    });

    doc.end();
  } catch (err) {
    console.error("PDF Export Error:", err);
    res.status(500).json({ error: err.message });
  }
});

// ==========================================================
// 3️⃣ NORMAL ROUTES
// ==========================================================
router.get('/', async (req, res) => {
  const drives = await OnCampusDrive.find().sort({ dateOfRecruitment: -1 });
  res.json(drives);
});

router.get('/:id', async (req, res) => {
  const drive = await OnCampusDrive.findById(req.params.id);
  if (!drive) return res.status(404).json({ message: 'Not found' });
  res.json(drive);
});

router.post('/', async (req, res) => {
  try {
    const payload = req.body;
    if (payload.dateOfRecruitment)
      payload.dateOfRecruitment = new Date(payload.dateOfRecruitment);

    const drive = new OnCampusDrive(payload);
    await drive.save();
    res.status(201).json(drive);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  const payload = req.body;
  if (payload.dateOfRecruitment)
    payload.dateOfRecruitment = new Date(payload.dateOfRecruitment);

  const drive = await OnCampusDrive.findByIdAndUpdate(req.params.id, payload, { new: true });
  res.json(drive);
});

router.delete('/:id', async (req, res) => {
  const drive = await OnCampusDrive.findByIdAndDelete(req.params.id);
  res.json({ message: 'Deleted', driveId: drive ? drive._id : null });
});




// ==========================================================
// 4️⃣ RESUME VIEW ROUTE — INLINE (OPEN IN NEW TAB)
// ==========================================================
router.get('/resume/view/:filename', (req, res) => {
  try {
    console.log('RESUME VIEW route hit, filename raw=', req.params.filename);
    const raw = req.params.filename || '';
    const filename = path.basename(decodeURIComponent(raw));
    const filePath = path.join(__dirname, '..', 'uploads', 'resumes', filename);

    console.log('Looking for filePath=', filePath);

    if (!fs.existsSync(filePath)) {
      console.warn('File not found:', filePath);
      return res.status(404).json({ message: 'File not found' });
    }

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'inline');
    res.sendFile(filePath);
  } catch (err) {
    console.error('View resume error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});


// ==========================================================
// 4️⃣ RESUME DOWNLOAD ROUTE — MUST BE LAST
// ==========================================================
router.get('/resume/:filename', (req, res) => {
  try {
    // make sure we only use the basename (prevent path segments / traversal)
    const raw = req.params.filename || '';
    const filename = path.basename(decodeURIComponent(raw)); // ensures only filename
    const file = path.join(__dirname, '..', 'uploads', 'resumes', filename);

    if (fs.existsSync(file)) {
      // let express handle download headers (content-type/disposition)
      return res.download(file, filename, (err) => {
        if (err) {
          console.error('Download error:', err);
          if (!res.headersSent) res.status(500).json({ message: 'Error sending file' });
        }
      });
    } else {
      return res.status(404).json({ message: 'File not found' });
    }
  } catch (err) {
    console.error('Resume download error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});


module.exports = router;
