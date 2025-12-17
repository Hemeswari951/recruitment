const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const ExitDetails = require("../models/exitDetails");

// Create upload folder if not exists
const uploadPath = path.join(__dirname, "../uploads/exitDocs");

if (!fs.existsSync(uploadPath)) {
  fs.mkdirSync(uploadPath, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadPath),
  filename: (req, file, cb) => cb(null, Date.now() + "-" + file.originalname),
});


const upload = multer({ storage });


// ===============================
// UPLOAD EXIT DOCUMENT
// ===============================
router.post("/upload", upload.single("file"), async (req, res) => {
  try {
    const { employeeId } = req.body;

    if (!req.file) {
      return res.status(400).json({ error: "No file uploaded" });
    }

    // update record with uploaded file name
    await ExitDetails.findOneAndUpdate(
      { employeeId: employeeId },
      { exitDocument: req.file.filename },
      { new: true }
    );

    res.status(200).json({
      message: "File uploaded successfully",
      file: req.file.filename,
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
// ===============================
// VIEW / DOWNLOAD EXIT DOCUMENT
// ===============================
router.get("/file/:fileName", (req, res) => {
  const filePath = path.join(uploadPath, req.params.fileName);

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: "File not found" });
  }

  res.sendFile(filePath);
});


module.exports = router;