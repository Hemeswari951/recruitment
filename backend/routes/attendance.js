//backend/routes/attendance.js
const express = require("express");
const Attendance = require("../models/attendance");
const router = express.Router();


function timeToMinutes(timeStr) {
  if (!timeStr) return 0;

  const [time, modifier] = timeStr.split(" ");
  let [hours, minutes] = time.split(":").map(Number);

  if (modifier === "PM" && hours !== 12) hours += 12;
  if (modifier === "AM" && hours === 12) hours = 0;

  return hours * 60 + minutes;
}

// 🔹 Utility: Always return DD-MM-YYYY
function formatDateToDDMMYYYY(dateInput) {
  if (!dateInput) {
    const today = new Date();
    const day = String(today.getDate()).padStart(2, "0");
    const month = String(today.getMonth() + 1).padStart(2, "0");
    const year = today.getFullYear();
    return `${day}-${month}-${year}`;
  }

  if (typeof dateInput === "string" && /^\d{2}-\d{2}-\d{4}$/.test(dateInput)) {
    return dateInput;
  }

  const d = new Date(dateInput);
  const day = String(d.getDate()).padStart(2, "0");
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const year = d.getFullYear();
  return `${day}-${month}-${year}`;
}

// ✅ POST: Save attendance (Login)
router.post("/attendance/mark/:employeeId", async (req, res) => {
  const { employeeId } = req.params;
  let { date, loginTime, logoutTime, breakTime, loginReason, logoutReason, status } = req.body;

  try {
    date = formatDateToDDMMYYYY(date);

    let existing = await Attendance.findOne({ employeeId, date });

    if (existing) {
      if (existing.status === "Login") {
        return res.status(400).json({ message: "❌ Already Logged In" });
      }

      existing.status = "Login";
      existing.loginTime = loginTime;
      existing.logoutTime = ""; // reset until actual logout
      existing.loginReason = loginReason || existing.loginReason;

      await existing.save();
      return res.status(200).json({ 
        message: "✅ Attendance updated to Login", 
        attendance: existing 
      });
    }

    // ✅ New record
    const newAttendance = new Attendance({
      employeeId,
      date,
      loginTime,
      logoutTime: "", // keep empty, not "Not logged out yet"
      breakTime: breakTime || "-",
      loginReason,
      logoutReason,
      status: status || "Login",
      attendanceType: "P", // ✅ FIX HERE
    });

    await newAttendance.save();
    res.status(201).json({ message: "✅ Attendance saved successfully", attendance: newAttendance });

  } catch (error) {
    console.error("❌ Error saving attendance:", error);
    res.status(500).json({ message: "Server Error" });
  }
});

// --- replace current PUT /attendance/update/:employeeId handler with this ---

router.put("/attendance/update/:employeeId", async (req, res) => {
  const { employeeId } = req.params;
  let { date, logoutTime, breakTime, breakStatus, loginReason, logoutReason, status } = req.body;

  try {
    date = formatDateToDDMMYYYY(date || undefined);
    const todayRecord = await Attendance.findOne({ employeeId, date });
    if (!todayRecord) return res.status(404).json({ message: "❌ Attendance not found" });

    if (!todayRecord.breakTime) todayRecord.breakTime = "-";

    // server formatted time "hh:mm:ss AM/PM"
    const serverNowFormatted = () => {
      return new Date().toLocaleTimeString('en-US', {
        hour12: true,
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      });
    };

    const computeStoredTotal = (breakTimeStr) => {
      let total = 0;
      if (!breakTimeStr || breakTimeStr === "-") return 0;
      const segments = breakTimeStr.split(",");
      for (let seg of segments) {
        const match = seg.match(/\((\d+)\s*mins\)/);
        if (match) total += parseInt(match[1]);
      }
      return total;
    };

    // --- BreakIn: Start break (do NOT block when total >= 60) ---
    if (breakStatus === "BreakIn") {
      let totalMinutes = computeStoredTotal(todayRecord.breakTime);

      // Use server timestamp to start break
      const serverStart = serverNowFormatted();
      todayRecord.breakInProgress = serverStart;
      todayRecord.status = "Break";
      await todayRecord.save();

      return res.json({
        message: "⏸ Break started",
        breakInProgress: todayRecord.breakInProgress,
        totalMinutes,
        // limitReached is only informational now, not an error block
        limitReached: totalMinutes >= 60
      });
    }

    // --- BreakOff: finalize break and calculate total (allow totals > 60) ---
    if (breakStatus === "BreakOff" && todayRecord.breakInProgress) {
      const breakStart = todayRecord.breakInProgress;
      const breakEnd = serverNowFormatted(); // server-determined end time

      let breakArray = [];
      if (todayRecord.breakTime && todayRecord.breakTime !== "-") {
        breakArray = todayRecord.breakTime
          .split(",")
          .map((b) => b.trim().split(" (")[0]); // existing stored ranges (without durations)
      }

      breakArray.push(`${breakStart} to ${breakEnd}`);
      todayRecord.breakInProgress = null;

      // parse "hh:mm:ss AM/PM" to minutes since midnight
      const parseTime = (timeStr) => {
        if (!timeStr) return 0;
        const [time, modifier] = timeStr.split(" ");
        const timeParts = time.split(":").map(Number);
        let hours = timeParts[0] || 0;
        let minutes = timeParts[1] || 0;
        // ignore seconds for calculation simplicity
        if (modifier === "PM" && hours !== 12) hours += 12;
        if (modifier === "AM" && hours === 12) hours = 0;
        return hours * 60 + minutes;
      };

      let totalMinutes = 0;
      const formattedBreaks = [];

      for (const segment of breakArray) {
        const [start, end] = segment.split("to").map((t) => t.trim());
        let startMin = parseTime(start);
        let endMin = parseTime(end);
        let diff = endMin - startMin;

        // handle cross-midnight
        if (diff < 0) diff += 24 * 60;
        diff = Math.max(diff, 0);

        // here we **do not** truncate segment to fit 60; we store full segment
        formattedBreaks.push(`${start} to ${end} (${diff} mins)`);
        totalMinutes += diff;
      }

      // store full total (may exceed 60)
      todayRecord.breakTime = formattedBreaks.join(", ") + ` (Total: ${totalMinutes} mins)`;
      todayRecord.status = "Login";
      await todayRecord.save();

      const limitReached = totalMinutes >= 60;
      const overtimeMinutes = Math.max(0, totalMinutes - 60);

      return res.status(200).json({
        message: limitReached
          ? "⚠ Total break time has reached/exceeded 60 minutes (overtime recorded)."
          : "▶ Break ended successfully",
        totalMinutes,
        overtimeMinutes,
        limitReached,
        breakTime: todayRecord.breakTime,
      });
    }

    // --- Logout / normal update ---
    if (logoutTime && todayRecord.loginTime) {
      const loginMinutes = timeToMinutes(todayRecord.loginTime);
      const logoutMinutes = timeToMinutes(logoutTime);

      let workedMinutes = logoutMinutes - loginMinutes;

      // subtract break minutes (will include overtime if present)
      let breakMinutes = 0;
      if (todayRecord.breakTime) {
        const match = todayRecord.breakTime.match(/Total:\s*(\d+)\s*mins/);
        if (match) breakMinutes = parseInt(match[1]);
      }

      workedMinutes = Math.max(workedMinutes - breakMinutes, 0);
      todayRecord.workingMinutes = workedMinutes;

      if (workedMinutes >= 480) {
        todayRecord.attendanceType = "P";
      } else if (workedMinutes >= 240) {
        todayRecord.attendanceType = "HL";
      } else {
        todayRecord.attendanceType = "A";
      }

      todayRecord.logoutTime = logoutTime;
      todayRecord.status = "Logout";
      todayRecord.breakInProgress = null;
    }

    if (loginReason) todayRecord.loginReason = loginReason;
    if (logoutReason) todayRecord.logoutReason = logoutReason;

    await todayRecord.save();
    res.json({ message: "✅ Attendance updated", attendance: todayRecord });
  } catch (error) {
    console.error("❌ Error updating attendance:", error);
    res.status(500).json({ message: "Server Error" });
  }
});

// ✅ GET: Last 5 records
router.get("/attendance/history/:employeeId", async (req, res) => {
  try {
    const { employeeId } = req.params;
    const history = await Attendance.find({ employeeId })
      .sort({ createdAt: -1 })
      .limit(5);

    res.status(200).json(history);
  } catch (error) {
    console.error("❌ Error fetching history:", error);
    res.status(500).json({ message: "Server Error" });
  }
});

// ✅ GET: Get today's status
router.get("/attendance/status/:employeeId", async (req, res) => {
  try {
    const { employeeId } = req.params;
    const todayDate = formatDateToDDMMYYYY();

    const todayRecord = await Attendance.findOne({ employeeId, date: todayDate });

    if (!todayRecord) return res.json({ status: "None", date: todayDate });

    res.json({
      status: todayRecord.status,
      loginTime: todayRecord.loginTime,
      logoutTime: todayRecord.logoutTime,
      loginReason: todayRecord.loginReason,
      logoutReason: todayRecord.logoutReason,
      breakTime: todayRecord.breakTime,
      breakInProgress: todayRecord.breakInProgress || null, // 👈 NEW
      date: todayRecord.date,
    });
  } catch (error) {
    console.error("❌ Error fetching status:", error);
    res.status(500).json({ message: "Server Error" });
  }
});


// ✅ GET: Attendance by month (for Attendance List screen)
// GET: Attendance by month (FINAL)
router.get("/attendance/month", async (req, res) => {
  try {
    const { year, month } = req.query; // month: 1-12
    if (!year || !month) {
      return res.status(400).json({ message: "Year and month required" });
    }

    const daysInMonth = new Date(year, month, 0).getDate();

    const dateList = Array.from({ length: daysInMonth }, (_, i) => {
      const d = new Date(year, month - 1, i + 1);
      return `${String(d.getDate()).padStart(2, "0")}-${String(
        d.getMonth() + 1
      ).padStart(2, "0")}-${d.getFullYear()}`;
    });

    const attendance = await Attendance.find({
      date: { $in: dateList },
    });

    res.json(attendance);
  } catch (err) {
    console.error("❌ Monthly attendance error:", err);
    res.status(500).json({ message: "Server Error" });
  }
});

module.exports = router;