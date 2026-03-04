//routes/notifications.js 

const express = require('express');
const router = express.Router();
const Notification = require("../models/notifications");
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// =======================
// MULTER CONFIG (Attachments)
// =======================
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = 'uploads/notifications';
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    cb(null, Date.now() + '-' + file.originalname);
  }
});

const upload = multer({ storage });

// 🔹 Get ALL notifications for a specific employee with optional month & category filter
router.get('/employee/:empId', async (req, res) => {
  try {
    const { empId } = req.params;
    const { month, year, category, source } = req.query;

    // ===============================
    // ✅ CHAT SIDEBAR MODE
    // ===============================
    if (source === "chat") {

      const chats = await Notification.find({
        category: "message",
        $or: [
          { empId: empId },
          { receiverId: empId }
        ],
        hiddenFor: { $ne: empId }
      }).sort({ updatedAt: -1 });

      const result = chats.map(chat => {

          const partnerId =
            chat.empId === empId ? chat.receiverId : chat.empId;

          // 🔥 Filter messages visible to this user
          const visibleMsgs = (chat.messages || []).filter(
            m => !(m.deletedBy || []).includes(empId)
          );

          // 🔥 If no visible messages → hide from sidebar
          if (visibleMsgs.length === 0) {
            return null;
          }

          const lastMsg = visibleMsgs[visibleMsgs.length - 1];
          const partnerName =
              chat.senderId === empId
                ? chat.receiverName || ""
                : chat.senderName || "";

          return {
            _id: chat._id,
            partnerId: partnerId,
            senderName: partnerName,
            lastMessage:
              lastMsg.text ||
              (lastMsg.attachments?.length > 0 ? "📎 Attachment" : ""),
            lastTime: lastMsg.createdAt || chat.updatedAt,
            isRead: chat.isRead || false
          };
        })
        .filter(Boolean); 

      return res.json(result);
    }

    // ===============================
    // ✅ NORMAL NOTIFICATION MODE
    // ===============================
    let query = {
      $or: [
        { empId: empId },
        { receiverId: empId }
      ]
    };

    if (source !== 'chat') {
      query.hiddenFor = { $ne: empId };
    }

    if (category) query.category = category;
    if (month) query.month = { $regex: new RegExp(`^${month}$`, 'i') };
    if (year) query.year = Number(year);

    const notifications = await Notification.find(query)
      .sort({ updatedAt: -1 });

    res.json(notifications || []);

  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});


// 🔹 HOLIDAYS
// Employee holidays
router.get('/holiday/employee/:empId', async (req, res) => {
  try {
    const { empId } = req.params;
    const { month, year } = req.query;

    const query = {
      category: "holiday",
      $or: [{ empId }, { empId: null }, { empId: "" }]
    };

    if (month) {
      query.month = { $regex: new RegExp(`^${month}$`, 'i') };
    }

    if (year) {
      query.year = Number(year);
    }

    const holidays = await Notification.find(query)
      .sort({ year: 1, month: 1, day: 1 });

    if (!holidays.length) {
      return res.status(404).json({ message: "No holiday notifications found" });
    }

    res.json(holidays);
  } catch (err) {
    console.error("Error fetching employee holiday notifications:", err);
    res.status(500).json({ message: "Server error" });
  }
});

// Admin holidays
router.get('/holiday/admin/:month', async (req, res) => {
  try {
    const { month } = req.params;
    const { year } = req.query;

    const query = {
      category: "holiday",
      month: { $regex: new RegExp(`^${month}$`, 'i') }
    };

    if (year) {
      query.year = Number(year);
    }

    const holidays = await Notification.find(query).sort({ createdAt: -1 });

    if (!holidays.length) {
      return res.status(404).json({ message: "No holiday notifications for admin" });
    }

    res.json(holidays);
  } catch (err) {
    console.error("Error fetching admin holiday notifications:", err);
    res.status(500).json({ message: "Server error" });
  }
});

// 1. Performance → Admin view (Optimized)
router.get('/performance/admin/:adminId', async (req, res) => {
    const { adminId } = req.params;
    const { month, year } = req.query;
    try {
        const query = {
          category: "performance",
          empId: adminId,  // 👈 Only show the copy owned by the Admin
          // receiverId: { $ne: adminId } // 👈 Ensures it's a 'Sent' record
        };

        if (month) query.month = { $regex: new RegExp(`^${month}$`, 'i') };
        if (year) query.year = Number(year);

        const notifications = await Notification.find(query).sort({ createdAt: -1 });
        res.json(notifications || []);
    } catch (err) {
        res.status(500).json({ message: 'Server error' });
    }
});

// 2. Performance → Employee view
router.get('/performance/employee/:month/:empId', async (req, res) => {
  const { month, empId } = req.params;
  const { year } = req.query; // ✅ Added year filter support
  try {
    const query = {
      category: "performance",
      month: { $regex: new RegExp(`^${month}$`, 'i') },
      $or: [{ empId }, { empId: null }, { empId: "" }],
    };

    if (year) query.year = Number(year);

    const notifications = await Notification.find(query).sort({ createdAt: -1 });

    if (!notifications.length) {
      return res.status(404).json({ message: "No performance notifications for this employee" });
    }

    res.json(notifications);
  } catch (err) {
    console.error("Error fetching performance for employee:", err);
    res.status(500).json({ message: 'Server error' });
  }
});

// 3. PERFORMANCE: SUPER ADMIN VIEW (All Reviews)

router.get('/performance/superadmin/all', async (req, res) => {
    try {
        const { month, year } = req.query;
        let query = { category: "performance" };

        if (month) query.month = { $regex: new RegExp(`^${month}$`, 'i') };
        if (year) query.year = Number(year);

        const notifications = await Notification.find(query).sort({ createdAt: -1 });
        res.json(notifications);
    } catch (err) {
        res.status(500).json({ message: "Server error" });
    }
});

// 1️⃣ Get holidays by YEAR (Holiday Master main fetch)
router.get('/holiday/year/:year', async (req, res) => {
  try {
    const { year } = req.params;

    const holidays = await Notification.find({
      category: "holiday",
      year: Number(year),
      state: "TN"
    }).sort({ month: 1, day: 1 });

    if (!holidays.length) {
      return res.json({ data: [], message: "NO_RECORDS" });
    }

    res.json({ data: holidays });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// 2️⃣ Clone holidays from previous year
router.post('/holiday/clone', async (req, res) => {
  try {
    const { fromYear, toYear } = req.body;

    if (fromYear === toYear) {
      return res.status(400).json({ message: "Same year clone not allowed" });
    }

    const exists = await Notification.findOne({
      category: "holiday",
      year: toYear
    });

    if (exists) {
      return res.status(409).json({ message: "Target year already exists" });
    }

    const prevHolidays = await Notification.find({
      category: "holiday",
      year: fromYear
    });

    if (!prevHolidays.length) {
      return res.status(404).json({ message: "Previous year not found" });
    }

    const cloned = prevHolidays.map(h => ({
      category: "holiday",
      holidayType: h.holidayType,
      year: toYear,
      month: h.month,
      day: h.day,
      message: h.message,
      state: "TN"
    }));

    await Notification.insertMany(cloned);

    res.json({ message: "Holiday cloned successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// UPDATE holiday
router.put('/holiday/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { year, month, day, message, holidayType } = req.body;

    await Notification.findByIdAndUpdate(id, {
      year,
      month,
      day,
      message,
      holidayType
    });

    res.json({ message: "Holiday updated" });
  } catch (err) {
    res.status(500).json({ message: "Server error" });
  }
});

// DELETE holiday
router.delete('/holiday/:id', async (req, res) => {
  try {
    await Notification.findByIdAndDelete(req.params.id);
    res.json({ message: "Holiday deleted" });
  } catch (err) {
    res.status(500).json({ message: "Server error" });
  }
});

// 3️⃣ Add / Edit single holiday (popup save)
router.post('/holiday', async (req, res) => {
  try {
    const { year, month, day, message, holidayType } = req.body;

    const holiday = new Notification({
      category: "holiday",
      year,
      month,
      day,
      message,
      holidayType,
      state: "TN"
    });

    await holiday.save();
    res.status(201).json({ message: "Holiday saved" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// ✅ Add a new notification
router.post('/', async (req, res) => {
  try {
    const { month, year, category, message, empId, senderName, senderId, flag , communication, attitude, technicalKnowledge, business, empName, receiverId } = req.body;
    if (!message || !empId || !category) {
      return res.status(400).json({ message: "Required fields missing" });
    }
    const newNotification = new Notification({ 
      month, 
      year: year || new Date().getFullYear(), // Handle year if missing
      category, 
      message, 
      empId,
      receiverId: receiverId || "",
      senderName: senderName || "",
      senderId: senderId || "",
      flag: flag || "" ,
      // 🔹 Save Performance Specifics
      communication: communication || "",
      attitude: attitude || "",
      technicalKnowledge: technicalKnowledge || "",
      business: business || "",
      empName: empName || ""
    });

    await newNotification.save();
    res.status(201).json({ message: 'Notification added successfully' });
  } catch (err) {
    console.error('Error adding notification:', err);
    res.status(500).json({ message: 'Server error' });
  }
});


// ADD NOTIFICATION WITH ATTACHMENTS
// =======================
router.post("/with-files", upload.array("attachments"), async (req, res) => {
  try {
    const {
      category,
      month,
      year,
      empId,
      receiverId,
      senderId,
      senderName
    } = req.body;

    // ✅ Parse reply JSON from Flutter
    let replyData = null;

    if (req.body.replyTo) {
      try {
        replyData = JSON.parse(req.body.replyTo);
      } catch (err) {
        console.log("Reply parse error:", err);
      }
    }

    // ✅ Safely handle undefined/empty message
    const messageText = req.body.message ? req.body.message.trim() : "";

    if (category !== "message") {
      return res.status(400).json({ error: "Invalid category" });
    }

    const files = (req.files || []).map(file => ({
      filename: file.filename,
      originalName: file.originalname,
      path: file.path.replace(/\\/g, "/"),
      mimetype: file.mimetype,
      size: file.size
    }));

    // ✅ Validate that EITHER text OR an attachment is provided
    if (!messageText && files.length === 0) {
      return res.status(400).json({ error: "Message or attachment required" });
    }

    // ✅ Create the preview label for the notification card
    const previewMsg = messageText || (files.length > 0 ? "📎 Attachment" : "");

    const sortedIds = [empId, receiverId].sort();
    const conversationEmpId = sortedIds[0];
    const conversationReceiverId = sortedIds[1];

    let existingConversation = await Notification.findOne({
      category: "message",
      $or: [
        { empId: conversationEmpId, receiverId: conversationReceiverId },
        { empId: conversationReceiverId, receiverId: conversationEmpId }
      ]
    });

    // ✅ IF CONVERSATION EXISTS
    // ===============================
   
    if (existingConversation) {
      existingConversation.messages.push({
        senderId,
        senderName,
        text: messageText,
        attachments: files || [],
        createdAt: new Date(),

        replyTo: replyData
          ? {
              messageId: replyData.messageId,
              text: replyData.text,
              senderName: replyData.senderName,
              attachments: replyData.attachments || []
            }
          : null
      });

      // Update latest preview
      existingConversation.message = previewMsg;
      existingConversation.isRead = false;
      existingConversation.updatedAt = new Date();
      existingConversation.senderId = senderId;
      existingConversation.senderName = senderName;

      // ✅ ADD THIS LINE: Unhide for everyone because a new message arrived
      existingConversation.hiddenFor = [];

      await existingConversation.save();

      return res.status(200).json({
        message: "Reply added to existing conversation"
      });
    }

    // ===============================
    // ✅ CREATE NEW CONVERSATION ONLY IF NOT EXISTS
    // ===============================
    const newConversation = new Notification({
      category,
      month,
      year,
      message: previewMsg,
      empId: conversationEmpId,
      receiverId: conversationReceiverId,
      senderId,
      senderName,
      messages: [
        {
          senderId,
          senderName,
          text: messageText,
          attachments: files || [],
          createdAt: new Date(),
          updatedAt: new Date(),

          replyTo: replyData
            ? {
                messageId: replyData.messageId,
                text: replyData.text,
                senderName: replyData.senderName,
                attachments: replyData.attachments || []
              }
            : null
        }
      ],
      isRead: false
    });

    await newConversation.save();

    res.status(201).json({
      message: "New conversation created"
    });

  } catch (error) {
    console.error("Message error:", error);
    res.status(500).json({ error: "Server error" });
  }
});


router.get('/unread-count/:empId', async (req, res) => {
  try {
    const { empId } = req.params;

    const chatCount = await Notification.countDocuments({
      category: "message",
      $or: [
        { empId, senderId: { $ne: empId } },
        { receiverId: empId, senderId: { $ne: empId } }
      ],
      isRead: false,
      hiddenFor: { $ne: empId }
    });

    // 2️⃣ Normal notifications (non-message): unread, visible, not hidden
    const normalCount = await Notification.countDocuments({
      category: { $ne: "message" },
      $or: [{ empId }, { receiverId: empId }],
      isRead: false,
      hiddenFor: { $ne: empId }
    });

    // 3️⃣ Holiday notifications: unread for this user, not hidden
    const holidayCount = await Notification.countDocuments({
      category: "holiday",
      readBy: { $nin: [empId] },
      hiddenFor: { $ne: empId }
    });

    // Total unread count
    const totalUnread = chatCount + normalCount + holidayCount;

    res.json({ count: totalUnread });

  } catch (err) {
    console.error("Unread count error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

router.put('/mark-read/:empId', async (req, res) => {
  try {
    const { empId } = req.params;

    // ✅ Non-message notifications
    await Notification.updateMany(
      {
        isRead: false,
        category: { $ne: "message" },
        $or: [{ empId }, { receiverId: empId }]
      },
      { $set: { isRead: true } }
    );
    // ✅ Mark holidays as read only for THIS user
    await Notification.updateMany(
      {
        category: "holiday",
        readBy: { $nin: [empId] }
      },
      {
        $push: { readBy: empId }
      }
    );
    // ✅ Chat messages (only if user is NOT sender)
    await Notification.updateMany(
      {
        category: "message",
        isRead: false,
        senderId: { $ne: empId },
        $or: [{ empId }, { receiverId: empId }]
      },
      { $set: { isRead: true } }
    );

    res.json({ message: "Notifications marked as read" });

  } catch (err) {
    console.error("Mark read error:", err);
    res.status(500).json({ message: "Server error" });
  }
});
 
// 4. CHAT: Get conversation between two users

router.get('/chat-conversation/:user1/:user2', async (req, res) => {
  try {
    const { user1, user2 } = req.params;

    // 🔥 Same sorting logic used during save
    const sortedIds = [user1, user2].sort();
    const conversationEmpId = sortedIds[0];
    const conversationReceiverId = sortedIds[1];

    // 🔥 Find the single conversation document
    const conversation = await Notification.findOne({
      category: "message",
      empId: conversationEmpId,
      receiverId: conversationReceiverId
    });

    if (!conversation) {
      return res.json([]);
    }

    let messages = conversation.messages || [];

    // 🔥 Always sort by time ascending (old → new)
    messages = messages.sort(
      (a, b) => new Date(a.createdAt) - new Date(b.createdAt)
    );

    // 🔥 Filter deleted for this user
    const visibleMessages = messages.filter(
      m => !(m.deletedBy || []).includes(user1)
    );

    res.json(visibleMessages);

  } catch (err) {
    console.error("Error fetching chat history:", err);
    res.status(500).json({ message: "Server error" });
  }
});


// ✅ NEW ENDPOINT: Delete specific messages PERMANENTLY for both sides (Delete for Everyone)
router.put('/chat-conversation/:user1/:user2/delete-messages', async (req, res) => {
  try {
    const { user1, user2 } = req.params; 
    const { messageIds } = req.body;
    
    if (!messageIds || messageIds.length === 0) {
      return res.status(400).json({ error: "No messages selected" });
    }

    const sortedIds = [user1, user2].sort();
    const mongoose = require('mongoose');
    // Safely cast string IDs to ObjectIds for subdocument matching
    const objectIds = messageIds.map(id => new mongoose.Types.ObjectId(id));

    // ✅ Use $pull to PERMANENTLY remove the messages from the array for BOTH users
    const conversation = await Notification.findOneAndUpdate(
      {
        category: "message",
        $or: [
          { empId: sortedIds[0], receiverId: sortedIds[1] },
          { empId: sortedIds[1], receiverId: sortedIds[0] }
        ]
      },
      {
        $pull: { messages: { _id: { $in: objectIds } } }
      },
      { new: true } // Returns the updated document after deletion
    );

    // ✅ Automatically update the Sidebar preview text to the new last message
    if (conversation) {
      if (conversation.messages.length > 0) {
        const lastMsg = conversation.messages[conversation.messages.length - 1];
        conversation.message = lastMsg.text || (lastMsg.attachments.length > 0 ? "📎 Attachment" : "");
      } else {
        conversation.message = ""; // Clears preview if chat is empty
      }
      conversation.updatedAt = new Date();
      await conversation.save();
    }

    res.json({ message: "Messages deleted permanently for everyone" });
  } catch (err) {
    console.error("Error deleting messages:", err);
    res.status(500).json({ message: "Server error" });
  }
});

// ✅ Delete messages ONLY for current user (Delete for Me)
router.put('/chat-conversation/:user1/:user2/delete-for-me', async (req, res) => {
  try {
    const { user1, user2 } = req.params;
    const { messageIds } = req.body;

    if (!messageIds || messageIds.length === 0) {
      return res.status(400).json({ error: "No messages selected" });
    }

    const sortedIds = [user1, user2].sort();

    const conversation = await Notification.findOne({
      category: "message",
      empId: sortedIds[0],
      receiverId: sortedIds[1]
    });

    if (!conversation) {
      return res.status(404).json({ error: "Conversation not found" });
    }

    // ✅ Mark deleted for this user
    conversation.messages.forEach(msg => {
      if (messageIds.includes(msg._id.toString())) {
        if (!msg.deletedBy.includes(user1)) {
          msg.deletedBy.push(user1);
        }
      }
    });

    // ✅ Check remaining visible messages
    const visibleMsgs = conversation.messages.filter(
      m => !(m.deletedBy || []).includes(user1)
    );

    // ✅ Hide conversation if nothing visible
    if (visibleMsgs.length === 0) {
      if (!conversation.hiddenFor.includes(user1)) {
        conversation.hiddenFor.push(user1);
      }
    }

    conversation.updatedAt = new Date();

    await conversation.save();

    res.json({ message: "Messages deleted for current user" });

  } catch (err) {
    console.error("Delete for me error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

// Hide a notification for a specific employee (PUT /notifications/hide/:id)
router.put('/hide/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { empId } = req.body;

    if (!empId) {
      return res.status(400).json({ message: "empId is required" });
    }

    const notification = await Notification.findById(id);
    if (!notification) {
      return res.status(404).json({ message: "Notification not found" });
    }

    // Only hide if not already hidden
    if (!notification.hiddenFor.includes(empId)) {
      notification.hiddenFor.push(empId);
      await notification.save();
    }

    res.json({ message: "Notification hidden successfully" });
  } catch (err) {
    console.error("Hide notification error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

module.exports = router;