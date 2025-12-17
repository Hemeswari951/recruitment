// routes/exitDetailsRoutes.js
const express = require('express');
const ExitDetail = require('../models/ExitDetail');

const router = express.Router();

/**
 * POST /api/exit-details
 * Create exit detail
 */
router.post('/exit-details', async (req, res) => {
  try {
    const payload = { ...req.body };

    // Convert ISO strings to Date if provided
    if (payload.resignationDate) payload.resignationDate = new Date(payload.resignationDate);
    if (payload.acceptanceDate) payload.acceptanceDate = new Date(payload.acceptanceDate);

    if (!payload.employeeId) {
      return res.status(400).json({ error: 'employeeId is required' });
    }

    const doc = new ExitDetail(payload);
    await doc.save();
    return res.status(201).json(doc);
  } catch (err) {
    console.error('POST /exit-details error', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/exit-details/:id
 * Get an exit detail by DB id
 */
router.get('/exit-details/:id', async (req, res) => {
  try {
    const doc = await ExitDetail.findById(req.params.id).exec();
    if (!doc) return res.status(404).json({ error: 'Not found' });
    return res.json(doc);
  } catch (err) {
    console.error('GET /exit-details/:id', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/employees/:employeeId/exit-details
 * List exit details for an employee (newest first)
 */
router.get('/employees/:employeeId/exit-details', async (req, res) => {
  try {
    const docs = await ExitDetail.find({ employeeId: req.params.employeeId })
      .sort({ createdAt: -1 })
      .exec();
    return res.json(docs);
  } catch (err) {
    console.error('GET /employees/:employeeId/exit-details', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * PUT /api/exit-details/:id
 * Update an exit detail
 */
router.put('/exit-details/:id', async (req, res) => {
  try {
    const payload = { ...req.body };
    if (payload.resignationDate) payload.resignationDate = new Date(payload.resignationDate);
    if (payload.acceptanceDate) payload.acceptanceDate = new Date(payload.acceptanceDate);

    const updated = await ExitDetail.findByIdAndUpdate(req.params.id, payload, { new: true }).exec();
    if (!updated) return res.status(404).json({ error: 'Not found' });
    return res.json(updated);
  } catch (err) {
    console.error('PUT /exit-details/:id', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * DELETE /api/exit-details/:id
 */
router.delete('/exit-details/:id', async (req, res) => {
  try {
    const deleted = await ExitDetail.findByIdAndDelete(req.params.id).exec();
    if (!deleted) return res.status(404).json({ error: 'Not found' });
    return res.json({ success: true });
  } catch (err) {
    console.error('DELETE /exit-details/:id', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
