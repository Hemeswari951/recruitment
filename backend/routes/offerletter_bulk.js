// backend/routes/offerletter_bulk.js
const express = require("express");
const router = express.Router();
const multer = require("multer");
const xlsx = require("xlsx");
const path = require("path");
const fs = require("fs");
const OfferLetter = require("../models/offerletter");
const Counter = require("../models/offerletter_counter");

const UPLOAD_DIR = path.join(__dirname, "..", "uploads");
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
const TMP_DIR = path.join(UPLOAD_DIR, "tmp");
if (!fs.existsSync(TMP_DIR)) fs.mkdirSync(TMP_DIR, { recursive: true });

// configure multer (store uploaded Excel temporarily)
const upload = multer({ dest: TMP_DIR });

// Helper: normalize header keys
function normalizeKey(k) {
  return String(k || "").trim().toLowerCase().replace(/[^a-z0-9]/g, "");
}

// Helper: Excel serial -> ISO date (yyyy-mm-dd)
function excelDateToISO(n) {
  // Excel epoch 1900, convert serial to JS date
  if (n === undefined || n === null || isNaN(n)) return "";
  const d = new Date((n - 25569) * 86400 * 1000);
  return d.toISOString().slice(0, 10);
}

// READ-ONLY: Return current lastNumber WITHOUT incrementing DB.
// This makes preview non-destructive (cancelling preview won't change counter).
async function getCurrentLastNumber() {
  const counter = await Counter.findOne({ key: "employeeId" });
  if (!counter) {
    // do NOT write to DB here — keep preview non-destructive
    return 152;
  }
  return counter.lastNumber;
}

// NEW: BULK DATA route (no PDF creation)
router.post("/bulk", upload.single("file"), async (req, res) => {
  try {
    console.log("=== /api/offerletter/bulk (data only) hit ===");

    if (!req.file) return res.status(400).json({ success: false, message: "No file uploaded" });

    // read workbook
    const workbook = xlsx.readFile(req.file.path, { cellDates: false });
    const selectedSheet = req.body.sheetName || workbook.SheetNames[0];
    //const rows = xlsx.utils.sheet_to_json(sheet, { defval: "" });

const sheet = workbook.Sheets[selectedSheet];
if (!sheet) {
  return res.status(400).json({ message: "Invalid sheet selected" });
}

    const rows = xlsx.utils.sheet_to_json(sheet, { defval: "" });
    if (!Array.isArray(rows) || rows.length === 0) {
      try { fs.unlinkSync(req.file.path); } catch (e) {}
      return res.status(400).json({ success: false, message: "Empty Excel file" });
    }

    const records = [];
    const errors = [];

    // Read the current counter once (non-destructively) so preview IDs are sequential.
    const startNumber = await getCurrentLastNumber(); // e.g. 152

    for (let i = 0; i < rows.length; i++) {
      const raw = rows[i];
      // normalize keys to easily find columns even if header case/spacing differs
      const map = {};
      Object.keys(raw).forEach(k => { map[normalizeKey(k)] = raw[k]; });

      // Candidate column names to try:
      const fullName = String(map["fullname"] || map["name"] || map["full_name"] || "").trim();
      const position = String(map["position"] || map["role"] || "").trim();
      const stipend = map["stipend"] !== undefined ? String(map["stipend"]) : "";
      const ctc = map["ctc"] !== undefined ? String(map["ctc"]) : "";

      // Dates: could be text (yyyy-mm-dd) or Excel serial number -> convert
      let doj = "";
      let signedDate = "";
      if (map["dateofjoining"] !== undefined) {
        doj = (typeof map["dateofjoining"] === "number") ? excelDateToISO(map["dateofjoining"]) : String(map["dateofjoining"]);
      } else if (map["doj"] !== undefined) {
        doj = (typeof map["doj"] === "number") ? excelDateToISO(map["doj"]) : String(map["doj"]);
      }
      if (map["signeddate"] !== undefined) {
        signedDate = (typeof map["signeddate"] === "number") ? excelDateToISO(map["signeddate"]) : String(map["signeddate"]);
      } else if (map["signdate"] !== undefined) {
        signedDate = (typeof map["signdate"] === "number") ? excelDateToISO(map["signdate"]) : String(map["signdate"]);
      }

      // NEW: Salary From -> accept 'salaryfrom' normalized key (covers 'Salary from', 'salary_from', 'salaryFrom', etc.)
      let salaryFrom = "";
      if (map["salaryfrom"] !== undefined) {
        salaryFrom = (typeof map["salaryfrom"] === "number") ? excelDateToISO(map["salaryfrom"]) : String(map["salaryfrom"]);
      } else if (map["salaryfrom"] === undefined && map["salaryfrom"] !== null) {
        // fallback is handled above; nothing to do
      }

      // NEW: Parse email (support normalized headers like "email", "mail", "gmail")
      const emailRaw = (map["email"] || map["mail"] || map["gmail"] || "").toString().trim();
      const email = emailRaw;

      // simple email validation (very permissive) — frontend should revalidate before sending mails
      const emailValid = email === "" ? false : /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);


      if (!fullName || !position) {
        errors.push({ row: i + 1, reason: "Missing fullName or position" });
        continue;
      }

      // compute employeeId for preview ONLY (do NOT save to DB)
      // use startNumber + (i + 1) so first row becomes ZeAI(startNumber+1)
      const computedId = `ZeAI${startNumber + (i + 1)}`;

      records.push({
        row: i + 1,
        fullName,
        employeeId: computedId,
        position,
        stipend,
        ctc,
        doj,
        signdate: signedDate,
        // Provide both keys: prefer camelCase for frontend but include legacy key if needed
        salaryFrom: salaryFrom,
        salaryfrom: salaryFrom,
        email: email,
        emailValid: emailValid,
      });
    }

    // clean up temp upload
    try { fs.unlinkSync(req.file.path); } catch (e) {}

    const summary = { total: rows.length, processed: records.length, failed: errors.length };

    return res.json({ success: true, summary, records, errors });
  } catch (err) {
    console.error("bulk-data error:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

router.post("/bulk/sheets", upload.single("file"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "No file uploaded" });
    }

    const workbook = xlsx.readFile(req.file.path);
    const sheetNames = workbook.SheetNames;

    // cleanup temp file
    try { fs.unlinkSync(req.file.path); } catch (_) {}

    return res.json({
      success: true,
      sheets: sheetNames
    });
  } catch (err) {
    console.error("sheet list error:", err);
    return res.status(500).json({ message: err.message });
  }
});


module.exports = router;
