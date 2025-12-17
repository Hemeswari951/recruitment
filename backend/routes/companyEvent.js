//backend/routes/companyEvent.js

const express = require('express');
const router = express.Router();
const CompanyEvent = require('../models/companyEvent');

// GET all events
router.get('/', async (req, res) => {
  try {
    const events = await CompanyEvent.find().sort({ dateTime: 1 });
    res.status(200).json(events);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST new event
router.post('/', async (req, res) => {
  try {
    const event = new CompanyEvent(req.body);
    await event.save();
    res.status(201).json(event);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// PUT update event
router.put('/:id', async (req, res) => {
  try {
    const event = await CompanyEvent.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!event) return res.status(404).json({ message: 'Event not found' });
    res.status(200).json(event);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// DELETE event
router.delete('/:id', async (req, res) => {
  try {
    const event = await CompanyEvent.findByIdAndDelete(req.params.id);
    if (!event) return res.status(404).json({ message: 'Event not found' });
    res.status(200).json({ message: 'Event deleted' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
