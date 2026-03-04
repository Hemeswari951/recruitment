// backend/routes/offerletter.js
const express = require("express");
const router = express.Router();
const OfferLetter = require("../models/offerletter");
const Counter = require("../models/offerletter_counter");
const PDFDocument = require("pdfkit");
const fs = require("fs");
const fsPromises = fs.promises; // <-- non-blocking fs API
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

// ---------- replacement POST handler in backend/routes/offerletter.js ----------
router.post("/", async (req, res) => {
  try {
    const {
      fullName,
      position,
      stipend,
      doj,
      joiningDate,
      signedDate,
      signdate,
      pdfFile,
    } = req.body;

    const emailRaw = req.body.email ? String(req.body.email).trim() : "";
    const email = emailRaw === "" ? undefined : emailRaw;

    const salaryFromRaw =
      req.body.salaryFrom ||
      req.body.salaryfrom ||
      req.body["salary from"] ||
      req.body.salary_from ||
      "";

    // Parse incoming provided employeeId (if any)
    const providedRaw = req.body.employeeId ? String(req.body.employeeId).trim() : null;
    const providedMatch = providedRaw ? providedRaw.match(/(\d+)$/) : null;
    const providedNum = providedMatch ? parseInt(providedMatch[1], 10) : null;

    let employeeId = null;

    // Load existing counter (ensure exists)
    let counter = await Counter.findOne({ key: "employeeId" });
    if (!counter) {
      // Do not assume preview already set DB — ensure DB record exists now
      counter = await Counter.create({ key: "employeeId", lastNumber: 152 });
    }

    if (providedNum) {
      // If provided number is greater than DB lastNumber -> try to claim it
      if (providedNum > counter.lastNumber) {
        // Atomically set counter to at least providedNum
        const updated = await Counter.findOneAndUpdate(
          { key: "employeeId" },
          { $max: { lastNumber: providedNum } },
          { new: true, upsert: true }
        );

        const candidateId = `ZeAI${providedNum}`;

        // Extra safety: ensure no OfferLetter already used this employeeId
        const exists = await OfferLetter.findOne({ employeeId: candidateId });
        if (exists) {
          // Someone already used it — don't reuse. Allocate next number atomically.
          const afterInc = await Counter.findOneAndUpdate(
            { key: "employeeId" },
            { $inc: { lastNumber: 1 } },
            { new: true }
          );
          employeeId = `ZeAI${afterInc.lastNumber}`;
        } else {
          // Safe to use the provided candidate
          employeeId = candidateId;
        }
      } else {
        // Provided number <= current counter => it's potentially already used.
        // Allocate a fresh one by incrementing the counter atomically.
        const updated = await Counter.findOneAndUpdate(
          { key: "employeeId" },
          { $inc: { lastNumber: 1 } },
          { new: true }
        );
        employeeId = `ZeAI${updated.lastNumber}`;
      }
    } else {
      // No provided employeeId — normal single-create flow: increment and use
      const updated = await Counter.findOneAndUpdate(
        { key: "employeeId" },
        { $inc: { lastNumber: 1 } },
        { new: true, upsert: true }
      );
      employeeId = `ZeAI${updated.lastNumber}`;
    }

    // Accept either doj or joiningDate field
    const joinDateValue = doj || joiningDate || "";
    const signedDateValue = signdate || signedDate || "";

    if (!pdfFile) {
      return res.status(400).json({ success: false, message: "No PDF file data provided." });
    }

    // Save PDF file to disk (ASYNC non-blocking)
    const safeId = String(employeeId || "unknown").replace(/[^a-z0-9_\-]/gi, "_");
    const fileName = `${safeId}_${Date.now()}.pdf`;
    const filePath = path.join(PDF_DIR, fileName);
    const pdfBuffer = Buffer.from(pdfFile, "base64");

    console.log(`POST /offerletter - saving file for ${employeeId} -> ${fileName}`);

    // Use async write to avoid blocking the event loop
    await fsPromises.writeFile(filePath, pdfBuffer);

    const pdfUrl = `/uploads/offerletters/${fileName}`;

    // Create OfferLetter record (employeeId is unique or near-unique now)
    const saved = await OfferLetter.create({
      fullName,
      employeeId,
      position,
      stipend,
      joiningDate: joinDateValue,
      signedDate: signedDateValue,
      salaryFrom: salaryFromRaw,
      salaryfrom: salaryFromRaw,
      pdfUrl,
      email, 
    });

    console.log(`POST /offerletter - saved record for ${employeeId}`);

    return res.status(201).json({
      success: true,
      data: saved,
      pdfUrl,
    });
  } catch (err) {
    console.error("POST /offerletter error:", err);
    // If duplicate key error occurs (rare), surface a friendly message
    if (err && err.code === 11000 && err.keyPattern && err.keyPattern.employeeId) {
      return res.status(409).json({ success: false, message: "Employee ID conflict. Try again." });
    }
    return res.status(500).json({ success: false, message: err.message });
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

// GET: Download PDF with friendly filename
router.get("/download/:id", async (req, res) => {
  try {
    const id = req.params.id;
    const record = await OfferLetter.findById(id);

    if (!record) {
      return res.status(404).json({ success: false, message: "Offer letter not found" });
    }

    // record.pdfUrl is like '/uploads/offerletters/ZeAI167_....pdf'
    const storedFileName = path.basename(record.pdfUrl || "");
    const filePath = path.join(PDF_DIR, storedFileName);

    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ success: false, message: "PDF file missing on server" });
    }

    // Create a safe download filename from fullName
    const rawName = String(record.fullName || "employee");
    const safeName = rawName.replace(/[^a-z0-9_\-]/gi, "_"); // keep underscores & dashes only
    const downloadName = `${safeName}_Offerletter.pdf`;

    // res.download will set Content-Disposition: attachment; filename="..."
    return res.download(filePath, downloadName, (err) => {
      if (err) {
        console.error("Download error:", err);
        // If headers already sent, we can't send JSON — just log
        if (!res.headersSent) {
          res.status(500).json({ success: false, message: "Failed to download file" });
        }
      }
    });
  } catch (err) {
    console.error("GET /offerletter/download error:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

router.put("/:id", async (req, res) => {
  try {
    // When updating, also handle salaryFrom variants so front-end can update either name
    const updateBody = { ...req.body };
    if (req.body.salaryfrom && !req.body.salaryFrom) {
      updateBody.salaryFrom = req.body.salaryfrom;
    }
    if (req.body.salaryFrom && !req.body.salaryfrom) {
      updateBody.salaryfrom = req.body.salaryFrom;
    }

    const updated = await OfferLetter.findByIdAndUpdate(
      req.params.id,
      updateBody,
      { new: true }
    );
    res.json({ success: true, updated });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;