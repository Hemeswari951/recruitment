// backend/routes/expericence.js
const express = require('express');
const router = express.Router();
const Expericence = require('../models/expericence');
const fs = require('fs');
const path = require('path');

// ✅ Define and create uploads directory ONCE here
const uploadsDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
  console.log('📁 Created uploads directory:', uploadsDir);
}

// POST /api/expericence  -> create a new experience record
router.post('/', async (req, res) => {
  try {
    const {
      companyName,
      fullName,
      position,
      startDate,
      endDate,
      issuedAt,
      pdfBase64,
      fileName,
    } = req.body;

    if (!fullName || !position || !startDate || !endDate) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    let pdfPath;
    if (pdfBase64 && fileName) {
      try {
        // sanitize filename
        const safeName = fileName.replace(/[^a-z0-9_\-\.]/gi, '_');
        const filePath = path.join(uploadsDir, safeName);
        const buffer = Buffer.from(pdfBase64, 'base64');

        fs.writeFileSync(filePath, buffer);
        pdfPath = `/uploads/${safeName}`; // public URL path
        console.log(`📄 Saved PDF to ${filePath} (public: ${pdfPath})`);
      } catch (fileErr) {
        console.error('❌ Error writing PDF file:', fileErr);
        return res
          .status(500)
          .json({ message: 'Failed to save PDF file', error: fileErr.toString() });
      }
    }

    const doc = new Expericence({
      companyName: companyName || 'ZeAI Soft',
      fullName,
      position,
      startDate,
      endDate,
      issuedAt: issuedAt ? new Date(issuedAt) : undefined,
      pdfPath,
    });

    const saved = await doc.save();
    return res.status(201).json(saved);
  } catch (err) {
    console.error('Error saving experience:', err);
    return res.status(500).json({ message: 'Internal server error', error: err.toString() });
  }
});


// PUT /api/expericence/:id  -> update an experience record FOR EDIT
router.put('/:id', async (req, res) => {
  try {
    const id = req.params.id;
    const {
      companyName,
      fullName,
      position,
      startDate,
      endDate,
      issuedAt,
      pdfBase64,
      fileName,
    } = req.body;

    if (!fullName || !position || !startDate || !endDate) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    const update = {
      companyName: companyName || 'ZeAI Soft',
      fullName,
      position,
      startDate,
      endDate,
    };

    // preserve issuedAt if provided (allow client to pass ISO or existing)
    if (issuedAt) {
      update.issuedAt = new Date(issuedAt);
    }

    // handle optional PDF replacement
    if (pdfBase64 && fileName) {
      try {
        const safeName = fileName.replace(/[^a-z0-9_\-\.]/gi, '_');
        const filePath = path.join(uploadsDir, safeName);
        const buffer = Buffer.from(pdfBase64, 'base64');
        fs.writeFileSync(filePath, buffer);
        update.pdfPath = `/uploads/${safeName}`;
        console.log(`📄 Updated PDF to ${filePath}`);
      } catch (fileErr) {
        console.error('❌ Error writing PDF file during update:', fileErr);
        return res.status(500).json({ message: 'Failed to save PDF file', error: fileErr.toString() });
      }
    }

    const updated = await Expericence.findByIdAndUpdate(id, update, { new: true });
    if (!updated) return res.status(404).json({ message: 'Not found' });
    res.json(updated);
  } catch (err) {
    console.error('Error updating experience:', err);
    res.status(500).json({ message: 'Internal server error', error: err.toString() });
  }
});


// GET /api/expericence -> list all
router.get('/', async (req, res) => {
  try {
    const list = await Expericence.find().sort({ createdAt: -1 }).limit(100);
    res.json(list);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// GET /api/expericence/:id -> get one
router.get('/:id', async (req, res) => {
  try {
    const doc = await Expericence.findById(req.params.id);
    if (!doc) return res.status(404).json({ message: 'Not found' });
    res.json(doc);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// DELETE /api/expericence/:id
router.delete('/:id', async (req, res) => {
  try {
    const doc = await Expericence.findByIdAndDelete(req.params.id);
    if (!doc) return res.status(404).json({ message: 'Not found' });
    res.json({ message: 'Deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Internal server error' });
  }
});

module.exports = router;
