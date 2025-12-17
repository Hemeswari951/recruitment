const express = require("express");
const router = express.Router();
const InviteTracker = require("../models/inviteTracker");
const PDFDocument = require('pdfkit');



// GET all records → /all

router.get("/all", async (req, res) => {
  try {
    const list = await InviteTracker.find().sort({ createdAt: -1 });
    res.status(200).json(list);
  } catch (error) {
    res.status(500).json({ message: "Failed to fetch records", error });
  }
});


// CREATE new record → /create

router.post("/create", async (req, res) => {
  try {
    const invite = new InviteTracker(req.body);
    await invite.save();
    res.status(201).json({ message: "Invite created successfully", invite });
  } catch (error) {
    res.status(500).json({ message: "Failed to create invite", error });
  }
});

//
// GET single record → /:id
//
router.get("/:id", async (req, res) => {
  try {
    const item = await InviteTracker.findById(req.params.id);
    if (!item) return res.status(404).json({ message: "Record not found" });

    res.status(200).json(item);
  } catch (error) {
    res.status(500).json({ message: "Failed to fetch record", error });
  }
});

//
// UPDATE record → /update/:id
//
router.put("/update/:id", async (req, res) => {
  try {
    const updated = await InviteTracker.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );

    if (!updated) return res.status(404).json({ message: "Record not found" });

    res.status(200).json({ message: "Update successful", updated });
  } catch (error) {
    res.status(500).json({ message: "Failed to update record", error });
  }
});

//
// DELETE record → /delete/:id
//
router.delete("/delete/:id", async (req, res) => {
  try {
    const deleted = await InviteTracker.findByIdAndDelete(req.params.id);

    if (!deleted) return res.status(404).json({ message: "Record not found" });

    res.status(200).json({ message: "Record deleted successfully" });
  } catch (error) {
    res.status(500).json({ message: "Failed to delete record", error });
  }
});

router.get("/download/pdf", async (req, res) => {
  try {
    const list = await InviteTracker.find().sort({ createdAt: -1 });

    // PDF headers
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", "attachment; filename=invite_tracker.pdf");

    const doc = new PDFDocument();
    doc.pipe(res);

    doc.fontSize(20).text("Invite Tracker Report", { align: "center" });
    doc.moveDown();

    list.forEach((item, i) => {
      doc.fontSize(12).text(`Invite #${i + 1}`);
      doc.text(`Date of Invite: ${item.dateOfInvite}`);
      doc.text(`College Name: ${item.collegeName}`);
      doc.text(`Total Students: ${item.totalStudents}`);
      doc.text(`Contact Person: ${item.contactPerson}`);
      doc.text(`Date of Recruitment: ${item.dateOfRecruitment}`);
      doc.text(`Mode: ${item.mode}`);
      doc.moveDown();
      doc.moveDown();
    });

    doc.end();
  } catch (e) {
    res.status(500).json({ message: "Failed to generate PDF", error: e });
  }
});

module.exports = router;