// routes/changerequests.js
const express = require('express');
const router = express.Router();
const ChangeRequest = require('../models/changeRequest');
const Profile = require('../models/profile'); // profile collection with id/position/full_name
const Employee = require('../models/employee');

// Helper: normalize role string
function normalizeRole(raw) {
  if (!raw) return '';
  return raw.toString().trim().toLowerCase();
}

// Decide approver based on requester role
function decideApproverRole(requesterRole) {
  requesterRole = normalizeRole(requesterRole);
  if (!requesterRole) return 'hr'; // default fallback

  if (requesterRole.includes('hr')) {
    return 'founder'; // HR requests go to Founder
  }
  if (requesterRole.includes('founder') || requesterRole.includes('superadmin')) {
    return 'founder'; // Founder/superadmin -> founder
  }

  // employees, interns, trainees -> HR approver
  // treat 'tech trainee' and 'intern' as employee group
  return 'hr';
}

// --------------------
// Create a change request (employee or any user)
router.post('/profile/:id/request-change', async (req, res) => {
  try {
    const employeeId = req.params.id;
    const { fullName, field, oldValue, newValue, requestedBy } = req.body;
    console.log('🟢 [CREATE REQUEST] Incoming:', { employeeId, field, newValue, requestedBy });

    if (!field || typeof newValue === 'undefined') {
      return res.status(400).json({ message: 'field and newValue required' });
    }

    // Attempt to fetch the target employee profile (employee whose profile is changing)
    const targetProfile = await Profile.findOne({ id: employeeId }).lean();

    // Find the requester profile (if requestedBy provided). If not provided, assume the requester is the targetEmployee.
    let requesterProfile;
    if (requestedBy) {
      requesterProfile = await Profile.findOne({ id: requestedBy }).lean();
    }
    if (!requesterProfile) {
      requesterProfile = targetProfile; // fallback
    }

    const requesterRoleRaw = requesterProfile?.position || requesterProfile?.role || requesterProfile?.designation || '';
    const requesterRole = normalizeRole(requesterRoleRaw);
    const approverRole = decideApproverRole(requesterRole);

    const request = new ChangeRequest({
      employeeId,
      full_name: fullName || targetProfile?.full_name || '',
      field,
      oldValue: oldValue ?? '',
      newValue: newValue.toString(),
      requestedBy: requestedBy ?? (requesterProfile?.id || employeeId),
      requestedByName: requesterProfile?.full_name || req.body.requestedByName || '',
      requestedByRole: requesterRole,
      approverRole,
    });

    await request.save();
    console.log('✅ Request saved:', request._id, 'approverRole=', approverRole);

    res.status(201).json({ message: '✅ Request created', request });
  } catch (err) {
    console.error('❌ Failed to create request:', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// --------------------
// Approve a request
router.post('/:id/approve', async (req, res) => {
  try {
    const requestId = req.params.id.trim();
    const resolver = req.body.resolvedBy || 'superadmin';

    const reqDoc = await ChangeRequest.findById(requestId);
    if (!reqDoc) return res.status(404).json({ message: 'Request not found' });
    if (reqDoc.status !== 'pending') {
      return res.status(400).json({ message: 'Request already resolved' });
    }

    // Update the profile document
    const updateObj = {};
    updateObj[reqDoc.field] = reqDoc.newValue;

    const updatedProfile = await Profile.findOneAndUpdate(
      { id: reqDoc.employeeId },
      { $set: updateObj },
      { new: true }
    );

    if (!updatedProfile) {
      console.log("❌ No profile found for:", reqDoc.employeeId);
      return res.status(404).json({ message: 'Employee profile not found' });
    }

    // Also try to sync Employee collection if applicable
    try {
      await Employee.updateOne(
        { employeeId: reqDoc.employeeId },
        { $set: updateObj }
      );
    } catch (syncErr) {
      console.warn('⚠️ Employee update sync failed:', syncErr);
    }

    reqDoc.status = 'approved';
    reqDoc.resolvedAt = new Date();
    reqDoc.resolvedBy = resolver;
    await reqDoc.save();

    res.status(200).json({
      message: '✅ Request approved and applied',
      request: reqDoc,
      employee: updatedProfile,
    });
  } catch (err) {
    console.error('❌ Failed to approve request:', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// --------------------
// Decline a request
router.post('/:id/decline', async (req, res) => {
  try {
    const requestId = req.params.id;
    const resolver = req.body.resolvedBy || 'superadmin';

    const reqDoc = await ChangeRequest.findById(requestId);
    if (!reqDoc) return res.status(404).json({ message: 'Request not found' });
    if (reqDoc.status !== 'pending') {
      return res.status(400).json({ message: 'Request already resolved' });
    }

    reqDoc.status = 'declined';
    reqDoc.resolvedAt = new Date();
    reqDoc.resolvedBy = resolver;
    await reqDoc.save();

    res.status(200).json({ message: '❌ Request declined', request: reqDoc });
  } catch (err) {
    console.error('❌ Failed to decline request:', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// --------------------
// List requests (supports filtering by status and approverRole)
router.get('/', async (req, res) => {
  try {
    const status = req.query.status || 'pending';
    const approverRole = req.query.approverRole ? req.query.approverRole.toString().trim().toLowerCase() : null;

    let query = status ? { status } : {};

    if (approverRole) {
      // founder should be able to see hr + founder assigned requests
      if (approverRole === 'founder') {
        query = { status, $or: [{ approverRole: 'founder' }, { approverRole: 'hr' }] };
      } else {
        query.approverRole = approverRole;
      }
    }

    const requests = await ChangeRequest.find(query).sort({ createdAt: -1 }).lean();
    res.status(200).json(requests);
  } catch (err) {
    console.error('❌ Failed to fetch requests:', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// --------------------
// Get pending count for an approver role
router.get('/count', async (req, res) => {
  try {
    const status = req.query.status || 'pending';
    const approverRole = req.query.approverRole ? req.query.approverRole.toString().trim().toLowerCase() : null;

    let query = { status };

    if (approverRole) {
      if (approverRole === 'founder') {
        // founder sees both hr-assigned and founder-assigned requests
        query = { status, $or: [{ approverRole: 'founder' }, { approverRole: 'hr' }] };
      } else {
        query.approverRole = approverRole;
      }
    }

    const pendingCount = await ChangeRequest.countDocuments(query);
    res.status(200).json({ pendingCount });
  } catch (err) {
    console.error('❌ Failed to count requests:', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// --------------------
// Get single request
router.get('/:id', async (req, res) => {
  try {
    const reqDoc = await ChangeRequest.findById(req.params.id).lean();
    if (!reqDoc) return res.status(404).json({ message: 'Request not found' });
    res.status(200).json(reqDoc);
  } catch (err) {
    console.error('❌ Failed to fetch request:', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

module.exports = router;