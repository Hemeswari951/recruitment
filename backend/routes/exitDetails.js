const express = require("express");
const router = express.Router();
const ExitDetails = require("../models/exitDetails");

// ===============================
// Save Exit Details
// ===============================
router.post("/", async (req, res) => {
  try {
    const data = req.body;

    const exit = new ExitDetails(data);
    await exit.save();

    res.status(201).json({
      message: "Exit Details Saved Successfully",
      data: exit,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ===============================
// Get All Exit Records
// ===============================
router.get("/", async (req, res) => {
  try {
    const exitData = await ExitDetails.find().sort({ createdAt: -1 });

    res.status(200).json(exitData);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
// ===============================
// Delete Exit Record by ID
// ===============================
router.delete("/:id", async (req, res) => {
  try {
    const { id } = req.params;

    const deleted = await ExitDetails.findByIdAndDelete(id);

    if (!deleted) {
      return res.status(404).json({ message: "Record not found" });
    }

    res.status(200).json({ message: "Record deleted successfully" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});


module.exports = router;