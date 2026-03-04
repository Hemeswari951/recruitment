// backend/routes/reports.js
const express = require("express");
const router = express.Router();
const mongoose = require("mongoose");

const Attendance = require("../models/attendance");
const Leave = require("../models/Leave");
const Employee = require("../models/employee");

// Helper: count business days (Mon-Fri) in a given month/year
function businessDaysInMonth(year, month) {
  const mIndex = month - 1;
  const start = new Date(year, mIndex, 1);
  const end = new Date(year, mIndex + 1, 0);
  let count = 0;
  for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    const wd = d.getDay();
    if (wd !== 0 && wd !== 6) count++;
  }
  return count;
}

function businessDaysOverlap(startDate, endDate, year, month) {
  if (!startDate || !endDate) return 0;
  const monthStart = new Date(year, month - 1, 1);
  const monthEnd = new Date(year, month, 0);
  const start = startDate > monthStart ? new Date(startDate) : new Date(monthStart);
  const end = endDate < monthEnd ? new Date(endDate) : new Date(monthEnd);
  if (end < start) return 0;
  let count = 0;
  for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    const wd = d.getDay();
    if (wd !== 0 && wd !== 6) count++;
  }
  return count;
}

/**
 * Helper: build flexible employee id matchers:
 * - employees may be referenced by employee._id (ObjectId) or by employee.employeeId (string)
 */
function buildEmployeeIdClauses(employees) {
  const objIds = [];
  const stringIds = [];
  for (const e of employees) {
    if (!e) continue;
    if (e._id) {
      try {
        objIds.push(mongoose.Types.ObjectId(e._id));
      } catch (err) { /* ignore */ }
    }
    if (e.employeeId) {
      stringIds.push(e.employeeId.toString());
    }
  }
  const clauses = [];
  if (objIds.length) clauses.push({ employeeId: { $in: objIds } });
  if (stringIds.length) clauses.push({ employeeId: { $in: stringIds } });
  // fallback: maybe attendance has employeeName? rarely, but we won't query that automatically
  return clauses.length ? { $or: clauses } : {};
}

/**
 * GET /attendance/monthly-summary
 * query:
 *   year (required)
 *   month (optional) - 1..12
 *   department (optional)
 */
router.get("/attendance/monthly-summary", async (req, res) => {
  try {
    const year = parseInt(req.query.year || new Date().getFullYear(), 10);
    const monthParam = req.query.month ? parseInt(req.query.month, 10) : null;
    const filterDomain = req.query.department || req.query.domain || null;

    const empQuery = filterDomain ? { domain: filterDomain } : {};
    const employees = await Employee.find(empQuery, "employeeId employeeName domain position").lean();

    async function computeForMonth(year, month) {
      const businessDays = businessDaysInMonth(year, month);
      // month range
      const monthStart = new Date(year, month - 1, 1, 0, 0, 0, 0);
      const monthEnd = new Date(year, month, 0, 23, 59, 59, 999);

      // build employee id clause (supports ObjectId _id and employeeId string)
      const empClause = buildEmployeeIdClauses(employees);
      if (!Object.keys(empClause).length) {
        // no employees -> return empty
        return { year, month, businessDays, employees: [], departmentSummary: {} };
      }

      // attendance date can be stored as Date or as string "DD-MM-YYYY". Build OR:
      const monthStrRegex = `-${String(month).padStart(2, "0")}-${year}$`;
      const attendanceDateOrRegex = {
        $or: [
          { date: { $gte: monthStart, $lte: monthEnd } }, // covers Date type
          { date: { $regex: monthStrRegex } },            // covers string DD-MM-YYYY
        ],
      };

      const attendanceQuery = { $and: [empClause, attendanceDateOrRegex] };
      const allAttendances = await Attendance.find(attendanceQuery).lean();

      // Leaves: approved leaves overlapping month.
      // Leave.fromDate / toDate may be Date or string: attempt to match by Date fields first,
      // and fallback to parsing string fields when building results below.
      const leavesQuery = {
       // --- small change inside monthly-summary's leavesQuery ---
      // replace { status: "Approved" } with a case-insensitive regex:
        $and: [
          { status: { $regex: /^approved$/i } }, // case-insensitive Approved
          empClause,
          {
            $or: [
              { $and: [{ fromDate: { $lte: monthEnd } }, { toDate: { $gte: monthStart } }] },
              { fromDate: { $exists: true } },
            ],
          },
        ],
      };

      const leaves = await Leave.find(leavesQuery).lean();

      // map attendances by employee identifier (try employeeId string then _id string)
      const attMap = {};
      for (const a of allAttendances) {
        // determine key used in employees list
        let key = null;
        if (a.employeeId) key = a.employeeId.toString();
        if (!key && a.employee && a.employee._id) key = a.employee._id.toString();
        if (!key && a.employeeId === undefined && a.employeeName) key = a.employeeName;
        if (!key) continue;
        attMap[key] = attMap[key] || [];
        attMap[key].push(a);
      }

      // build leave map similarly
      const leaveMap = {};
      for (const l of leaves) {
        let key = null;
        if (l.employeeId) key = l.employeeId.toString();
        if (!key && l.employee && l.employee._id) key = l.employee._id.toString();
        if (!key && l.employeeName) key = l.employeeName;
        if (!key) continue;
        leaveMap[key] = leaveMap[key] || [];
        leaveMap[key].push(l);
      }

      const employeeSummaries = [];

      for (const e of employees) {
        // choose key candidates for this employee
        const keysToTry = [];
        if (e.employeeId) keysToTry.push(e.employeeId.toString());
        if (e._id) keysToTry.push(e._id.toString());

        // collect attendances for any matching key
        const empAtts = [];
        for (const k of keysToTry) {
          if (attMap[k]) empAtts.push(...attMap[k]);
        }

        // dedupe by date string/day: need to extract day from either Date or "DD-MM-YYYY"
        const presentDatesSet = new Set();
        empAtts.forEach(a => {
          if (!a) return;
          if (a.date instanceof Date) {
            presentDatesSet.add(a.date.toISOString().slice(0, 10)); // YYYY-MM-DD
          } else if (typeof a.date === "string") {
            // if date stored as DD-MM-YYYY -> normalize to YYYY-MM-DD for dedupe
            const parts = a.date.split("-");
            if (parts.length === 3) {
              // assume DD-MM-YYYY
              const ds = `${parts[2].padStart(4, "0")}-${parts[1].padStart(2, "0")}-${parts[0].padStart(2, "0")}`;
              presentDatesSet.add(ds);
            } else {
              presentDatesSet.add(a.date);
            }
          }
        });
        const presentDays = presentDatesSet.size;

        // leaves: calculate overlap days (business days)
        let leaveDays = 0;
        const leaveByType = {};
        const empLeaves = [];
        for (const k of keysToTry) {
          if (leaveMap[k]) empLeaves.push(...leaveMap[k]);
        }
        for (const l of empLeaves) {
          // normalize from/to to Date objects (attempt)
          let from = l.fromDate;
          let to = l.toDate;
          if (typeof from === "string") {
            // try parse DD-MM-YYYY -> Date
            const p = from.split("-");
            if (p.length === 3) from = new Date(Number(p[2]), Number(p[1]) - 1, Number(p[0]));
            else from = new Date(from);
          }
          if (typeof to === "string") {
            const p = to.split("-");
            if (p.length === 3) to = new Date(Number(p[2]), Number(p[1]) - 1, Number(p[0]));
            else to = new Date(to);
          }
          if (!(from instanceof Date) || isNaN(from)) continue;
          if (!(to instanceof Date) || isNaN(to)) continue;
          const overlap = businessDaysOverlap(from, to, year, month);
          leaveDays += overlap;
          const t = (l.leaveType || "unknown").toString();
          leaveByType[t] = (leaveByType[t] || 0) + overlap;
        }

        const absentDays = Math.max(0, businessDays - presentDays - leaveDays);

        employeeSummaries.push({
          employeeId: e.employeeId || null,
          _id: e._id || null,
          employeeName: e.employeeName,
          domain: e.domain,
          position: e.position,
          businessDaysInMonth: businessDays,
          presentDays,
          leaveDays,
          leaveByType,
          absentDays,
        });
      } // end for employees

      // Department aggregation
      const deptAgg = {};
      for (const s of employeeSummaries) {
        const dept = s.domain || "Unknown";
        const d = deptAgg[dept] || { employees: 0, present: 0, leave: 0, absent: 0 };
        d.employees += 1;
        d.present += s.presentDays;
        d.leave += s.leaveDays;
        d.absent += s.absentDays;
        deptAgg[dept] = d;
      }

      return {
        year,
        month,
        businessDays,
        employees: employeeSummaries,
        departmentSummary: deptAgg,
      };
    } // computeForMonth

    if (monthParam) {
      const m = await computeForMonth(year, monthParam);
      return res.json(m);
    }

    const months = [];
    for (let m = 1; m <= 12; m++) months.push(await computeForMonth(year, m));
    return res.json({ year, months });
  } catch (err) {
    console.error("❌ monthly-summary error:", err);
    return res.status(500).json({ message: "Server error", error: err.message });
  }
});

// --- Replace the entire /attendance/employee-days route with this updated route ---
router.get("/attendance/employee-days", async (req, res) => {
  try {
    const employeeId = req.query.employeeId;
    const year = parseInt(req.query.year || new Date().getFullYear(), 10);
    const month = parseInt(req.query.month || (new Date().getMonth() + 1), 10);
    if (!employeeId) return res.status(400).json({ message: "employeeId required" });

    const monthStart = new Date(year, month - 1, 1, 0, 0, 0, 0);
    const monthEnd = new Date(year, month, 0, 23, 59, 59, 999);
    const monthStrRegex = `-${String(month).padStart(2, "0")}-${year}$`;

    // build flexible match for employeeId (ObjectId or string)
    const orClauses = [];
    try {
      orClauses.push({ employeeId: mongoose.Types.ObjectId(employeeId) });
    } catch (err) { /* not an ObjectId - ignore */ }
    orClauses.push({ employeeId: employeeId });

    // 1) Attendance docs for the employee in month
    const attendanceDocs = await Attendance.find({
      $and: [
        { $or: orClauses },
        {
          $or: [
            { date: { $gte: monthStart, $lte: monthEnd } },
            { date: { $regex: monthStrRegex } },
          ],
        },
      ],
    }).lean();

    // Build initial day map from attendance (attendance takes precedence)
    const daysMap = {};
    for (const a of attendanceDocs) {
      if (!a.date) continue;
      let dayNum = null;
      if (a.date instanceof Date) dayNum = a.date.getDate();
      else if (typeof a.date === "string") {
        const parts = a.date.split("-");
        if (parts.length === 3) dayNum = parseInt(parts[0], 10); // DD-MM-YYYY
        else {
          const dt = new Date(a.date);
          if (!isNaN(dt)) dayNum = dt.getDate();
        }
      }
      if (!dayNum) continue;
      // determine marker (simple mapping)
      let mark = "";
      const s = (a.status || "").toString().toLowerCase();
      if (s.includes("abs") || s === "a") mark = "A";
      else if (s.includes("leave") || s === "l") mark = "L";
      else if (s.includes("login") || s.includes("present") || s === "p") mark = "P";
      else mark = (a.status || "").toString().substring(0, 1).toUpperCase();
      daysMap[String(dayNum)] = mark;
    }

    // 2) Fetch APPROVED leaves (case-insensitive) that may overlap the month
    const leaves = await Leave.find({
      $and: [
        { $or: orClauses },
        { status: { $regex: /^approved$/i } },
        {
          $or: [
            { $and: [{ fromDate: { $lte: monthEnd } }, { toDate: { $gte: monthStart } }] },
            { fromDate: { $exists: true } }, // fallback: include leaves with date strings and filter below
          ],
        },
      ],
    }).lean();

    // Merge leaves into daysMap (do not overwrite 'P' from attendance)
    for (const l of leaves) {
      let from = l.fromDate;
      let to = l.toDate;
      if (typeof from === "string") {
        const p = from.split("-");
        if (p.length === 3) from = new Date(Number(p[2]), Number(p[1]) - 1, Number(p[0]));
        else from = new Date(from);
      }
      if (typeof to === "string") {
        const p = to.split("-");
        if (p.length === 3) to = new Date(Number(p[2]), Number(p[1]) - 1, Number(p[0]));
        else to = new Date(to);
      }
      if (!(from instanceof Date) || isNaN(from)) continue;
      if (!(to instanceof Date) || isNaN(to)) continue;

      // restrict to month range
      const start = from > monthStart ? new Date(from) : new Date(monthStart);
      const end = to < monthEnd ? new Date(to) : new Date(monthEnd);
      if (end < start) continue;

      for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
        const wd = d.getDay();
        if (wd === 0 || wd === 6) continue; // skip weekends (business days only)
        const dayNum = d.getDate();
        const key = String(dayNum);
        // don't overwrite present markers
        if (daysMap[key] && daysMap[key] === "P") continue;
        // Only set L if not present/other stronger marker
        if (!daysMap[key] || daysMap[key] === "") daysMap[key] = "L";
      }
    }

    return res.json({ days: daysMap });
  } catch (err) {
    console.error("employee-days error:", err);
    return res.status(500).json({ message: "Server error", error: err.message });
  }
});


module.exports = router;
