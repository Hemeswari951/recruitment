const mongoose = require("mongoose"); 

 
 

const AttachmentSchema = new mongoose.Schema({ 

  filename: String, 

  originalName: String, 

  size: Number, 

  mimeType: String, 

  path: String, 

}, { _id: false }); 

 
 

const MailSchema = new mongoose.Schema( 

  { 

    from: { 

      type: String,   // employeeId of sender 

      required: true, 

      trim: true, 

    }, 

    to: { 

      type: String,   // employeeId of receiver 

      required: true, 

      trim: true, 

    }, 

    subject: { 

      type: String, 

      default: "", 

    }, 

    body: { 

      type: String, 

      default: "", 

    }, 

    attachments: [AttachmentSchema], 

 
 

    read: { type: Boolean, default: false }, 

    archived: { type: Boolean, default: false }, 

    trashed: { type: Boolean, default: false }, 

  }, 

  { timestamps: true } 

); 

 
 

module.exports = mongoose.model("Mail", MailSchema);