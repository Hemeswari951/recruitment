//backend/routes/RevisedOfferLetter.js
const router = require("express").Router();
const RevisedOfferLetter = require("../models/RevisedOfferLetter");

// @route   POST /api/revisedofferletter
// @desc    Create a new revised offer letter
router.post("/", async (req, res) => {
  try {
    const {
      fullName,
      employeeId,
      fromposition, // Add fromposition
      position,
      stipend,
      ctc,
      doj,
      signdate,
      salaryFrom,
      pdfFile,
    } = req.body;

    const newLetter = new RevisedOfferLetter({
      fullName,
      employeeId,
      fromposition, // Add fromposition
      position,
      stipend,
      ctc,
      doj,
      signdate,
      salaryFrom,
      pdfFile,
    });

    const savedLetter = await newLetter.save();
    res.status(201).json(savedLetter);
  } catch (err) {
    console.error("Error saving revised offer letter:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// @route   GET /api/revisedofferletter
// @desc    Get all revised offer letters
router.get("/", async (req, res) => {
  try {
    const letters = await RevisedOfferLetter.find().sort({ createdAt: -1 });
    res.status(200).json(letters);
  } catch (err) {
    console.error("Error fetching revised offer letters:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// @route   PUT /api/revisedofferletter/:id
// @desc    Update a revised offer letter
router.put("/:id", async (req, res) => {
  try {
    const {
      fullName,
      employeeId,
      fromposition, // Add fromposition
      position,
      stipend,
      ctc,
      doj,
      signdate,
      salaryFrom,
      pdfFile,
    } = req.body;

    const updatedLetter = await RevisedOfferLetter.findByIdAndUpdate(
      req.params.id,
      {
        fullName,
        employeeId,
        fromposition, // Add fromposition
        position,
        stipend,
        ctc,
        doj,
        signdate,
        salaryFrom,
        pdfFile, // Also update the regenerated PDF
      },
      { new: true } // This option returns the updated document
    );

    if (!updatedLetter) {
      return res.status(404).json({ error: "Revised offer letter not found" });
    }

    res.status(200).json(updatedLetter);
  } catch (err) {
    console.error("Error updating revised offer letter:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// @route   DELETE /api/revisedofferletter/:id
// @desc    Delete a revised offer letter
router.delete("/:id", async (req, res) => {
  try {
    const deletedLetter = await RevisedOfferLetter.findByIdAndDelete(req.params.id);
    if (!deletedLetter) {
      return res.status(404).json({ error: "Revised offer letter not found" });
    }
    res.status(200).json({ message: "Revised offer letter deleted successfully" });
  } catch (err) {
    console.error("Error deleting revised offer letter:", err);
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router;