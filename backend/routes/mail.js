// backend/routes/mail.js
const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const fs = require("fs");

// legacy Mail model (you may remove after migration)
// const Mail = require("../models/mail");
const Draft = require("../models/draft");

// new thread model + employee
const MailThread = require("../models/mailThread");
const Employee = require("../models/employee");

// ------------------ Multer Setup ------------------ //
const uploadDir = path.join(__dirname, "../uploads");
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir);

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, "uploads/"),
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname).toLowerCase());
  },
});

const upload = multer({ storage });

/**
 * POST /send
 * Create a new thread (if no threadId) or append a message to an existing thread (if threadId)
 * Expects: from (employeeId), to (JSON array of employeeIds OR comma-separated string), cc (optional), bcc (optional), subject, body, threadId (optional)
 * Attachments are available as files in req.files
 */
router.post("/send", upload.array("attachments", 10), async (req, res) => {
  try {
    const { from, to, cc, bcc, subject, body, threadId } = req.body;
    if (!from || !to) return res.status(400).json({ message: "From and To required" });

    const sender = await Employee.findOne({ employeeId: from });
    if (!sender) return res.status(404).json({ message: "Sender not found" });

    // Accept JSON string, array, or csv string and resolve to Employee objects
    const parseRecipients = async (val) => {
      let ids = [];
      if (Array.isArray(val)) ids = val;
      else if (typeof val === "string") {
        try {
          const parsed = JSON.parse(val);
          if (Array.isArray(parsed)) ids = parsed;
          else {
            // fallback: comma separated
            ids = val.split(",").map((s) => s.trim()).filter(Boolean);
          }
        } catch (e) {
          // not JSON -> comma separated
          ids = val.split(",").map((s) => s.trim()).filter(Boolean);
        }
      }

      const list = [];
      for (const id of ids) {
        const emp = await Employee.findOne({ employeeId: id });
        if (emp) {
          list.push({
            employeeId: emp.employeeId,
            employeeName: emp.employeeName,
            employeeImage: emp.employeeImage,
          });
        }
      }
      return list;
    };

    const toRecipients = await parseRecipients(to);
    const ccRecipients = cc ? await parseRecipients(cc) : [];
    const bccRecipients = bcc ? await parseRecipients(bcc) : [];

    // attachments safe guard and normalize path to /uploads/<filename>
    const attachments = (req.files || []).map((file) => ({
      filename: file.filename,                // multer's saved filename
      originalName: file.originalname,
      size: file.size,
      mimeType: file.mimetype,
      path: `/uploads/${file.filename}`,      // use a URL-friendly path
    }));

    // If client passed forwardAttachments (JSON array of server filenames),
    // include them as attachments referencing existing files in uploads/.
    // This avoids the need to re-upload already-stored files when forwarding.
    const forwardAttachmentsRaw = req.body.forwardAttachments;
    if (forwardAttachmentsRaw) {
      let forwardList = [];
      try {
        forwardList = Array.isArray(forwardAttachmentsRaw) ? forwardAttachmentsRaw : JSON.parse(forwardAttachmentsRaw);
      } catch (e) {
        // fallback if it's a CSV-like string
        forwardList = String(forwardAttachmentsRaw).split(",").map(s => s.trim()).filter(Boolean);
      }
      for (const fname of forwardList) {
        try {
          // attempt to stat the file to get size (best-effort)
          const realPath = path.join(__dirname, "..", "uploads", path.basename(fname));
          let size = 0;
          try {
            const stats = fs.statSync(realPath);
            size = stats.size;
          } catch (e) {
            // ignore stat error, size stays 0
          }
          attachments.push({
            filename: path.basename(fname),
            originalName: path.basename(fname),
            size,
            mimeType: '', // unknown, not critical
            path: `/uploads/${path.basename(fname)}`,
          });
        } catch (e) {
          // skip invalid entries
          console.warn("Ignoring forward attachment:", fname, e);
        }
      }
    }

    // ensure each message has timestamps
    const now = new Date();
    const message = {
      from: {
        employeeId: sender.employeeId,
        employeeName: sender.employeeName,
        employeeImage: sender.employeeImage,
      },
      to: toRecipients,
      cc: ccRecipients,
      bcc: bccRecipients,
      body,
      attachments,
      createdAt: now,
      updatedAt: now,
    };

    if (threadId) {
      // Append to existing thread
      const thread = await MailThread.findById(threadId);
      if (!thread) return res.status(404).json({ message: "Thread not found" });

      thread.messages.push(message);
      thread.lastUpdated = new Date();
      thread.lastMessagePreview = body ? String(body).slice(0, 200) : "";
      //for loop reply count
      thread.readBy = [sender.employeeId];

      // add participants (unique) from sender, to, cc, bcc
      const newParticipants = [
        sender.employeeId,
        ...toRecipients.map((r) => r.employeeId),
        ...ccRecipients.map((r) => r.employeeId),
        ...bccRecipients.map((r) => r.employeeId),
      ];
      thread.participants = Array.from(new Set([...(thread.participants || []), ...newParticipants]));
      await thread.save();
      return res.status(200).json({ message: "Appended to thread", thread });
    } else {
      // New thread
      const participants = Array.from(
        new Set([
          sender.employeeId,
          ...toRecipients.map((r) => r.employeeId),
          ...ccRecipients.map((r) => r.employeeId),
          ...bccRecipients.map((r) => r.employeeId),
        ])
      );
      const thread = new MailThread({
        subject: subject || "",
        participants,
        messages: [message],
        lastUpdated: new Date(),
        lastMessagePreview: body ? String(body).slice(0, 200) : "",
        readBy: [],
        trashedBy: [],
      });
      await thread.save();
      return res.status(201).json({ message: "Thread created", thread });
    }
  } catch (err) {
    console.error("Send mail error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * GET /inbox/:employeeId
 * Return threads where the user is a participant and hasn't trashed the thread
 * Filters out threads where all messages were authored by the employee (so a sender with no replies won't see that thread in inbox)
 */
router.get("/inbox/:employeeId", async (req, res) => {
  try {
    const empId = req.params.employeeId;
    // get candidate threads where user is participant and not trashed
    const threads = await MailThread.find({
      participants: empId,
      trashedBy: { $ne: empId },
    })
      .sort({ lastUpdated: -1 })
      .lean();

    // Filter out threads that contain only messages authored by the current user.
    // We want to show threads in the user's inbox only if someone else has sent a message in that thread.
    const filtered = threads.filter(thread => {
      if (!Array.isArray(thread.messages) || thread.messages.length === 0) return false;
      // show thread if there exists at least one message from someone other than empId
      return thread.messages.some(m => {
        const from = m && m.from;
        if (!from) return false;
        // handle both forms: m.from.employeeId (object) or m.from (string)
        const fromId = typeof from === 'string' ? from : (from.employeeId || "");
        return String(fromId) !== String(empId);
      });
    });

    res.json(filtered);
  } catch (err) {
    console.error("Inbox error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * GET /sent/:employeeId
 * Threads which have at least one message sent by this employee
 */
router.get("/sent/:employeeId", async (req, res) => {
  try {
    const empId = req.params.employeeId;
    const threads = await MailThread.find({
      "messages.from.employeeId": empId,
      trashedBy: { $ne: empId },
    }).sort({ lastUpdated: -1 });
    res.json(threads);
  } catch (err) {
    console.error("Sent error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * GET /thread/:threadId/:employeeId
 * View a single thread (all messages). Marks thread as read for this employee.
 */
router.get("/thread/:threadId/:employeeId", async (req, res) => {
  try {
    const { threadId, employeeId } = req.params;
    const thread = await MailThread.findById(threadId);
    if (!thread) return res.status(404).json({ message: "Thread not found" });

    // Mark read by this employee
    if (!Array.isArray(thread.readBy)) thread.readBy = [];
    if (!thread.readBy.includes(employeeId)) {
      thread.readBy.push(employeeId);
      await thread.save();
    }

    res.json(thread);
  } catch (err) {
    console.error("View thread error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * PUT /trash/:threadId/:employeeId
 * Soft-delete (move thread to trash for this user)
 */
router.put("/trash/:threadId/:employeeId", async (req, res) => {
  try {
    const { threadId, employeeId } = req.params;
    const thread = await MailThread.findById(threadId);
    if (!thread) return res.status(404).json({ message: "Thread not found" });

    if (!Array.isArray(thread.trashedBy)) thread.trashedBy = [];
    if (!thread.trashedBy.includes(employeeId)) {
      thread.trashedBy.push(employeeId);
      await thread.save();
    }
    res.json({ message: "Moved thread to trash" });
  } catch (err) {
    console.error("Trash error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * PUT /restore/:threadId/:employeeId
 * Restore thread from trash for this user
 */
router.put("/restore/:threadId/:employeeId", async (req, res) => {
  try {
    const { threadId, employeeId } = req.params;
    const thread = await MailThread.findById(threadId);
    if (!thread) return res.status(404).json({ message: "Thread not found" });

    thread.trashedBy = (thread.trashedBy || []).filter((id) => id !== employeeId);
    await thread.save();
    res.json({ message: "Thread restored" });
  } catch (err) {
    console.error("Restore error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * DELETE /delete-permanent/:threadId/:employeeId
 * Permanently delete a thread only if the requesting user has trashed it.
 * Optionally require all participants to have trashed it before permanent deletion.
 */
router.delete("/delete-permanent/:threadId/:employeeId", async (req, res) => {
  try {
    const { threadId, employeeId } = req.params;
    const thread = await MailThread.findById(threadId);
    if (!thread) return res.status(404).json({ message: "Thread not found" });

    // User must have trashed it first
    if (!Array.isArray(thread.trashedBy) || !thread.trashedBy.includes(employeeId)) {
      return res.status(403).json({ message: "Not allowed - thread not trashed by you" });
    }

    // 🔥 Remove this user completely from thread
    thread.participants = (thread.participants || []).filter(
      (id) => String(id) !== String(employeeId)
    );

    thread.trashedBy = (thread.trashedBy || []).filter(
      (id) => String(id) !== String(employeeId)
    );

    thread.readBy = (thread.readBy || []).filter(
      (id) => String(id) !== String(employeeId)
    );

    // If no participants left → delete thread from DB
    if (!thread.participants || thread.participants.length === 0) {
      await MailThread.findByIdAndDelete(threadId);
      return res.json({ message: "Thread fully deleted (no participants left)" });
    }

    await thread.save();

    res.json({ message: "Thread deleted for this user only" });

  } catch (err) {
    console.error("Delete permanent error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

// router.delete("/delete-permanent/:threadId/:employeeId", async (req, res) => {
//   try {
//     const { threadId, employeeId } = req.params;
//     const thread = await MailThread.findById(threadId);
//     if (!thread) return res.status(404).json({ message: "Thread not found" });

//     if (!Array.isArray(thread.trashedBy) || !thread.trashedBy.includes(employeeId)) {
//       return res.status(403).json({ message: "Not allowed - thread not trashed by you" });
//     }

//     // Require all participants to have trashed the thread before permanent delete
//     const participantCount = (thread.participants || []).length;
//     const trashedCount = (thread.trashedBy || []).length;
//     if (trashedCount < participantCount) {
//       return res.status(403).json({ message: "Others still have this thread" });
//     }

//     await MailThread.findByIdAndDelete(threadId);
//     res.json({ message: "Thread permanently deleted" });
//   } catch (err) {
//     console.error("Delete permanent error:", err);
//     res.status(500).json({ message: "Server error" });
//   }
// });

/**
 * GET /trash/:employeeId
 * Get threads that this employee has moved to trash
 */
router.get("/trash/:employeeId", async (req, res) => {
  try {
    const empId = req.params.employeeId;
    const threads = await MailThread.find({
      trashedBy: empId,
    }).sort({ lastUpdated: -1 });
    res.json(threads);
  } catch (err) {
    console.error("Trash fetch error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * GET /download?path=<path>
 * Download attachment file by path (safe resolution)
 */
router.get("/download", async (req, res) => {
  try {
    const { path: filePath } = req.query;
    if (!filePath) {
      return res.status(400).json({ message: "File path required" });
    }

    // Allow either a filename or a path like /uploads/<filename>
    const filename = path.basename(String(filePath));
    const full = path.join(__dirname, "..", "uploads", filename);

    if (!fs.existsSync(full)) return res.status(404).json({ message: "File not found" });

    res.download(full, filename);
  } catch (err) {
    console.error("❌ Error downloading file:", err);
    res.status(500).json({ message: "Server error" });
  }
});


/**
 * POST /drafts/save
 * Save or update a draft. Accepts optional multipart files as attachments.
 * If req.body.draftId present => update existing draft, else create new.
 */
router.post("/drafts/save", upload.array("attachments", 10), async (req, res) => {
  try {
    const { draftId, from, to, cc, bcc, subject, body } = req.body;
    if (!from) return res.status(400).json({ message: "From required" });

    // parse list helpers (accept JSON or CSV/string)
    const parseList = (val) => {
      if (!val) return [];
      if (Array.isArray(val)) return val;
      if (typeof val === "string") {
        try {
          const parsed = JSON.parse(val);
          if (Array.isArray(parsed)) return parsed;
        } catch (e) {
          // not JSON
        }
        return val.split(",").map(s => s.trim()).filter(Boolean);
      }
      return [];
    };

    const toList = parseList(to);
    const ccList = parseList(cc);
    const bccList = parseList(bcc);

    // attachments from upload (save metadata)
    const attachments = (req.files || []).map((file) => ({
      filename: file.filename,
      originalName: file.originalname,
      size: file.size,
      mimeType: file.mimetype,
      path: `/uploads/${file.filename}`,
    }));

    // If updating existing draft, merge attachments (append)
    if (draftId) {
      const draft = await Draft.findById(draftId);
      if (!draft) return res.status(404).json({ message: "Draft not found" });
      if (String(draft.from) !== String(from)) return res.status(403).json({ message: "Not owner" });

      draft.to = toList;
      draft.cc = ccList;
      draft.bcc = bccList;
      draft.subject = subject || "";
      draft.body = body || "";
      draft.attachments = [...(draft.attachments || []), ...attachments];
      draft.updatedAt = new Date();
      await draft.save();
      return res.json({ message: "Draft updated", draft });
    }

    // create new draft
    const newDraft = new Draft({
      from,
      to: toList,
      cc: ccList,
      bcc: bccList,
      subject: subject || "",
      body: body || "",
      attachments,
    });
    await newDraft.save();
    return res.status(201).json({ message: "Draft saved", draft: newDraft });
  } catch (err) {
    console.error("Draft save error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * GET /drafts/:employeeId
 * Fetch drafts for the given user.
 */
router.get("/drafts/:employeeId", async (req, res) => {
  try {
    const empId = req.params.employeeId;
    const drafts = await Draft.find({ from: empId }).sort({ updatedAt: -1 }).lean();
    res.json(drafts);
  } catch (err) {
    console.error("Drafts fetch error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * GET /draft/:draftId
 * Fetch single draft
 */
router.get("/draft/:draftId", async (req, res) => {
  try {
    const d = await Draft.findById(req.params.draftId).lean();
    if (!d) return res.status(404).json({ message: "Draft not found" });
    res.json(d);
  } catch (err) {
    console.error("Draft fetch error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * DELETE /draft/:draftId/:employeeId
 * Delete draft (only owner can delete)
 */
router.delete("/draft/:draftId/:employeeId", async (req, res) => {
  try {
    const { draftId, employeeId } = req.params;
    const draft = await Draft.findById(draftId);
    if (!draft) return res.status(404).json({ message: "Draft not found" });
    if (String(draft.from) !== String(employeeId)) return res.status(403).json({ message: "Not owner" });
    await Draft.findByIdAndDelete(draftId);
    res.json({ message: "Draft deleted" });
  } catch (err) {
    console.error("Draft delete error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * GET /pending-count
 * Get unread inbox thread count for dashboard badge (Consistent with Leave)
 */
router.get("/pending-count", async (req, res) => {
  try {
    const employeeId = req.query.employeeId;
    if (!employeeId) return res.status(400).json({ message: "employeeId required" });

    const threads = await MailThread.find({
      participants: employeeId,
      readBy: { $ne: employeeId },     // not read
      trashedBy: { $ne: employeeId },  // not trashed
    }).lean();

    // Filter threads that contain at least one message
    // from someone other than current employee
    const unreadThreads = threads.filter(thread => {
      if (!Array.isArray(thread.messages)) return false;

      return thread.messages.some(m => {
        const fromId =
          typeof m.from === "string"
            ? m.from
            : m.from?.employeeId;

        return String(fromId) !== String(employeeId);
      });
    });

    res.json({ pendingCount: unreadThreads.length });

  } catch (err) {
    console.error("Pending count error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * GET /unread-count/:employeeId
 * Get unread inbox thread count for dashboard badge
 */
router.get("/unread-count/:employeeId", async (req, res) => {
  try {
    const employeeId = req.params.employeeId;

    const threads = await MailThread.find({
      participants: employeeId,
      readBy: { $ne: employeeId },     // not read
      trashedBy: { $ne: employeeId },  // not trashed
    }).lean();

    // Filter threads that contain at least one message
    // from someone other than current employee
    const unreadThreads = threads.filter(thread => {
      if (!Array.isArray(thread.messages)) return false;

      return thread.messages.some(m => {
        const fromId =
          typeof m.from === "string"
            ? m.from
            : m.from?.employeeId;

        return String(fromId) !== String(employeeId);
      });
    });

    res.json({ unreadCount: unreadThreads.length });

  } catch (err) {
    console.error("Unread count error:", err);
    res.status(500).json({ message: "Server error" });
  }
});


module.exports = router;