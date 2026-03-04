import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'sidebar.dart';

class AdminPayslipViewer extends StatefulWidget {
  const AdminPayslipViewer({super.key});

  @override
  State<AdminPayslipViewer> createState() => _AdminPayslipViewerState();
}

class _AdminPayslipViewerState extends State<AdminPayslipViewer> {
  double fullMonthWorkingDays = 0;
  bool isLoading = false;
  bool noPayslipAvailable = false;
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  DateTime? employeeDOJ;

  DateTime safeParseDate(String raw) {
    try {
      return DateTime.parse(raw); // ISO format yyyy-MM-dd
    } catch (_) {
      try {
        return DateFormat('dd-MM-yyyy').parse(raw);
      } catch (_) {
        return DateFormat('dd/MM/yyyy').parse(raw);
      }
    }
  }

  bool _isMonthValid(int year, int monthIndex) {
    DateTime now = DateTime.now();
    DateTime selected = DateTime(year, monthIndex);

    if (year > now.year) return false;
    if (year == now.year && monthIndex >= now.month) return false;

    if (employeeDOJ != null) {
      DateTime joinMonth = DateTime(employeeDOJ!.year, employeeDOJ!.month);
      if (selected.isBefore(joinMonth)) return false;
    }

    return true;
  }

  List<String> get _years {
    if (employeeDOJ == null) {
      return [selectedYear];
    }
    int joinYear = employeeDOJ!.year;
    int currentYear = DateTime.now().year;
    return List.generate(
      currentYear - joinYear + 1,
      (index) => (joinYear + index).toString(),
    );
  }

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

  // Search related
  final TextEditingController _searchController = TextEditingController();
  String? searchedEmployeeId;
  List<dynamic> _searchResults = [];
  Timer? _debounce;

  void _autoSelectLatestValidMonth() {
    if (employeeDOJ == null) return;

    DateTime now = DateTime.now();
    DateTime lastCompletedMonth = DateTime(now.year, now.month - 1);
    DateTime joiningMonth = DateTime(employeeDOJ!.year, employeeDOJ!.month);

    DateTime target = lastCompletedMonth.isBefore(joiningMonth)
        ? joiningMonth
        : lastCompletedMonth;

    selectedYear = target.year.toString();
    selectedMonth = _months[target.month - 1];
  }

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    int prevMonth = now.month - 1;

    if (prevMonth == 0) {
      prevMonth = 12;
      selectedYear = (now.year - 1).toString();
    } else {
      selectedYear = now.year.toString();
    }

    selectedMonth = _months[prevMonth - 1];
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          _searchResults = [];
        });
        return;
      }
      try {
        final res = await http.get(Uri.parse("https://company-04bz.onrender.com/api/employees/search/$query"));
        if (res.statusCode == 200) {
          setState(() {
            _searchResults = jsonDecode(res.body);
          });
        }
      } catch (e) {
        debugPrint("Search error: $e");
      }
    });
  }

  void _selectEmployee(dynamic emp) {
    setState(() {
      searchedEmployeeId = emp['employeeId'];
      _searchController.text = "${emp['employeeName']} (${emp['employeeId']})";
      _searchResults = [];
      employeeDOJ = null;
      earnings = {};
      deductions = {};
      employeeData = {};
      noPayslipAvailable = false;
      isLoading = true;
    });
    _fetchPayslipDetails();
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

    int validMonth = endMonth;
    selectedMonth = _months[validMonth - 1];
  }

  Future<void> fetchMonthlyPayrollSummary() async {
    final employeeId = searchedEmployeeId;
    if (employeeId == null || employeeId.isEmpty) return;

    final monthIndex = _months.indexOf(selectedMonth) + 1;
    final year = int.parse(selectedYear);

    final resAttendance = await http.get(Uri.parse(
      "https://company-04bz.onrender.com/attendance/attendance/month?year=$year&month=$monthIndex",
    ));

    final resLeaves = await http.get(Uri.parse(
      "https://company-04bz.onrender.com/apply/approved/month?year=$year&month=$monthIndex",
    ));

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

    bool isWeekend(DateTime date) =>
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    bool isHoliday(DateTime date) {
      final key = "${date.day}-${date.month}-${date.year}";
      return holidayDateKeys.contains(key);
    }

    final attendanceMap = <String, String>{};
    for (final a in monthlyAttendance) {
      if (a["employeeId"] == employeeId) {
        final date = a["date"];
        final type = a["attendanceType"] ?? "P";
        attendanceMap[date] = type;
      }
    }

    final leaveSet = <String>{};
    for (final leave in approvedLeaves) {
      if (leave["employeeId"] != employeeId) continue;

      final fromRaw = safeParseDate(leave["fromDate"]).toLocal();
      final toRaw = safeParseDate(leave["toDate"]).toLocal();

      final from = DateTime(fromRaw.year, fromRaw.month, fromRaw.day);
      final to = DateTime(toRaw.year, toRaw.month, toRaw.day);

      for (DateTime d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
        leaveSet.add(DateFormat("dd-MM-yyyy").format(d));
      }
    }

    final firstDayOfMonth = DateTime(year, monthIndex, 1);
    final lastDayOfMonth = DateTime(year, monthIndex + 1, 0);
    double fullMonthTotal = 0;

    for (DateTime d = firstDayOfMonth;
        !d.isAfter(lastDayOfMonth);
        d = d.add(const Duration(days: 1))) {
      if (isWeekend(d)) continue;
      if (isHoliday(d)) continue;
      fullMonthTotal += 1;
    }

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
    final employeeId = searchedEmployeeId;
    if (employeeId == null) return;

    final url = Uri.parse(
      'https://company-04bz.onrender.com/get-payslip-details?employee_id=$employeeId&year=$selectedYear&month=$selectedMonth',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        setState(() {
          isLoading = false;
          noPayslipAvailable = true;
          employeeData = {};
          earnings = {};
          deductions = {};
        });
        return;
      }

      final data = jsonDecode(response.body);
      final rawDate = data['date_of_joining'];
      if (rawDate != null && rawDate.toString().isNotEmpty) {
        final parsedDate = safeParseDate(rawDate);
        if (employeeDOJ == null) {
          employeeDOJ = parsedDate;
          _autoSelectLatestValidMonth();
        }
      }

      earnings = data['earnings'] ?? {};
      deductions = data['deductions'] ?? {};

      if (earnings.isEmpty && deductions.isEmpty) {
        setState(() {
          noPayslipAvailable = true;
          employeeData = {};
          isLoading = false;
        });
        return;
      } else {
        noPayslipAvailable = false;
      }

      await fetchMonthlyPayrollSummary();

      final gross = double.tryParse(earnings['GrossTotalSalary']?.toString() ?? "0") ?? 0;
      final otherDeduction = double.tryParse(deductions['TotalDeductions']?.toString() ?? "0") ?? 0;

      double perDaySalary = fullMonthWorkingDays > 0 ? gross / fullMonthWorkingDays : 0;
      double salaryBeforeLop = perDaySalary * totalWorkingDays;
      lopAmount = perDaySalary * lopDays;
      double newNetSalary = salaryBeforeLop - otherDeduction - lopAmount;

      deductions['LOP Amount'] = lopAmount.toStringAsFixed(2);
      deductions['NetSalary'] = newNetSalary.toStringAsFixed(2);

      final monthIndex = _months.indexOf(selectedMonth) + 1;
      final totalMonthDays = getTotalDaysInMonth(int.parse(selectedYear), monthIndex);

      setState(() {
        employeeData = {
          'employee_name': (data['employee_name'] ?? '').toString(),
          'employee_id': (data['employee_id'] ?? '').toString(),
          'designation': (data['designation'] ?? '').toString(),
          'location': (data['location'] ?? '').toString(),
          'no_of_workdays': totalMonthDays.toString(),
          'date_of_joining': DateFormat('dd-MM-yyyy').format(employeeDOJ!),
          'bank_name': (data['bank_name'] ?? '').toString(),
          'account_no': (data['account_no'] ?? '').toString(),
          'pan': (data['pan'] ?? '').toString(),
          'uan': (data['uan'] ?? '').toString(),
          'esic_no': (data['esic_no'] ?? '').toString(),
          'lop': lopDays.toStringAsFixed(1),
        };
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Network error: $e");
      setState(() => isLoading = false);
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
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Image(imageLogo, height: 50),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text("ZeAI Soft", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                            pw.Text("3rd Floor,SKCL Tech Square,Lazer St,South Phase", style: pw.TextStyle(fontSize: 12)),
                            pw.Text("SIDCO Industrial Estate,Guindy,Chennai,Tamil Nadu 600032", style: pw.TextStyle(fontSize: 12)),
                            pw.Text("info@zeaisoft.com | +91 97876 36374", style: pw.TextStyle(fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                    pw.Divider(thickness: 1),
                    pw.SizedBox(height: 5),
                    pw.Center(
                      child: pw.Text('Payslip for $selectedMonth $selectedYear', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('Employee Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border: pw.TableBorder.all(width: 1, color: PdfColors.grey),
                      children: [
                        _detailRow('Employee Name', employeeData['employee_name'], 'Employee ID', employeeData['employee_id']),
                        _detailRow('Date of Joining', employeeData['date_of_joining'], 'Bank Name', employeeData['bank_name']),
                        _detailRow('Designation', employeeData['designation'], 'Account No', employeeData['account_no']),
                        _detailRow('Location', employeeData['location'], 'UAN', employeeData['uan']),
                        _detailRow('No.Of Days', employeeData['no_of_workdays'], 'ESIC No', employeeData['esic_no']),
                        _detailRow('PAN', employeeData['pan'], 'LOP Days', employeeData['lop']),
                      ],
                    ),
                    pw.SizedBox(height: 30),
                    pw.Table(
                      border: pw.TableBorder.all(width: 1, color: PdfColors.grey),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#9F71F8')),
                          children: [
                            _cell('Earnings', isBold: true),
                            _cell('Amount (Rs)', isBold: true),
                            _cell('Deductions', isBold: true),
                            _cell('Amount (Rs)', isBold: true),
                          ],
                        ),
                        ...List.generate(
                          (earnings.length > deductions.length ? earnings.length : deductions.length),
                          (index) {
                            final earningKey = index < earnings.keys.length ? earnings.keys.elementAt(index) : '';
                            final earningValue = index < earnings.values.length ? earnings.values.elementAt(index).toString() : '';
                            final deductionKey = index < deductions.keys.length ? deductions.keys.elementAt(index) : '';
                            final deductionValue = index < deductions.values.length ? deductions.values.elementAt(index).toString() : '';
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
                    pw.Container(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text("Net Salary: Rs ${deductions['NetSalary'] ?? '-'}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Divider(thickness: 1, color: PdfColors.grey),
                    pw.SizedBox(height: 6),
                    pw.Center(
                      child: pw.Text("This document has been automatically generated by system; therefore, a signature is not required", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: 'Employee Payslips',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 20),
            if (searchedEmployeeId != null) ...[
              _monthYearDropdowns(),
              const SizedBox(height: 12),
              _payslipHeader(),
              const SizedBox(height: 12),
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else if (noPayslipAvailable)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  child: const Text("No payslip available for this month", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
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
                  _button(Icons.picture_as_pdf, 'Payslips', noPayslipAvailable ? Colors.grey : Colors.blueGrey, noPayslipAvailable ? () {} : _generatePdf),
                  _outlinedButton(Icons.download, 'Download', noPayslipAvailable ? () {} : _generatePdf),
                ],
              ),
            ] else
              const Center(child: Text("Please search and select an employee to view payslips.", style: TextStyle(color: Colors.white70))),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: "Search by Name or Employee ID",
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        searchedEmployeeId = null;
                        _searchResults = [];
                      });
                    },
                  )
                : null,
          ),
        ),
        if (_searchResults.isNotEmpty)
          Container(
            color: Colors.white,
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final emp = _searchResults[index];
                return ListTile(
                  title: Text("${emp['employeeName']} (${emp['employeeId']})"),
                  subtitle: Text(emp['position'] ?? ''),
                  onTap: () => _selectEmployee(emp),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _monthYearDropdowns() {
    DateTime now = DateTime.now();
    int currentYear = now.year;
    int currentMonth = now.month;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DropdownButton<String>(
          value: selectedMonth,
          dropdownColor: Colors.black,
          items: _months.asMap().entries.map((entry) {
            int monthIndex = entry.key + 1;
            String month = entry.value;
            bool isEnabled = false;
            int year = int.parse(selectedYear);

            if (employeeDOJ != null) {
              DateTime monthDate = DateTime(year, monthIndex);
              if (monthDate.isBefore(DateTime(employeeDOJ!.year, employeeDOJ!.month))) {
                isEnabled = false;
              } else if (year == currentYear && monthIndex >= currentMonth) {
                isEnabled = false;
              } else if (year > currentYear) {
                isEnabled = false;
              } else {
                isEnabled = true;
              }
            }
            return DropdownMenuItem(
              value: month,
              enabled: isEnabled,
              child: Text(month, style: TextStyle(color: isEnabled ? Colors.white : Colors.grey)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                selectedMonth = value;
              });
              _fetchPayslipDetails();
            }
          },
        ),
        const SizedBox(width: 20),
        DropdownButton<String>(
          value: _years.contains(selectedYear) ? selectedYear : null,
          dropdownColor: Colors.black,
          hint: const Text("Year", style: TextStyle(color: Colors.white)),
          items: _years.map((year) {
            return DropdownMenuItem(value: year, child: Text(year, style: const TextStyle(color: Colors.white)));
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Text('Payslip for $selectedMonth $selectedYear', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _employeeDetails() {
    if (employeeData.isEmpty) return const SizedBox();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Column(
        children: [
          _infoRow('Employee Name', employeeData['employee_name'] ?? '', 'Employee ID', employeeData['employee_id'] ?? ''),
          const Divider(),
          _infoRow('Date of Joining', employeeData['date_of_joining'] ?? '', 'Bank Name', employeeData['bank_name'] ?? ''),
          const Divider(),
          _infoRow('Designation', employeeData['designation'] ?? '', 'Account NO', employeeData['account_no'] ?? ''),
          const Divider(),
          _infoRow('Location', employeeData['location'] ?? '', 'UAN', employeeData['uan'] ?? ''),
          const Divider(),
          _infoRow('No.Of Days', employeeData['no_of_workdays'] ?? '', 'ESIC No', employeeData['esic_no'] ?? ''),
          const Divider(),
          _infoRow('PAN', employeeData['pan'] ?? '', 'LOP Days', employeeData['lop'] ?? ''),
        ],
      ),
    );
  }

  Widget _salaryDetails() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
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
                  if (entry.key.toLowerCase() != 'grosstotalsalary') _payRow(entry.key, 'Rs ${entry.value}'),
                const Divider(),
                _payRow('Gross Total Salary', 'Rs ${earnings['GrossTotalSalary'] ?? '-'}', isBold: true),
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
                  if (entry.key.toLowerCase() != 'totaldeductions' && entry.key.toLowerCase() != 'netsalary') _payRow(entry.key, 'Rs ${entry.value}'),
                const Divider(),
                _payRow('Total Deductions', 'Rs ${deductions['TotalDeductions'] ?? '-'}', isBold: true),
                _payRow('Net Salary', 'Rs ${deductions['NetSalary'] ?? '-'}', isBold: true),
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
          Expanded(child: Text('$label1: $value1', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text('$label2: $value2', style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _header(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: const Color.fromARGB(129, 132, 26, 238),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
    );
  }

  Widget _payRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
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
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
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
}

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
    padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 4),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 14, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );
}