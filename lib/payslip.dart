// payslip.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'sidebar.dart';
import 'user_provider.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  // int workingDays = 0;
  double fullMonthWorkingDays = 0;

  bool isLoading = true;
  bool noPayslipAvailable = false;
  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  DateTime? employeeDOJ;

  DateTime safeParseDate(String raw) {
  try {
    return DateTime.parse(raw); // ISO format yyyy-MM-dd
  } catch (_) {
    try {
      return DateFormat('dd-MM-yyyy').parse(raw);
    } catch (_) {
      return DateFormat('dd/MM/yyyy').parse(raw); // 🔥 ADD THIS
    }
  }
}

bool _isMonthValid(int year, int monthIndex) {
  DateTime now = DateTime.now();
  DateTime selected = DateTime(year, monthIndex);

  // ❌ Future year
  if (year > now.year) return false;

  // ❌ Future month in current year
  if (year == now.year && monthIndex >= now.month) return false;

  // ❌ Before DOJ month
  if (employeeDOJ != null) {
    DateTime joinMonth =
        DateTime(employeeDOJ!.year, employeeDOJ!.month);

    if (selected.isBefore(joinMonth)) return false;
  }

  return true;
}

  List<String> get _years {
  if (employeeDOJ == null) {
    return [selectedYear]; // temporary fallback
  }

  int joinYear = employeeDOJ!.year;
  int currentYear = DateTime.now().year;

  return List.generate(
    currentYear - joinYear + 1,
    (index) => (joinYear + index).toString(),
  );
}


// showing no of days in monthwise(30 or 31)
  int getTotalDaysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}

  double totalWorkingDays = 0;
double presentDays = 0;
double halfDays = 0;
double leaveDays = 0;
double absentDays = 0;
double lopDays = 0;
double lopAmount = 0;


 late String selectedMonth;
  late String selectedYear;

  Map<String, dynamic> earnings = {};
  Map<String, dynamic> deductions = {};
  Map<String, dynamic> employeeData = {};

  void _autoSelectLatestValidMonth() {
  if (employeeDOJ == null) return;

  DateTime now = DateTime.now();
  DateTime lastCompletedMonth = DateTime(now.year, now.month - 1);

  DateTime joiningMonth =
      DateTime(employeeDOJ!.year, employeeDOJ!.month);

  DateTime target =
      lastCompletedMonth.isBefore(joiningMonth)
          ? joiningMonth
          : lastCompletedMonth;

  selectedYear = target.year.toString();
  selectedMonth = _months[target.month - 1];
}


  @override
  void initState() {
    super.initState();
    // 👇 Dynamically set previous month
    DateTime now = DateTime.now();
    int prevMonth = now.month - 1;

    if (prevMonth == 0) {
      // If current month is January → set to December of previous year
      prevMonth = 12;
      selectedYear = (now.year - 1).toString();
    } else {
      selectedYear = now.year.toString();
    }

    selectedMonth = _months[prevMonth - 1]; // list is 0-based
    
    Future.delayed(Duration.zero, _fetchPayslipDetails);
  }

void _fixMonthForSelectedYear(int year) {
  DateTime now = DateTime.now();
  int currentYear = now.year;
  int currentMonth = now.month;

  int startMonth = 1;
  int endMonth = 12;

  if (employeeDOJ != null && year == employeeDOJ!.year) {
    startMonth = employeeDOJ!.month;
  }

  if (year == currentYear) {
    endMonth = currentMonth - 1;
  }

  if (endMonth < startMonth) return;

  // choose latest valid month in that year
  int validMonth = endMonth;

  selectedMonth = _months[validMonth - 1];
}

  Future<void> fetchMonthlyPayrollSummary() async {
  final employeeId = Provider.of<UserProvider>(context, listen: false).employeeId ?? "";
  if (employeeId.isEmpty) return;

  final monthIndex = _months.indexOf(selectedMonth) + 1;
  final year = int.parse(selectedYear);

  // 1) fetch attendance month
  final resAttendance = await http.get(Uri.parse(
    "https://company-04bz.onrender.com/attendance/attendance/month?year=$year&month=$monthIndex",
  ));

  // 2) fetch approved leaves month
  final resLeaves = await http.get(Uri.parse(
    "https://company-04bz.onrender.com/apply/approved/month?year=$year&month=$monthIndex",
  ));

  // 3) fetch holidays month
  final resHolidays = await http.get(Uri.parse(
    "https://company-04bz.onrender.com/notifications/holiday/employee/ADMIN?month=$selectedMonth&year=$year",
  ));

  List<Map<String, dynamic>> monthlyAttendance = [];
  List<Map<String, dynamic>> approvedLeaves = [];
  Set<String> holidayDateKeys = {};

  if (resAttendance.statusCode == 200) {
    monthlyAttendance = List<Map<String, dynamic>>.from(jsonDecode(resAttendance.body));
  }

  if (resLeaves.statusCode == 200) {
    approvedLeaves = List<Map<String, dynamic>>.from(jsonDecode(resLeaves.body));
  }

  if (resHolidays.statusCode == 200) {
    final List data = jsonDecode(resHolidays.body);
    holidayDateKeys = data.map<String>((h) {
      return "${h["day"]}-$monthIndex-${h["year"]}";
    }).toSet();
  }

  // ---- helper functions (same like AttendanceList) ----
  // List<DateTime> getDaysInMonth(int year, int month) {
  //   final lastDay = DateTime(year, month + 1, 0).day;
  //   return List.generate(lastDay, (index) => DateTime(year, month, index + 1));
  // }

  bool isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  bool isHoliday(DateTime date) {
    final key = "${date.day}-${date.month}-${date.year}";
    return holidayDateKeys.contains(key);
  }

  // Attendance Map (only this employee)
  final attendanceMap = <String, String>{}; // dateKey -> type
  for (final a in monthlyAttendance) {
    if (a["employeeId"] == employeeId) {
      final date = a["date"]; // dd-MM-yyyy
      final type = a["attendanceType"] ?? "P";
      attendanceMap[date] = type;
    }
  }

  // Leave Map (only this employee)
  final leaveSet = <String>{};
  for (final leave in approvedLeaves) {
    if (leave["employeeId"] != employeeId) continue;

    // final fromRaw = DateTime.parse(leave["fromDate"]).toLocal();
    // final toRaw = DateTime.parse(leave["toDate"]).toLocal();
    final fromRaw = safeParseDate(leave["fromDate"]).toLocal();
final toRaw = safeParseDate(leave["toDate"]).toLocal();


    final from = DateTime(fromRaw.year, fromRaw.month, fromRaw.day);
    final to = DateTime(toRaw.year, toRaw.month, toRaw.day);

    for (DateTime d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
      leaveSet.add(DateFormat("dd-MM-yyyy").format(d));
    }
  }

  // ---- calculate summary ----
  // final days = getDaysInMonth(year, monthIndex);
  final firstDayOfMonth = DateTime(year, monthIndex, 1);
final lastDayOfMonth = DateTime(year, monthIndex + 1, 0);
// 🔥 FULL month working days (exclude weekends + holidays)
double fullMonthTotal = 0;

for (DateTime d = firstDayOfMonth;
    !d.isAfter(lastDayOfMonth);
    d = d.add(const Duration(days: 1))) {

  if (isWeekend(d)) continue;
  if (isHoliday(d)) continue;

  fullMonthTotal += 1;
}


// 🔥 Determine effective start date (DOJ proration)
DateTime effectiveStart = firstDayOfMonth;

if (employeeDOJ != null &&
    employeeDOJ!.year == year &&
    employeeDOJ!.month == monthIndex) {
  effectiveStart = DateTime(
    employeeDOJ!.year,
    employeeDOJ!.month,
    employeeDOJ!.day,
  );
}

// 🔥 Generate only eligible days
List<DateTime> days = [];

for (DateTime d = effectiveStart;
    !d.isAfter(lastDayOfMonth);
    d = d.add(const Duration(days: 1))) {
  days.add(d);
}


  double total = 0;
  double present = 0;
  double half = 0;
  double leave = 0;

  for (final d in days) {
    // completed month → no need to ignore future date logic
    if (isWeekend(d)) continue;
    if (isHoliday(d)) continue;

    total += 1;

    final key = DateFormat("dd-MM-yyyy").format(d);

    // Leave has higher priority than attendance
    if (leaveSet.contains(key)) {
      leave += 1;
      continue;
    }

    final status = attendanceMap[key];

    if (status == "P") {
      present += 1;
    } else if (status == "HL") {
      half += 0.5;
    } else {
      // if no record or status is A → absent
    }
  }

  final absent = total - present - half - leave;

  // Eligible leave = 3
  const eligibleLeave = 3.0;
final extraLeaveLop = (leave - eligibleLeave) > 0 ? (leave - eligibleLeave) : 0.0;
final lop = absent + extraLeaveLop;

  setState(() {
    totalWorkingDays = total.toDouble();
    presentDays = present.toDouble();
    halfDays = half.toDouble();
    leaveDays = leave.toDouble();
    absentDays = absent.toDouble();
    lopDays = lop.toDouble();
    fullMonthWorkingDays = fullMonthTotal; 
  });
}

  Future<void> _fetchPayslipDetails() async {
  final employeeId =
      Provider.of<UserProvider>(context, listen: false).employeeId;

  if (employeeId == null) return;

  final url = Uri.parse(
    'https://company-04bz.onrender.com/get-payslip-details?employee_id=$employeeId&year=$selectedYear&month=$selectedMonth',
  );

  try {
    final response = await http.get(url);

    if (response.statusCode != 200) {
      print("❌ Failed to fetch payslip");
      return;
    }

    final data = jsonDecode(response.body);

    // ✅ 1️⃣ Parse DOJ FIRST
    final rawDate = data['date_of_joining'];
    if (rawDate != null && rawDate.toString().isNotEmpty) {
      final parsedDate = safeParseDate(rawDate);
      if (employeeDOJ == null) {
    employeeDOJ = parsedDate;
    _autoSelectLatestValidMonth(); // 🔥 only first time
  }
    }

    // ✅ 3️⃣ Assign earnings/deductions
    earnings = data['earnings'] ?? {};
    deductions = data['deductions'] ?? {};

    if (earnings.isEmpty && deductions.isEmpty) {
      setState(() {
        noPayslipAvailable = true;
        employeeData = {};
      });
      return;
    } else {
      noPayslipAvailable = false;
    }

    // ✅ 4️⃣ Calculate Attendance
    await fetchMonthlyPayrollSummary();

    // ✅ 5️⃣ Salary Calculations
    final gross =
        double.tryParse(earnings['GrossTotalSalary']?.toString() ?? "0") ?? 0;

    final otherDeduction =
        double.tryParse(deductions['TotalDeductions']?.toString() ?? "0") ?? 0;

    // 🔥 Calculate FULL month working days (for divisor)
int monthIndex = _months.indexOf(selectedMonth) + 1;

    double perDaySalary =
    fullMonthWorkingDays > 0 ? gross / fullMonthWorkingDays : 0;

double salaryBeforeLop = perDaySalary * totalWorkingDays;

lopAmount = perDaySalary * lopDays;

double newNetSalary =
    salaryBeforeLop - otherDeduction - lopAmount;

    deductions['LOP Amount'] = lopAmount.toStringAsFixed(2);
    deductions['NetSalary'] = newNetSalary.toStringAsFixed(2);

    // final monthIndex = _months.indexOf(selectedMonth) + 1;
    final totalMonthDays =
        getTotalDaysInMonth(int.parse(selectedYear), monthIndex);

    setState(() {
      employeeData = {
        'employee_name': (data['employee_name'] ?? '').toString(),
        'employee_id': (data['employee_id'] ?? '').toString(),
        'designation': (data['designation'] ?? '').toString(),
        'location': (data['location'] ?? '').toString(),
        'no_of_workdays': totalMonthDays.toString(),
        'date_of_joining':
            DateFormat('dd-MM-yyyy').format(employeeDOJ!),
        'bank_name': (data['bank_name'] ?? '').toString(),
        'account_no': (data['account_no'] ?? '').toString(),
        'pan': (data['pan'] ?? '').toString(),
        'uan': (data['uan'] ?? '').toString(),
        'esic_no': (data['esic_no'] ?? '').toString(),
        'lop': lopDays.toStringAsFixed(1),
      };
    });
  } catch (e) {
    print("❌ Network error: $e");
  }
}



  Future<void> _generatePdf() async {
  final pdf = pw.Document();

  final imageLogo = pw.MemoryImage(
    (await rootBundle.load('assets/logo_zeai.png')).buffer.asUint8List(),
  );

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) {
        return pw.Container(
          height: PdfPageFormat.a4.availableHeight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // ================= Top & Middle Content =================
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Company Header
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Image(imageLogo, height: 50),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("ZeAI Soft",
                              style: pw.TextStyle(
                                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                              "3rd Floor,SKCL Tech Square,Lazer St,South Phase",
                              style: pw.TextStyle(fontSize: 12)),
                          pw.Text(
                              "SIDCO Industrial Estate,Guindy,Chennai,Tamil Nadu 600032",
                              style: pw.TextStyle(fontSize: 12)),
                          pw.Text("info@zeaisoft.com | +91 97876 36374",
                              style: pw.TextStyle(fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 5),

                  // Payslip Title
                  pw.Center(
                    child: pw.Text(
                      'Payslip for $selectedMonth $selectedYear',
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 10),

                  // Employee Details
                  pw.Text('Employee Details',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border:
                        pw.TableBorder.all(width: 1, color: PdfColors.grey),
                    children: [
                      _detailRow('Employee Name', employeeData['employee_name'],
                          'Employee ID', employeeData['employee_id']),
                      _detailRow('Date of Joining',
                          employeeData['date_of_joining'], 'Bank Name',
                          employeeData['bank_name']),
                      _detailRow('Designation', employeeData['designation'],
                          'Account No', employeeData['account_no']),
                      _detailRow('Location', employeeData['location'], 'UAN',
                          employeeData['uan']),
                      _detailRow('No.Of Days',
                          employeeData['no_of_workdays'], 'ESIC No',
                          employeeData['esic_no']),
                      _detailRow('PAN', employeeData['pan'], 'LOP Days',
                          employeeData['lop']),
                    ],
                  ),

                  // ✅ Extra space between employee details and earnings
                  pw.SizedBox(height: 30),

                  // Earnings + Deductions
                  pw.Table(
                    border:
                        pw.TableBorder.all(width: 1, color: PdfColors.grey),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#9F71F8')),
                       children: [
  _cell('Earnings', isBold: true),
  _cell('Amount (Rs)', isBold: true),
  _cell('Deductions', isBold: true),
  _cell('Amount (Rs)', isBold: true),
],
                      ),
                      ...List.generate(
                        (earnings.length > deductions.length
                            ? earnings.length
                            : deductions.length),
                        (index) {
                          final earningKey = index < earnings.keys.length
                              ? earnings.keys.elementAt(index)
                              : '';
                          final earningValue = index < earnings.values.length
                              ? earnings.values.elementAt(index).toString()
                              : '';
                          final deductionKey = index < deductions.keys.length
                              ? deductions.keys.elementAt(index)
                              : '';
                          final deductionValue = index < deductions.values.length
                              ? deductions.values.elementAt(index).toString()
                              : '';

                          return pw.TableRow(
                            children: [
                              _cell(earningKey),
                              _cell(earningValue),
                              _cell(deductionKey),
                              _cell(deductionValue),
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 30),

                  // Net Pay
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      "Net Salary: Rs ${deductions['NetSalary'] ?? '-'}",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // ================= Footer (Bottom Note) =================
              pw.Column(
                children: [
                  pw.Divider(thickness: 1, color: PdfColors.grey),
                  pw.SizedBox(height: 6),
                  pw.Center(
                    child: pw.Text(
                      "This document has been automatically generated by system; therefore, a signature is not required",
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
  );
}





  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: 'Payslip',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _monthYearDropdowns(),
            const SizedBox(height: 12),
            _payslipHeader(),
            const SizedBox(height: 12),
            if (noPayslipAvailable)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.all(40),
    alignment: Alignment.center,
    child: const Text(
      "No payslip available for this month",
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white70,
      ),
    ),
  )
else ...[
  _employeeDetails(),
  const SizedBox(height: 12),
  _salaryDetails(),
],

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _button(
  Icons.picture_as_pdf,
  'Payslips',
  noPayslipAvailable ? Colors.grey : Colors.blueGrey,
  noPayslipAvailable ? () {} : _generatePdf,
),

                _outlinedButton(Icons.download, 'Download', noPayslipAvailable ? () {} : _generatePdf),
                // _filledButton('Send'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthYearDropdowns() {
  DateTime now = DateTime.now();
  int currentYear = now.year;
  int currentMonth = now.month; // current month (1–12)
  

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      DropdownButton<String>(
        value: selectedMonth,
        dropdownColor: Colors.black,
        items: _months.asMap().entries.map((entry) {
          int monthIndex = entry.key + 1; // 1-based index
          String month = entry.value;

          bool isEnabled = false;

int year = int.parse(selectedYear);

if (employeeDOJ != null) {

  DateTime monthDate = DateTime(year, monthIndex);

  // ❌ Disable if before joining month
  if (monthDate.isBefore(DateTime(employeeDOJ!.year, employeeDOJ!.month))) {
    isEnabled = false;
  }

  // ❌ Disable future months
  else if (year == currentYear && monthIndex >= currentMonth) {
    isEnabled = false;
  }

  // ❌ Disable future years
  else if (year > currentYear) {
    isEnabled = false;
  }

  // ✅ Otherwise enable
  else {
    isEnabled = true;
  }
}
          return DropdownMenuItem(
            value: month,
            enabled: isEnabled, // 👈 disable future months
            child: Text(
              month,
              style: TextStyle(
                color: isEnabled ? Colors.white : Colors.grey, // blur effect
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
  if (value != null) {
    setState(() {
      selectedMonth = value;   // ✅ FIXED
    });
    _fetchPayslipDetails();
  }
},


      ),
      const SizedBox(width: 20),
      DropdownButton<String>(
  value: _years.contains(selectedYear) ? selectedYear : null,
  dropdownColor: Colors.black,
  hint: const Text(
    "Year",
    style: TextStyle(color: Colors.white),
  ),
  items: _years.map((year) {
    return DropdownMenuItem(
      value: year,
      child: Text(
        year,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }).toList(),
  onChanged: (value) {
  if (value != null) {
    setState(() {
      selectedYear = value;

      int monthIndex = _months.indexOf(selectedMonth) + 1;

      if (!_isMonthValid(int.parse(value), monthIndex)) {
        _fixMonthForSelectedYear(int.parse(value));
      }
    });

    _fetchPayslipDetails();
  }
},
),

    ],
  );
}


  Widget _payslipHeader() {
    return Center(
      child: Container(
        width: 505,
        height: 49,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Payslip for $selectedMonth $selectedYear',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _employeeDetails() {
    if (employeeData.isEmpty) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          _infoRow(
            'Employee Name',
            employeeData['employee_name'] ?? '',
            'Employee ID',
            employeeData['employee_id'] ?? '',
          ),
          
          const Divider(),
          _infoRow(
            'Date of Joining',
            employeeData['date_of_joining'] ?? '',
            'Bank Name',
            employeeData['bank_name'] ?? '',
          ),
          const Divider(),
          _infoRow(
            'Designation',
            employeeData['designation'] ?? '',
            'Account NO',
            employeeData['account_no'] ?? '',
          ),
          const Divider(),
          _infoRow(
            'Location',
            employeeData['location'] ?? '',
            'UAN',
            employeeData['uan'] ?? '',
          ),
          const Divider(),
          _infoRow(
            'No.Of Days',
            employeeData['no_of_workdays'] ?? '',
            'ESIC No',
            employeeData['esic_no'] ?? '',
          ),
          const Divider(),
          _infoRow(
            'PAN',
            employeeData['pan'] ?? '',
            'LOP Days',
            employeeData['lop'] ?? '',
          ),
        ],
      ),
    );
  }

  Widget _salaryDetails() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header('Earnings'),
                for (var entry in earnings.entries)
                  if (entry.key.toLowerCase() != 'GrossTotalSalary')
                    _payRow(entry.key, 'Rs ${entry.value}'),
                const Divider(),
                _payRow(
                  'Gross Total Salary',
                  'Rs ${earnings['GrossTotalSalary'] ?? '-'}',
                  isBold: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 200, color: Colors.black12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header('Deductions'),
                for (var entry in deductions.entries)
                  if (entry.key.toLowerCase() != 'TotalDeductions' &&
                      entry.key.toLowerCase() != 'NetSalary')
                    _payRow(entry.key, 'Rs ${entry.value}'),
                const Divider(),
                _payRow(
                  'Total Deductions',
                  'Rs ${deductions['TotalDeductions'] ?? '-'}',
                  isBold: true,
                ),
                _payRow(
                  'Net Salary',
                  'Rs ${deductions['NetSalary'] ?? '-'}',
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label1, String value1, String label2, String value2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label1: $value1',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              '$label2: $value2',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: const Color.fromARGB(129, 132, 26, 238),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _payRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(IconData icon, String text, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 41,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlinedButton(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 66,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            Text(text, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // Widget _filledButton(String text) {
  //   return Container(
  //     width: 80,
  //     height: 35,
  //     decoration: BoxDecoration(
  //       color: const Color(0xFF9F71F8),
  //       borderRadius: BorderRadius.circular(8),
  //     ),
  //     alignment: Alignment.center,
  //     child: Text(
  //       text,
  //       style: const TextStyle(
  //         color: Colors.white,
  //         fontWeight: FontWeight.bold,
  //       ),
  //     ),
  //   );
  // }
}

// PDF helper methods
pw.TableRow _detailRow(String k1, String? v1, String k2, String? v2) {
  return pw.TableRow(
    children: [
      _cell('$k1: ${v1 ?? ''}'),
      _cell('$k2: ${v2 ?? ''}'),
    ],
  );
}

pw.Widget _cell(String text, {bool isBold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(
      vertical: 7,
      horizontal: 4,
    ),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}