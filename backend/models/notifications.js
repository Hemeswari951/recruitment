//models/notifications.js

const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema({
  category: {
    type: String,
    required: true,
    enum: ["message", "performance", "meeting", "event", "holiday", "leave"]
  },

  holidayType: {
    type: String,
    enum: ["FIXED", "FLOATING"],
    required: function () {
      return this.category === "holiday";
    }
  },

  month: {
    type: String,
    enum: [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ],
    required: true 
  },

  day: {
    type: Number,
    min: 1,
    max: 31,
    required: function () {
      return this.category === "holiday";
    }
  },

  year: {
    type: Number,
    required: true, 
    index: true
  },

  state: {
    type: String,
    default: "TN"
  },

  message: {
    type: String,
    required: false 
  },

  messages: [
    {
      senderId: String,
      senderName: String,
      receiverId: { type: String, default: "" },
      receiverName: { type: String, default: "" },
      text: String,
      attachments: Array,
      createdAt: { type: Date, default: Date.now },
      replyTo: {
        messageId: String,
        text: String,
        senderName: String,
        attachments: [
          {
            filename: String,
            originalName: String,
            path: String,
            mimetype: String,
            size: Number
          }
        ]
      },
      deletedBy: {
        type: [String],
        default: []
      }
    }
  ],

  empId: {
    type: String,
    required: function () {
      return this.category === "performance";
    }
  },
  receiverId: {
  type: String,
  required: function () {
    return this.category === "performance";
  }
},

reviewId: String,
senderId: String,
senderName: String,

flag: {
  type: String,
  required: function () {
    return this.category === "performance";
  }
},
  reviewId:  String,
  senderId:  String,
  senderName:  String,
  communication:  String,
  attitude:  String,
  technicalKnowledge:  String,
  business:  String,
  empName:  String,
  receiverName:String,
  attachments: [
    {
      filename: String,      // original file name
      originalName: String,  // field added to match route logic
      path: String,          // server path
      mimetype: String,
      size: Number
    }
  ],
  isRead: {
    type: Boolean,
    default: false,
    index: true
  },

  createdAt: { type: Date, default: Date.now },

  hiddenFor: {
    type: [String],
    default: []
  },

  readBy: {
  type: [String],
  default: [],
  index: true
},

},{ timestamps: true });

module.exports = mongoose.model("Notification", notificationSchema);