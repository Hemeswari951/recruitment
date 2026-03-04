// attendancelist.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'sidebar.dart';
import 'dart:html' as html;
//import 'package:flutter/scheduler.dart' show WidgetsBinding;

class AttendanceListScreen extends StatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  final TextEditingController searchController = TextEditingController();
  // ✅ REQUIRED SCROLL CONTROLLERS (kept for backward compatibility; not used by child)
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> filteredEmployees = [];
  List<Map<String, dynamic>> monthlyAttendance = [];
  List<Map<String, dynamic>> approvedLeaves = [];

  Set<String> holidayDateKeys = {};

  bool isLoading = true;

  int selectedYear = DateTime.now().year;
  int selectedMonthIndex = DateTime.now().month;

  late List<int> years;

  final List<String> months = const [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  @override
  void initState() {
    super.initState();

    final currentYear = DateTime.now().year;
    years = [currentYear - 1, currentYear];
    //searchController.addListener(_filterEmployees); // ✅ same as EmployeeList
    fetchAllData();
  }

  /// ---------------- LOAD ALL DATA ----------------
  Future<void> fetchAllData() async {
    setState(() => isLoading = true);
    await fetchEmployees();
    await fetchMonthlyAttendance();
    await fetchApprovedLeaves();
    await fetchHolidays(); // 🆕 NEW
    // _filterEmployees(); // 🔁 keep filtered list in sync

    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    //searchController.removeListener(_filterEmployees);
    searchController.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  /// ---------------- EMPLOYEES ----------------
  Future<void> fetchEmployees() async {
    final res = await http.get(
      Uri.parse("https://company-04bz.onrender.com/api/employees"),
    );
    if (res.statusCode == 200) {
      employees = List<Map<String, dynamic>>.from(json.decode(res.body));
      filteredEmployees = List.from(employees);
    }
  }

  /// ---------------- MONTHLY ATTENDANCE ----------------
  Future<void> fetchMonthlyAttendance() async {
    final res = await http.get(
      Uri.parse(
        "https://company-04bz.onrender.com/attendance/attendance/month"
        "?year=$selectedYear&month=$selectedMonthIndex",
      ),
    );

    if (res.statusCode == 200) {
      monthlyAttendance = List<Map<String, dynamic>>.from(
        json.decode(res.body),
      );
    }
  }

  //-------ApprovedLeaves----------
  Future<void> fetchApprovedLeaves() async {
    final res = await http.get(
      Uri.parse(
        "https://company-04bz.onrender.com/apply/approved/month"
        "?year=$selectedYear&month=$selectedMonthIndex",
      ),
    );

    if (res.statusCode == 200) {
      approvedLeaves = List<Map<String, dynamic>>.from(json.decode(res.body));
    }
  }

  /// ---------------- HOLIDAYS ----------------
  /// 🆕 NEW
  Future<void> fetchHolidays() async {
    final monthName = months[selectedMonthIndex - 1];

    final res = await http.get(
      Uri.parse(
        "https://company-04bz.onrender.com/notifications/holiday/employee/ADMIN?month=$monthName&year=$selectedYear",
      ),
    );

    if (res.statusCode == 200) {
      final List data = json.decode(res.body);

      holidayDateKeys = data.map<String>((h) {
        return "${h["day"]}-$selectedMonthIndex-${h["year"]}";
      }).toSet();
    } else {
      // holidayDays = {};
      holidayDateKeys = {};
    }
  }

  /// ---------------- DATE HELPERS ----------------
  List<DateTime> getDaysInMonth(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return List.generate(lastDay, (index) => DateTime(year, month, index + 1));
  }

  bool isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  /// 🆕 NEW
  bool isHoliday(DateTime date) {
    // return holidayDays.contains(date.day);
    final key = "${date.day}-${date.month}-${date.year}";
    return holidayDateKeys.contains(key);
  }

  /// ---------------- BUILD ATTENDANCE MAP ----------------
  Map<String, Map<String, String>> buildAttendanceMap() {
    final map = <String, Map<String, String>>{};

    for (final a in monthlyAttendance) {
      final empId = a["employeeId"];
      final date = a["date"];
      final type = a["attendanceType"] ?? "P";

      map.putIfAbsent(empId, () => {});
      map[empId]![date] = type;
    }
    return map;
  }

  Map<String, Set<String>> buildLeaveMap() {
    final map = <String, Set<String>>{};

    for (final leave in approvedLeaves) {
      final empId = leave["employeeId"];

      // final fromRaw = DateTime.parse(leave["fromDate"]).toLocal();
      // final toRaw = DateTime.parse(leave["toDate"]).toLocal();
//       final fromRaw = DateTime.parse(leave["fromDate"]);
// final toRaw   = DateTime.parse(leave["toDate"]);
final from = DateFormat("dd-MM-yyyy").parse(leave["fromDate"]);
final to   = DateFormat("dd-MM-yyyy").parse(leave["toDate"]);



      // final from = DateTime(fromRaw.year, fromRaw.month, fromRaw.day);
      // final to = DateTime(toRaw.year, toRaw.month, toRaw.day);

      map.putIfAbsent(empId, () => <String>{});

      for (
        DateTime d = from;
        !d.isAfter(to);
        d = d.add(const Duration(days: 1))
      ) {
        map[empId]!.add(DateFormat("dd-MM-yyyy").format(d));
      }
    }
    return map;
  }

  /// ---------------- STATUS ----------------
  String getStatusForDate(
    String empId,
    DateTime date,
    Map<String, Map<String, String>> attendanceMap,
    Map<String, Set<String>> leaveMap,
  ) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final cellDate = DateTime(date.year, date.month, date.day);
    final key = DateFormat("dd-MM-yyyy").format(date);
    // 🆕 0. HOLIDAY (highest priority)
    if (isHoliday(cellDate)) return "H";

    // ✅ 0. WEEKEND
   if (isWeekend(cellDate) && !cellDate.isAfter(todayOnly)) return "WE";

   // 1. LEAVE LOGIC WITH 3-DAY LIMIT
    if (leaveMap[empId]?.contains(key) == true) {
    // Get all leave dates for this employee this month
    List<String> sortedLeaveDates = leaveMap[empId]!.toList()..sort();
    
    // Find the index of the current date in the list of leaves
    int leaveIndex = sortedLeaveDates.indexOf(key);

    // If it's the 4th leave or beyond (index 3, 4, ...), return "A"
    if (leaveIndex >= 3) {
      return "A"; 
    }
    return "L";
  }

    // ✅ 2. PRESENT
    final status = attendanceMap[empId]?[key];
    if (status == "P") {
      return "P";
    }

    if (status == "HL") {
      return "HL";
    }

    // ✅ Ignore Working status
    if (status != null && status != "W") {
      return status;
    }

    // ✅ 3. FUTURE DATE (no leave)
    if (cellDate.isAfter(todayOnly)) {
      return "";
    }

    // ✅ 4. PAST DATE → ABSENT
    if (cellDate.isBefore(todayOnly)) {
      return "A";
    }

    return "";
  }

  Color getStatusColor(String status) {
    if (status == "P") return Colors.green;
    if (status == "A") return Colors.red;
    if (status == "L") return Colors.orange;
    if (status == "H") return Colors.pink;

    if (status == "HL") return Colors.purple;
    if (status == "WE") return Colors.blue;
    return Colors.transparent;
  }

  /// ---------------- TOTALS ----------------
  Map<String, double> calculateMonthlySummary(
  String empId,
  List<DateTime> days,
  Map<String, Map<String, String>> attendanceMap,
  Map<String, Set<String>> leaveMap,
) {
  double total = 0;
  double present = 0;
  double halfDay = 0;
  double leave = 0;
  double extraAbsentFromLeave = 0;

  final now = DateTime.now();
  final todayOnly = DateTime(now.year, now.month, now.day);

  // Pre-sort leave dates to identify which ones are > 3
  List<String> sortedLeaves = leaveMap[empId]?.toList() ?? [];
  sortedLeaves.sort();

  for (final d in days) {
    final dayOnly = DateTime(d.year, d.month, d.day);
    if (dayOnly.isAfter(todayOnly)) continue;
    if (isWeekend(dayOnly) || isHoliday(dayOnly)) continue;

    total += 1;
    final key = DateFormat("dd-MM-yyyy").format(d);
    final status = attendanceMap[empId]?[key];

    // Check Leave Limit
    if (leaveMap[empId]?.contains(key) == true) {
      int leaveIndex = sortedLeaves.indexOf(key);
      if (leaveIndex < 3) {
        leave += 1;
      } else {
        // This is the 4th leave or more, treat as Absent
        extraAbsentFromLeave += 1;
      }
    } else if (status == "P") {
      present += 1;
    } else if (status == "HL") {
      halfDay += 0.5;
      present += 0.5;
    }
  }

  return {
    "total": total,
    "present": present,
    "halfDay": halfDay,
    "leave": leave,
    "absent": (total - present - halfDay - leave), // extraAbsentFromLeave is naturally included here
  };
}

  void downloadCsv() {
    final now = DateTime.now();
    final isCurrentMonthSelected =
        now.year == selectedYear && now.month == selectedMonthIndex;
    final days = getDaysInMonth(selectedYear, selectedMonthIndex);
    final attendanceMap = buildAttendanceMap();
    final leaveMap = buildLeaveMap();

    final buffer = StringBuffer();

    // ================= HEADER =================
    if (isCurrentMonthSelected) {
      // Current month → day-wise header
      buffer.write("SL,Emp ID,Name,Position,");
      for (final d in days) {
        //buffer.write("${DateFormat("MMM dd").format(d)}," );
        //buffer.write("${DateFormat("MMM dd").format(d).toUpperCase()}," );
        buffer.write("'${DateFormat("MMM dd").format(d).toUpperCase()}," );
      }
      buffer.writeln("Total,Present,HalfDay,Leave,Absent");

      // -------- HEADER ROW 2 : WEEKDAY ----------
      buffer.write(",,,,"); // skip SL, Emp ID, Name, Position
      for (final d in days) {
        buffer.write("${DateFormat("EEE").format(d).toUpperCase()},");
      }
      buffer.writeln(",,,,"); // align summary columns
    } else {
      // Past month → summary only header
      buffer.writeln(
        "SL,Emp ID,Name,Position,Total Days,Present,HalfDay,Leave,Absent",
      );
    }

    // ================= ROWS =================
    for (int i = 0; i < filteredEmployees.length; i++) {
      final emp = filteredEmployees[i];
      final empId = emp["employeeId"];

      buffer.write(
        "${i + 1},$empId,${emp["employeeName"]},${emp["position"]},",
      );

      if (isCurrentMonthSelected) {
        // ---------- DAY-WISE CSV ----------
        int present = 0, half = 0, leave = 0, total = 0;

        // ... inside rows loop ...
for (final d in days) {
  final status = getStatusForDate(empId, d, attendanceMap, leaveMap);
  buffer.write("$status,");

  if (status == "WE" || status == "H") continue;
  if (status.isNotEmpty) total++;
  if (status == "P") present++;
  if (status == "HL") half++;
  if (status == "L") leave++; 
  // Note: if status is "A" (because it was the 4th leave), 
  // it won't increment 'leave', so 'absent' calculation below remains correct.
}
final absent = total - present - half - leave;
        buffer.writeln("$total,$present,$half,$leave,$absent");
      } else {
        // ---------- SUMMARY-ONLY CSV ----------
        final summary = calculateMonthlySummary(
          empId,
          days,
          attendanceMap,
          leaveMap,
        );

        buffer.writeln(
          "${summary["total"]},"
          "${summary["present"]},"
          "${summary["halfDay"]},"
          //"${summary["holiday"]}," // ✅ NEW
          "${summary["leave"]},"
          "${summary["absent"]}",
        );
      }
    }

    // ================= FILE DOWNLOAD =================
    final fileName =
        "${DateFormat("MMM").format(DateTime(0, selectedMonthIndex))}"
        "-$selectedYear-Attendance_list.csv";

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  void downloadSummaryCsv() {
    final days = getDaysInMonth(selectedYear, selectedMonthIndex);
    final attendanceMap = buildAttendanceMap();
    final leaveMap = buildLeaveMap();

    final buffer = StringBuffer();

    // HEADER
    buffer.writeln("S.No,Emp ID,Name,Total,P,HL,L,A");

    for (int i = 0; i < filteredEmployees.length; i++) {
      final emp = filteredEmployees[i];
      final empId = emp["employeeId"];

      final summary = calculateMonthlySummary(
        empId,
        days,
        attendanceMap,
        leaveMap,
      );

      buffer.writeln(
        "${i + 1},"
        "$empId,"
        "${emp["employeeName"]},"
        "${summary["total"]},"
        "${summary["present"]},"
        "${summary["halfDay"]},"
        "${summary["leave"]},"
        "${summary["absent"]}",
      );
    }

    final fileName =
        "Attendance_Summary_${selectedMonthIndex.toString().padLeft(2, '0')}_$selectedYear.csv";

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  void openAttendanceSummary() {
    final days = getDaysInMonth(selectedYear, selectedMonthIndex);
    final attendanceMap = buildAttendanceMap();
    final leaveMap = buildLeaveMap();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---------- HEADER ----------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Attendance Summary - "
                      "${selectedMonthIndex.toString().padLeft(2, '0')} / $selectedYear",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Row(
                      children: [
                        IconButton(
                          tooltip: "Download CSV",
                          icon: const Icon(
                            Icons.download_rounded,
                            color: Colors.blue,
                          ),
                          onPressed: downloadSummaryCsv,
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ---------- TABLE ----------
                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowHeight: 44,
                      dataRowHeight: 40,
                      columns: const [
                        DataColumn(label: Text("S.No")),
                        DataColumn(label: Text("Emp ID")),
                        DataColumn(label: Text("Name")),
                        DataColumn(label: Text("Total")),
                        DataColumn(label: Text("P")),
                        DataColumn(label: Text("HL")),
                        DataColumn(label: Text("L")),
                        DataColumn(label: Text("A")),
                      ],
                      rows: List.generate(filteredEmployees.length, (i) {
                        final emp = filteredEmployees[i];
                        final empId = emp["employeeId"];

                        final summary = calculateMonthlySummary(
                          empId,
                          days,
                          attendanceMap,
                          leaveMap,
                        );

                        return DataRow(
                          cells: [
                            DataCell(Text("${i + 1}")),
                            DataCell(Text(empId ?? "-")),
                            DataCell(Text(emp["employeeName"] ?? "-")),
                            DataCell(Text(summary["total"].toString())),
                            DataCell(
                              Text(
                                summary["present"].toString(),
                                style: const TextStyle(color: Colors.green),
                              ),
                            ),
                            DataCell(
                              Text(
                                summary["halfDay"].toString(),
                                style: const TextStyle(color: Colors.purple),
                              ),
                            ),
                            DataCell(
                              Text(
                                summary["leave"].toString(),
                                style: const TextStyle(
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                summary["absent"].toString(),
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = getDaysInMonth(selectedYear, selectedMonthIndex);
    final attendanceMap = buildAttendanceMap();
    final leaveMap = buildLeaveMap(); // ✅ FIX

    return Sidebar(
      title: "Attendance List",
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Column(
            children: [
              /// HEADER ROW
              Row(
                children: [
                  const Text(
                    "Attendance List",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// YEAR DROPDOWN
                      SizedBox(
                        width: 110,
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          items: years
                              .map(
                                (y) => DropdownMenuItem<int>(
                                  value: y,
                                  child: Text(y.toString()),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => selectedYear = value!);
                            fetchAllData();
                          },
                        ),
                      ),

                      const SizedBox(width: 8),

                      /// MONTH DROPDOWN
                      SizedBox(
                        width: 140,
                        child: DropdownButtonFormField<String>(
                          value: months[selectedMonthIndex - 1],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          items: months
                              .map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedMonthIndex = months.indexOf(value!) + 1;
                            });
                            fetchAllData();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // 🟣 ATTENDANCE SUMMARY BUTTON (NEW)
                      IconButton(
                        onPressed: openAttendanceSummary,
                        icon: const Icon(
                          Icons.bar_chart_rounded,
                          color: Colors.deepPurple,
                        ),
                        tooltip: "Attendance Summary",
                      ),
                      const SizedBox(width: 12),

                      /// DOWNLOAD BUTTON
                      ElevatedButton.icon(
                        onPressed: filteredEmployees.isEmpty
                            ? null
                            : downloadCsv,
                        icon: const Icon(Icons.download),
                        label: const Text(""),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      const _LegendItem(
                        color: Colors.green,
                        label: "P",
                        text: "Present",
                      ),
                      SizedBox(width: 8),
                      _LegendItem(
                        color: Colors.deepPurple,
                        label: "HL",
                        text: "HalfDay",
                      ),
                      SizedBox(width: 8),

                      _LegendItem(
                        color: Colors.orange,
                        label: "L",
                        text: "Leave",
                      ),
                      SizedBox(width: 8),
                      _LegendItem(
                        color: Colors.red,
                        label: "A",
                        text: "Absent",
                      ),
                    ],
                  ),
                  // ),
                ],
              ),

              const SizedBox(height: 16),

              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "Search employee...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _AttendanceDataTable(
                        employees: employees,
                        searchController: searchController,
                        daysInMonth: daysInMonth,
                        attendanceMap: attendanceMap,
                        leaveMap: leaveMap,
                        isWeekend: isWeekend,
                        isHoliday: isHoliday,
                        getStatusForDate: getStatusForDate,
                        getStatusColor: getStatusColor,
                        calculateMonthlySummary: calculateMonthlySummary,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// LEGEND WIDGET
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String text;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: color,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _AttendanceDataTable extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final TextEditingController searchController;

  final List<DateTime> daysInMonth;
  final Map<String, Map<String, String>> attendanceMap;
  final Map<String, Set<String>> leaveMap;

  final bool Function(DateTime) isWeekend;
  final bool Function(DateTime) isHoliday;
  final String Function(
    String,
    DateTime,
    Map<String, Map<String, String>>,
    Map<String, Set<String>>,
  )
      getStatusForDate;

  final Color Function(String) getStatusColor;

  final Map<String, double> Function(
    String,
    List<DateTime>,
    Map<String, Map<String, String>>,
    Map<String, Set<String>>,
  )
      calculateMonthlySummary;

  const _AttendanceDataTable({
    required this.employees,
    required this.searchController,
    required this.daysInMonth,
    required this.attendanceMap,
    required this.leaveMap,
    required this.isWeekend,
    required this.isHoliday,
    required this.getStatusForDate,
    required this.getStatusColor,
    required this.calculateMonthlySummary,
  });

  @override
  State<_AttendanceDataTable> createState() => _AttendanceDataTableState();
}

class _AttendanceDataTableState extends State<_AttendanceDataTable> {
  List<Map<String, dynamic>> _filteredEmployees = [];

  // controllers for left (fixed) and right (scrollable) vertical areas
  final ScrollController _leftVertical = ScrollController();
  final ScrollController _rightVertical = ScrollController();

  // horizontal controllers (table + visible thumb)
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _horizontalThumbController = ScrollController();

  bool _isSyncingVertical = false;
  bool _isSyncingHorizontal = false;

  // tweak widths here
  final double leftColumnWidth = 420; // width for SL, Emp ID, Name, Position area (adjustable)
  final double perDayWidth = 56; // width per day column
  // summary columns have fixed widths: Total=70, P/HL/L/A=56 each => 70 + (56*4) = 294
  final double summaryWidth = 70 + (56 * 4); // 294

  @override
  void initState() {
    super.initState();
    _filteredEmployees = List.from(widget.employees);
    widget.searchController.addListener(_filterEmployees);

    // sync vertical scrolling (left <-> right)
    _leftVertical.addListener(() {
      if (_isSyncingVertical) return;
      _isSyncingVertical = true;
      if (_rightVertical.hasClients) {
        _rightVertical.jumpTo(_leftVertical.position.pixels);
      }
      _isSyncingVertical = false;
    });

    _rightVertical.addListener(() {
      if (_isSyncingVertical) return;
      _isSyncingVertical = true;
      if (_leftVertical.hasClients) {
        _leftVertical.jumpTo(_rightVertical.position.pixels);
      }
      _isSyncingVertical = false;
    });

    // Sync table horizontal controller -> thumb controller
    _horizontalController.addListener(() {
      if (_isSyncingHorizontal) return;
      _isSyncingHorizontal = true;
      if (_horizontalThumbController.hasClients) {
        _horizontalThumbController.jumpTo(_horizontalController.position.pixels);
      }
      _isSyncingHorizontal = false;
    });

    // Sync thumb controller -> table horizontal controller
    _horizontalThumbController.addListener(() {
      if (_isSyncingHorizontal) return;
      _isSyncingHorizontal = true;
      if (_horizontalController.hasClients) {
        _horizontalController.jumpTo(_horizontalThumbController.position.pixels);
      }
      _isSyncingHorizontal = false;
    });
  }

  void _filterEmployees() {
    final q = widget.searchController.text.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredEmployees = List.from(widget.employees);
      } else {
        _filteredEmployees = widget.employees.where((e) {
          final id = e["employeeId"]?.toString().toLowerCase() ?? "";
          final name = e["employeeName"]?.toString().toLowerCase() ?? "";
          final pos = e["position"]?.toString().toLowerCase() ?? "";
          return id.contains(q) || name.contains(q) || pos.contains(q);
        }).toList();
      }
    });

    // ensure scroll resets after the frame so the new (shorter) list is visible at the top
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_leftVertical.hasClients) _leftVertical.jumpTo(0);
      if (_rightVertical.hasClients) _rightVertical.jumpTo(0);
      if (_horizontalController.hasClients) _horizontalController.jumpTo(0);
      if (_horizontalThumbController.hasClients) _horizontalThumbController.jumpTo(0);
    });
  }

  @override
  void didUpdateWidget(covariant _AttendanceDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employees != widget.employees) {
      _filteredEmployees = List.from(widget.employees);
      _filterEmployees();
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_filterEmployees);
    _leftVertical.dispose();
    _rightVertical.dispose();
    _horizontalController.dispose();
    _horizontalThumbController.dispose();
    super.dispose();
  }

  Widget _buildLeftHeader() {
    return Container(
      width: leftColumnWidth,
      height: 56,
      // top header already colored; keep bottom and right border
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
        color: Colors.grey.shade100,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: const Text("SL", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Container(
            width: 110,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: const Text("Emp ID", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              child: const Text("Name", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            child: const Text("Position", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRightHeader() {
    final rightWidth = widget.daysInMonth.length * perDayWidth + summaryWidth;
    return SingleChildScrollView(
      controller: _horizontalController,
      scrollDirection: Axis.horizontal,
      child: Container(
        width: rightWidth,
        height: 56,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          color: Colors.grey.shade100,
        ),
        child: Row(
          children: [
            // days
            ...widget.daysInMonth.map((d) {
              return Container(
                width: perDayWidth,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat("MMM dd").format(d).toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat("EEE").format(d).toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: widget.isWeekend(d) ? Colors.blue : Colors.grey[700]),
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }),

            // summary headers
            Container(
              width: 70,
              alignment: Alignment.center,
              child: const Text("Total Days", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Container(
              width: 56,
              alignment: Alignment.center,
              child: const Text("P", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Container(
              width: 56,
              alignment: Alignment.center,
              child: const Text("HL", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Container(
              width: 56,
              alignment: Alignment.center,
              child: const Text("L", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Container(
              width: 56,
              alignment: Alignment.center,
              child: const Text("A", style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            // removed extra spacing to avoid negative width crash
            SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftRow(int index, Map<String, dynamic> emp) {
    return Container(
      width: leftColumnWidth,
      height: 44,
      // draw right separator and bottom line for each row
      padding: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Text("${index + 1}"),
          ),
          Container(
            width: 110,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Text(emp["employeeId"]?.toString() ?? "-"),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Text(emp["employeeName"] ?? "-"),
            ),
          ),
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            child: Text(emp["position"] ?? "-"),
          ),
        ],
      ),
    );
  }

  Widget _buildRightRow(String empId, int index) {
    final summary = widget.calculateMonthlySummary(
      empId,
      widget.daysInMonth,
      widget.attendanceMap,
      widget.leaveMap,
    );

    return Row(
      children: [
        // day cells
        ...widget.daysInMonth.map((date) {
          final status = widget.getStatusForDate(empId, date, widget.attendanceMap, widget.leaveMap);
          final bg = widget.getStatusColor(status);
          return Container(
            width: perDayWidth,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg == Colors.transparent ? null : bg.withOpacity(0.12),
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Text(
              status,
              style: TextStyle(fontWeight: FontWeight.bold, color: widget.getStatusColor(status)),
            ),
          );
        }),

        // summary cells (also draw bottom borders to align with grid)
        Container(
          width: 70,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300), right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Text(summary["total"].toString()),
        ),
        Container(
          width: 56,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300), right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Text(summary["present"].toString(), style: const TextStyle(color: Colors.green)),
        ),
        Container(
          width: 56,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300), right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Text(summary["halfDay"].toString(), style: const TextStyle(color: Colors.purple)),
        ),
        Container(
          width: 56,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300), right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Text(summary["leave"].toString(), style: const TextStyle(color: Colors.orange)),
        ),
        Container(
          width: 56,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Text(summary["absent"].toString(), style: const TextStyle(color: Colors.red)),
        ),

        // removed extra spacing to avoid negative width crash
        SizedBox.shrink(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // compute right width
    final rightWidth = widget.daysInMonth.length * perDayWidth + summaryWidth;

    return Column(
      children: [
        // header (fixed left + horizontally-scrollable right)
        Row(
          children: [
            _buildLeftHeader(),
            Expanded(child: _buildRightHeader()),
          ],
        ),

        const SizedBox(height: 0),

        // body
        Expanded(
          child: Row(
            children: [
              // ---- REPLACE LEFT FIXED COLUMNS (inside Row children) ----
              SizedBox(
                width: leftColumnWidth,
                child: Scrollbar(
                  controller: _leftVertical,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _leftVertical,
                    itemCount: _filteredEmployees.length,
                    itemExtent: 44, // fixed height for perfect alignment
                    physics: const ClampingScrollPhysics(),
                    itemBuilder: (context, i) {
                      final emp = _filteredEmployees[i];
                      return _buildLeftRow(i, emp);
                    },
                  ),
                ),
              ),

              // ---- REPLACE RIGHT SCROLLABLE PART (rest of Row children) ----
              Expanded(
                child: Column(
                  children: [
                    // the right table area (horizontally scrollable)
                    Expanded(
                      child: Scrollbar(
                        controller: _rightVertical,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: rightWidth,
                            // Use ListView for vertical rows so heights are identical
                            child: ListView.builder(
                              controller: _rightVertical,
                              itemCount: _filteredEmployees.length,
                              itemExtent: 44, // same as left side
                              physics: const ClampingScrollPhysics(),
                              itemBuilder: (context, i) {
                                final emp = _filteredEmployees[i];
                                final empId = emp["employeeId"];
                                return _buildRightRow(empId ?? "-", i);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ALWAYS-VISIBLE horizontal scrollbar (synced)
                    SizedBox(
                      height: 18,
                      child: Scrollbar(
                        controller: _horizontalThumbController,
                        thumbVisibility: true,
                        notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _horizontalThumbController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(width: rightWidth, height: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}