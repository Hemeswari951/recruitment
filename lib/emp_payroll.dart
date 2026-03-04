// emp_payroll.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'payslip.dart';
import 'sidebar.dart';
import 'user_provider.dart';

class EmpPayroll extends StatefulWidget {
  const EmpPayroll({super.key});

  @override
  State<EmpPayroll> createState() => _EmpPayrollState();
}

class _EmpPayrollState extends State<EmpPayroll> {
  String? selectedYear;
  // List<bool> checkedList = List<bool>.filled(12, false);
  final ValueNotifier<List<bool>> checkedList =
    ValueNotifier(List<bool>.filled(12, false));

  final ScrollController _scrollController = ScrollController();
  DateTime? employeeDOJ;


  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _fetchEmployeeDOJ);
  }

  @override
void dispose() {
  _scrollController.dispose();
  super.dispose();
}

  bool _areAllAllowedMonthsChecked() {
  if (selectedYear == null || employeeDOJ == null) return false;

  int selected = int.parse(selectedYear!);
  DateTime now = DateTime.now();

  for (int i = 0; i < checkedList.value.length; i++) {
    bool isDisabled = false;
    DateTime monthDate = DateTime(selected, i + 1);

    // ❌ Before joining month
    if (monthDate.isBefore(
        DateTime(employeeDOJ!.year, employeeDOJ!.month))) {
      isDisabled = true;
    }

    // ❌ Future months in current year
    else if (selected == now.year &&
        i + 1 >= now.month) {
      isDisabled = true;
    }

    // ❌ Future years
    else if (selected > now.year) {
      isDisabled = true;
    }

    if (!isDisabled && !checkedList.value[i]) {
      return false;
    }
  }

  return true;
}


   int getTotalDaysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}

  static const List<String> months = [
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

  static const List<String> monthKeys = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  DateTime safeParseDate(String raw) {
  try {
    return DateTime.parse(raw);
  } catch (_) {
    try {
      return DateFormat('dd-MM-yyyy').parse(raw);
    } catch (_) {
      return DateFormat('dd/MM/yyyy').parse(raw);
    }
  }
}

List<String> get _years {
  int currentYear = DateTime.now().year;

  if (employeeDOJ == null) {
    return [currentYear.toString()];
  }

  int joinYear = employeeDOJ!.year;

  return List.generate(
    currentYear - joinYear + 1,
    (index) => (joinYear + index).toString(),
  );
}

Future<void> _fetchEmployeeDOJ() async {
  final employeeId =
      Provider.of<UserProvider>(context, listen: false).employeeId;

  if (employeeId == null) return;

  final response = await http.post(
    Uri.parse('https://company-04bz.onrender.com/get-multiple-payslips'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'employee_id': employeeId,
      'year': DateTime.now().year.toString(),
      'months': [], // 👈 EMPTY
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final employee = data['employeeInfo'];

    if (employee != null && employee['date_of_joining'] != null) {
      setState(() {
        employeeDOJ = safeParseDate(employee['date_of_joining']);
        selectedYear = DateTime.now().year.toString();
      });
    }
  } else {
    print("Failed to fetch DOJ: ${response.body}");
  }
}


Future<Map<String, double>> fetchMonthlyPayrollSummaryForPdf({
  required String employeeId,
  required int monthIndex,
  required int year,
  required String monthName,
}) async {
  // 1) Attendance month
  final resAttendance = await http.get(Uri.parse(
    "https://company-04bz.onrender.com/attendance/attendance/month?year=$year&month=$monthIndex",
  ));

  // 2) Approved leave month
  final resLeaves = await http.get(Uri.parse(
    "https://company-04bz.onrender.com/apply/approved/month?year=$year&month=$monthIndex",
  ));

  // 3) Holiday month
  final resHolidays = await http.get(Uri.parse(
    "https://company-04bz.onrender.com/notifications/holiday/employee/ADMIN?month=$monthName&year=$year",
  ));

  List<Map<String, dynamic>> monthlyAttendance = [];
  List<Map<String, dynamic>> approvedLeaves = [];
  Set<String> holidayDateKeys = {};

  if (resAttendance.statusCode == 200) {
    monthlyAttendance =
        List<Map<String, dynamic>>.from(jsonDecode(resAttendance.body));
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

  // Helpers
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

  // Attendance Map for employee
  final attendanceMap = <String, String>{};
  for (final a in monthlyAttendance) {
    if (a["employeeId"] == employeeId) {
      final date = a["date"]; // dd-MM-yyyy
      final type = a["attendanceType"] ?? "P";
      attendanceMap[date] = type;
    }
  }

  // Leave Set for employee
  final leaveSet = <String>{};
  for (final leave in approvedLeaves) {
    if (leave["employeeId"] != employeeId) continue;

    // final fromRaw = DateTime.parse(leave["fromDate"]).toLocal();
    // final toRaw = DateTime.parse(leave["toDate"]).toLocal();
    final fromRaw = safeParseDate(leave["fromDate"]).toLocal();
final toRaw   = safeParseDate(leave["toDate"]).toLocal();


    final from = DateTime(fromRaw.year, fromRaw.month, fromRaw.day);
    final to = DateTime(toRaw.year, toRaw.month, toRaw.day);

    for (DateTime d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
      leaveSet.add(DateFormat("dd-MM-yyyy").format(d));
    }
  }

  // Calculate
  // final days = getDaysInMonth(year, monthIndex);
  final firstDayOfMonth = DateTime(year, monthIndex, 1);
final lastDayOfMonth = DateTime(year, monthIndex + 1, 0);
// 🔥 FULL month working days
double fullMonthWorkingDays = 0;

for (DateTime d = firstDayOfMonth;
    !d.isAfter(lastDayOfMonth);
    d = d.add(const Duration(days: 1))) {

  if (isWeekend(d)) continue;
  if (isHoliday(d)) continue;

  fullMonthWorkingDays += 1;
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
  double total = 0;
  double present = 0;
  double half = 0;
  double leave = 0;

  for (DateTime d = effectiveStart;
    !d.isAfter(lastDayOfMonth);
    d = d.add(const Duration(days: 1))) {

  if (isWeekend(d)) continue;
  if (isHoliday(d)) continue;

  total += 1;

    final key = DateFormat("dd-MM-yyyy").format(d);

    if (leaveSet.contains(key)) {
      leave += 1;
      continue;
    }

    final status = attendanceMap[key];

    if (status == "P") {
      present += 1;
    } else if (status == "HL") {
      half += 0.5;
    }
  }

  final absent = total - present - half - leave;

  // ✅ Your rule:
  // LOP = Absent + extra leave above 3
  const eligibleLeave = 3.0;
  final extraLeaveLop = (leave - eligibleLeave) > 0 ? (leave - eligibleLeave) : 0.0;
  final lop = absent + extraLeaveLop;

  return {
    "fullMonthWorkingDays": fullMonthWorkingDays,
    "eligibleWorkingDays": total,
    "presentDays": present,
    "halfDays": half,
    "leaveDays": leave,
    "absentDays": absent,
    "lopDays": lop,
  };
}


  Future<void> _downloadAllCheckedPayslips() async {
    final employeeId =
        Provider.of<UserProvider>(context, listen: false).employeeId;

    if (employeeId == null ||
        selectedYear == null ||
        !checkedList.value.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select year and at least one month')),
      );
      return;
    }

    final selectedMonths = <String>[];
    for (int i = 0; i < checkedList.value.length; i++) {
      if (checkedList.value[i]) {
        selectedMonths.add(monthKeys[i]);
      }
    }

    try {
      final response = await http.post(
        Uri.parse('https://company-04bz.onrender.com/get-multiple-payslips'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'year': selectedYear,
          'months': selectedMonths,
          'employee_id': employeeId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final employee = Map<String, dynamic>.from(data['employeeInfo']);
        final pdf = pw.Document();

        final imageLogo = pw.MemoryImage(
          (await rootBundle.load('assets/logo_zeai.png')).buffer.asUint8List(),
        );

        for (final monthKey in selectedMonths) {
          if (data['months'][monthKey] == null) {
    print("⚠️ No payslip data for $monthKey");
    continue;
  }
  final monthIndex = monthKeys.indexOf(monthKey);
  final monthName = months[monthIndex];

  final totalMonthDays = getTotalDaysInMonth(
  int.parse(selectedYear!),
  monthIndex + 1,
);


  // ✅ attendance summary
  final summary = await fetchMonthlyPayrollSummaryForPdf(
    employeeId: employeeId,
    monthIndex: monthIndex + 1,
    year: int.parse(selectedYear!),
    monthName: monthName,
  );

  // final totalWorkdays = summary["totalWorkingDays"] ?? 0;
  final fullMonthDays = summary["fullMonthWorkingDays"] ?? 0;
final eligibleDays = summary["eligibleWorkingDays"] ?? 0;
final lopDays = summary["lopDays"] ?? 0;
  
  // ✅ backend earnings/deductions
  final earnings =
      Map<String, dynamic>.from(data['months'][monthKey]['earnings']);
  final deductions =
      Map<String, dynamic>.from(data['months'][monthKey]['deductions']);

  // ✅ calculate LOP salary
  final gross =
      double.tryParse(earnings['GrossTotalSalary']?.toString() ?? "0") ?? 0;
  final otherDeduction =
      double.tryParse(deductions['TotalDeductions']?.toString() ?? "0") ?? 0;

  double perDaySalary = 0;

if (fullMonthDays > 0) {
  perDaySalary = gross / fullMonthDays;
}

// 🔥 Salary only for eligible days
final proratedGross = perDaySalary * eligibleDays;

final lopAmount = perDaySalary * lopDays;

final netSalary = proratedGross - otherDeduction - lopAmount;
  // final netSalary = gross - otherDeduction;


  // ✅ update deductions for pdf printing
  deductions['LOP Amount'] = lopAmount.toStringAsFixed(2);
  deductions['NetSalary'] = netSalary.toStringAsFixed(2);

  String formattedDoj = employee['date_of_joining'];

if (formattedDoj.contains('-')) {
  try {
    final d = safeParseDate(formattedDoj);
    formattedDoj = DateFormat('dd-MM-yyyy').format(d);
  } catch (_) {}
}

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
                      'Payslip for $monthName $selectedYear',
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
                      
                      _detailRow('Employee Name', employee['employee_name'],
                          'Employee ID', employee['employee_id']),
                      // _detailRow('Date of Joining',
                      //     employee['date_of_joining'], 'Bank Name',
                      //     employee['bank_name']),
                      _detailRow('Date of Joining', formattedDoj, 'Bank Name', employee['bank_name']),
                      _detailRow('Designation', employee['designation'],
                          'Account No', employee['account_no']),
                      _detailRow('Location', employee['location'], 'UAN',
                          employee['uan']),
                      _detailRow(
  // 'No.Of Days Worked',
  // totalWorkdays.toStringAsFixed(0),
  'No.Of Days',
  totalMonthDays.toString(),
  'ESIC No',
  employee['esic_no'],
),
                      _detailRow('PAN', employee['pan'], 'LOP Days',
                          lopDays.toStringAsFixed(1)),
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
        }

        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}')),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exception: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: 'Payroll Management',
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
              ),
            ),
            const SizedBox(height: 10),

            // Header Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PayslipScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C314A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Payslip',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 20),
                  DropdownButton<String>(
                    value: _years.contains(selectedYear) ? selectedYear : null,
                    hint: const Text(
                      'Select Year',
                      style: TextStyle(color: Colors.white),
                    ),
                    dropdownColor: const Color(0xFF2C314A),
                    icon:
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                    style: const TextStyle(color: Colors.white),
                    items: _years.map((year) {
  return DropdownMenuItem(
    value: year,
    child: Text(year, style: const TextStyle(color: Colors.white)),
  );
}).toList(),
                    onChanged: (value) {
  if (value == null) return;

  setState(() {
    selectedYear = value;
  });

  // ✅ Reset all months safely
  checkedList.value = List<bool>.filled(12, false);
},
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _downloadAllCheckedPayslips,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C314A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Download Selected Payslips',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Scrollable Month List
            Expanded(
  child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF2C314A),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [

        // ✅ STATIC HEADER (NOT SCROLLING)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              flex: 8,
              child: Text(
                'Months',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Check All',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Checkbox(
                    value: _areAllAllowedMonthsChecked(),
                    onChanged: (bool? value) {
                      if (selectedYear == null) return;
                      setState(() {
                        int currentYear = DateTime.now().year;
                        int currentMonth = DateTime.now().month;
                        int selected = int.parse(selectedYear!);

                        final updated = List<bool>.from(checkedList.value);

for (int i = 0; i < updated.length; i++) {
  bool isDisabled = false;
  DateTime monthDate = DateTime(selected, i + 1);

  if (employeeDOJ != null &&
      monthDate.isBefore(DateTime(employeeDOJ!.year, employeeDOJ!.month))) {
    isDisabled = true;
  } else if (selected == currentYear && i + 1 >= currentMonth) {
    isDisabled = true;
  } else if (selected > currentYear) {
    isDisabled = true;
  }

  if (!isDisabled) {
    updated[i] = value ?? false;
  } else {
    updated[i] = false;
  }
}

checkedList.value = updated;
                      });
                    },
                    checkColor: Colors.black,
                    fillColor:
                        WidgetStateProperty.all<Color>(Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),

        const Divider(thickness: 2, color: Colors.white),
        const SizedBox(height: 10),

        // ✅ SCROLLABLE MONTH LIST ONLY
        // ✅ SCROLLABLE MONTH LIST ONLY
Expanded(
  child: ValueListenableBuilder<List<bool>>(
    valueListenable: checkedList,
    builder: (context, list, _) {
      return ListView.builder(
        controller: _scrollController,
        itemCount: 12,
        itemBuilder: (context, index) {
          int currentYear = DateTime.now().year;
          int currentMonth = DateTime.now().month;
          bool isDisabled = false;

          if (selectedYear != null) {
            int selected = int.parse(selectedYear!);

            if (employeeDOJ != null) {
              DateTime now = DateTime.now();
              DateTime monthDate = DateTime(selected, index + 1);

              // ❌ before joining month
              if (monthDate.isBefore(
                  DateTime(employeeDOJ!.year, employeeDOJ!.month))) {
                isDisabled = true;
              }
              // ❌ future months current year
              else if (selected == now.year &&
                  index + 1 >= now.month) {
                isDisabled = true;
              }
              // ❌ future years
              else if (selected > now.year) {
                isDisabled = true;
              }
            } else if (selected == currentYear) {
              isDisabled = index + 1 >= currentMonth;
            } else if (selected > currentYear) {
              isDisabled = true;
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  flex: 8,
                  child: Text(
                    months[index],
                    style: TextStyle(
                      color: isDisabled
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: AbsorbPointer(
                    absorbing: isDisabled,
                    child: Opacity(
                      opacity: isDisabled ? 0.3 : 1.0,
                      child: Checkbox(
                        value: list[index], // ✅ IMPORTANT
                        onChanged: isDisabled
                            ? null
                            : (bool? value) {
                                final updated = [...list];
                                updated[index] = value ?? false;
                                checkedList.value = updated;
                              },
                        checkColor: Colors.black,
                        fillColor:
                            WidgetStateProperty.all<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  ),
),
      ],
    
    ),
  ),
            
),

          ],
        ),
      ),
    );
  }
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