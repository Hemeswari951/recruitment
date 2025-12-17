//backend/routes/offerletter.js
const express = require("express");
const router = express.Router();
const OfferLetter = require("../models/offerletter");
const Counter = require("../models/offerletter_counter");
const PDFDocument = require("pdfkit");
const fs = require("fs");
const path = require("path");

// Ensure folder exists
const PDF_DIR = path.join(__dirname, "..", "uploads", "offerletters");
if (!fs.existsSync(PDF_DIR)) fs.mkdirSync(PDF_DIR, { recursive: true });

// ------------------------ GET NEXT AUTO EMPLOYEE ID ------------------------
router.get("/next-id", async (req, res) => {
  try {
    let counter = await Counter.findOne({ key: "employeeId" });

    if (!counter) {
      counter = await Counter.create({ key: "employeeId", lastNumber: 152 });
    }

    const nextId = counter.lastNumber + 1;
    const formattedId = `ZeAI${nextId}`;

    res.json({ success: true, nextId: formattedId });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST: Save Offer Letter (save data + generate PDF)
router.post("/", async (req, res) => {
  try {
    const { fullName, position, stipend, doj, joiningDate, signedDate, signdate, pdfFile } = req.body;

    // AUTO GENERATE EMPLOYEE ID
    let counter = await Counter.findOne({ key: "employeeId" });
    if (!counter) counter = await Counter.create({ key: "employeeId", lastNumber: 152 });

    counter.lastNumber += 1;
    await counter.save();

    const employeeId = `ZeAI${counter.lastNumber}`;

    // Accept either doj or joiningDate field (frontend may send doj)
    const joinDateValue = doj || joiningDate || "";
    const signedDateValue = signdate || signedDate || "";

    if (!pdfFile) {
      return res.status(400).json({ success: false, message: "No PDF file data provided." });
    }

    // Create filename safely
    const safeId = String(employeeId || "unknown").replace(/[^a-z0-9_\-]/gi, "_");
    const fileName = `${safeId}_${Date.now()}.pdf`;  // ✅ correct
    const filePath = path.join(PDF_DIR, fileName);
    

    // Decode Base64 and write the file
    //const pdfBuffer = Buffer.from(pdfFile, 'base64');
    const base64Data = pdfFile.replace(/^data:application\/pdf;base64,/, "");
const pdfBuffer = Buffer.from(base64Data, "base64");
    fs.writeFileSync(filePath, pdfBuffer);

    const pdfUrl = `/uploads/offerletters/${fileName}`; // ✅ template string 

    // Save DB record with pdfUrl
    const saved = await OfferLetter.create({
      fullName,
      employeeId,
      position,
      stipend,
      joiningDate: joinDateValue,
      signedDate: signedDateValue,
      pdfUrl
    });

    res.status(201).json({
      success: true,
      data: saved,
      pdfUrl
    });

  } catch (err) {
    console.error("POST /offerletter error:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET: Fetch All Offer Letters (same as before)
router.get("/", async (req, res) => {
  try {
    const letters = await OfferLetter.find().sort({ createdAt: -1 });
    res.json({ success: true, letters });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET: Serve PDF direct (optional — easier for frontend)
router.get("/pdf/:fileName", (req, res) => {
  const fileName = req.params.fileName;
  const filePath = path.join(PDF_DIR, fileName);
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ success: false, message: "PDF not found" });
  }
  res.sendFile(filePath);
});

router.put("/:id", async (req, res) => {
  try {
    const updated = await OfferLetter.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    res.json({ success: true, updated });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports=router;