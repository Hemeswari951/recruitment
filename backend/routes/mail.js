const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const Mail = require("../models/Mail"); // <-- your mail model

// --------------------------------------
// STORAGE FOR FILE UPLOAD (MULTER)
// --------------------------------------
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, "uploads/");
    },
    filename: (req, file, cb) => {
        const unique = Date.now() + "-" + Math.round(Math.random() * 1e9);
        cb(null, unique + path.extname(file.originalname));
    }
});

const upload = multer({ storage });

// --------------------------------------
// SEND MAIL
// --------------------------------------
router.post("/send", upload.array("attachments"), async (req, res) => {
    try {
        const { from, to, subject, body } = req.body;

        let filePaths = [];
        if (req.files) {
            filePaths = req.files.map((file) => `/uploads/${file.filename}`);
        }

        const mail = new Mail({
            from,
            to,
            subject,
            body,
            attachments: filePaths,
            trash: false,
            createdAt: new Date(),
        });

        await mail.save();
        return res.status(201).send({ message: "Mail sent successfully" });
    } catch (err) {
        console.error("Send Mail Error:", err);
        return res.status(500).send("Error sending mail");
    }
});

// --------------------------------------
// GET INBOX
// --------------------------------------
router.get("/inbox/:id", async (req, res) => {
    try {
        const inbox = await Mail.find({ to: req.params.id, trash: false }).sort({ createdAt: -1 });
        res.send(inbox);
    } catch (err) {
        res.status(500).send("Inbox load error");
    }
});

// --------------------------------------
// GET SENT MAILS
// --------------------------------------
router.get("/sent/:id", async (req, res) => {
    try {
        const sent = await Mail.find({ from: req.params.id, trash: false }).sort({ createdAt: -1 });
        res.send(sent);
    } catch (err) {
        res.status(500).send("Sent load error");
    }
});

// --------------------------------------
// TRASH MAILS
// --------------------------------------
router.get("/trash/:id", async (req, res) => {
    try {
        const trash = await Mail.find({
            $or: [{ to: req.params.id }, { from: req.params.id }],
            trash: true
        }).sort({ createdAt: -1 });
        res.send(trash);
    } catch (err) {
        res.status(500).send("Trash load error");
    }
});

// --------------------------------------
// VIEW MAIL
// --------------------------------------
router.get("/view/:id", async (req, res) => {
    try {
        const mail = await Mail.findById(req.params.id);
        res.send(mail);
    } catch (err) {
        res.status(500).send("Mail view error");
    }
});

// --------------------------------------
// MOVE TO TRASH
// --------------------------------------
router.put("/trash/:id", async (req, res) => {
    try {
        await Mail.findByIdAndUpdate(req.params.id, { trash: true });
        res.send("Moved to trash");
    } catch (err) {
        res.status(500).send("Trash error");
    }
});

// --------------------------------------
// RESTORE MAIL
// --------------------------------------
router.put("/restore/:id", async (req, res) => {
    try {
        await Mail.findByIdAndUpdate(req.params.id, { trash: false });
        res.send("Restored");
    } catch (err) {
        res.status(500).send("Restore error");
    }
});

// --------------------------------------
// DELETE FOREVER
// --------------------------------------
router.delete("/delete-permanent/:id", async (req, res) => {
    try {
        await Mail.findByIdAndDelete(req.params.id);
        res.send("Deleted permanently");
    } catch (err) {
        res.status(500).send("Delete error");
    }
});

module.exports = router;
