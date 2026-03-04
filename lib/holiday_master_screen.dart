import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'sidebar.dart';

class HolidayMasterScreen extends StatefulWidget {
  const HolidayMasterScreen({super.key});

  @override
  State<HolidayMasterScreen> createState() => _HolidayMasterScreenState();
}

class _HolidayMasterScreenState extends State<HolidayMasterScreen> {
  final String baseUrl = "https://company-04bz.onrender.com/notifications";

  int selectedYear = DateTime.now().year;
  bool loading = true;

  final int startYear = 2020;
  final int endYear = 2030;

  final ScrollController _scrollController = ScrollController();

  Map<String, List<Map<String, dynamic>>> groupedHolidays = {};

  /// 🔴 THIS LIST IS MANDATORY
  final List<String> monthOrder = const [
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
    fetchHolidays();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchHolidays() async {
    setState(() => loading = true);

    try {
      final res = await http.get(
        Uri.parse("$baseUrl/holiday/year/$selectedYear"),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List data = body["data"];

        groupedHolidays.clear();

        for (var h in data) {
          final month = h["month"];
          groupedHolidays.putIfAbsent(month, () => []);
          groupedHolidays[month]!.add(h);
        }

        // sort days inside each month
        groupedHolidays.forEach((_, v) {
          v.sort((a, b) => a["day"].compareTo(b["day"]));
        });
      }
    } catch (_) {}

    setState(() => loading = false);
  }

  Future<void> deleteHoliday(String id) async {
    await http.delete(Uri.parse("$baseUrl/holiday/$id"));
    fetchHolidays();
  }

  Future<void> confirmDeleteHoliday(String id) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text("Confirm Delete"),
          content: const Text(
            "Are you sure you want to delete this holiday?\nThis action cannot be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await deleteHoliday(id);
    }
  }

  Future<void> cloneFromPreviousYear() async {
    final prevYear = selectedYear - 1;

    await http.post(
      Uri.parse("$baseUrl/holiday/clone"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"fromYear": prevYear, "toYear": selectedYear}),
    );

    fetchHolidays();
  }

  // Future<void> updateHoliday(Map<String, dynamic> h) async {
  //   final picked = await showDatePicker(
  //     context: context,
  //     initialDate: DateTime(h["year"], _monthIndex(h["month"]), h["day"]),
  //     firstDate: DateTime(selectedYear, 1, 1),
  //     lastDate: DateTime(selectedYear, 12, 31),
  //   );

  //   if (picked == null) return;

  //   await http.put(
  //     Uri.parse("$baseUrl/holiday/${h["_id"]}"),
  //     headers: {"Content-Type": "application/json"},
  //     body: jsonEncode({
  //       "year": selectedYear,
  //       "month": _monthName(picked.month),
  //       "day": picked.day,
  //       "message": h["message"],
  //       "holidayType": h["holidayType"],
  //     }),
  //   );

  //   fetchHolidays();
  // }

  // ---------------- ADD HOLIDAY DIALOG ----------------

  Future<void> addHolidayDialog() async {
    final TextEditingController messageCtrl = TextEditingController();

    String holidayType = "FLOATING";
    String category = "holiday";
    String state = "TN";

    DateTimeRange selectedRange = DateTimeRange(
      start: DateTime(selectedYear, 1, 1),
      end: DateTime(selectedYear, 1, 1),
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text("Add Holiday"),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Message"),
                    const SizedBox(height: 6),
                    TextField(
                      controller: messageCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text("Holiday Type"),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: holidayType,
                      items: const [
                        DropdownMenuItem(value: "FIXED", child: Text("FIXED")),
                        DropdownMenuItem(
                          value: "FLOATING",
                          child: Text("FLOATING"),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => holidayType = v);
                        }
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text("Date Range"),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: selectedRange,
                          firstDate: DateTime(startYear, 1, 1),
                          lastDate: DateTime(endYear, 12, 31),
                        );

                        if (picked != null) {
                          setDialogState(() => selectedRange = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "${selectedRange.start.day} ${_monthName(selectedRange.start.month)} "
                                "- ${selectedRange.end.day} ${_monthName(selectedRange.end.month)}, "
                                "${selectedRange.end.year}",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    DateTime current = selectedRange.start;
                    while (!current.isAfter(selectedRange.end)) {
                      await http.post(
                        Uri.parse("$baseUrl/holiday"),
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode({
                          "category": category,
                          "holidayType": holidayType,
                          "message": messageCtrl.text.trim(),
                          "month": _monthName(current.month),
                          "day": current.day,
                          "year": current.year,
                          "state": state,
                        }),
                      );
                      current = current.add(const Duration(days: 1));
                    }

                    Navigator.pop(context);
                    fetchHolidays();
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> updateHoliday(Map<String, dynamic> h) async {
    final TextEditingController nameCtrl = TextEditingController(
      text: h["message"],
    );

    String holidayType = h["holidayType"];

    DateTime initialDate = DateTime(h["year"], _monthIndex(h["month"]), h["day"]);

    DateTimeRange selectedRange =
        DateTimeRange(start: initialDate, end: initialDate);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text("Edit Holiday"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Holiday Name
                    const Text("Holiday Name"),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Holiday Type
                    const Text("Holiday Type"),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: holidayType,
                      items: const [
                        DropdownMenuItem(value: "FIXED", child: Text("FIXED")),
                        DropdownMenuItem(
                          value: "FLOATING",
                          child: Text("FLOATING"),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => holidayType = v);
                        }
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Date Range Picker
                    const Text("Date Range"),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: selectedRange,
                          firstDate: DateTime(startYear, 1, 1),
                          lastDate: DateTime(endYear, 12, 31),
                        );

                        if (picked != null) {
                          setDialogState(() => selectedRange = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "${selectedRange.start.day} ${_monthName(selectedRange.start.month)} "
                                "- ${selectedRange.end.day} ${_monthName(selectedRange.end.month)}, "
                                "${selectedRange.end.year}",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // 1. Delete old record
                    await http.delete(Uri.parse("$baseUrl/holiday/${h["_id"]}"));

                    // 2. Create new records for the range
                    DateTime current = selectedRange.start;
                    while (!current.isAfter(selectedRange.end)) {
                      await http.post(
                        Uri.parse("$baseUrl/holiday"),
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode({
                          "category": "holiday",
                          "message": nameCtrl.text.trim(),
                          "holidayType": holidayType,
                          "year": current.year,
                          "month": _monthName(current.month),
                          "day": current.day,
                          "state": h["state"] ?? "TN",
                        }),
                      );
                      current = current.add(const Duration(days: 1));
                    }

                    Navigator.pop(context);
                    fetchHolidays();
                  },
                  child: const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int _monthIndex(String m) => monthOrder.indexOf(m) + 1;
  String _monthName(int i) => monthOrder[i - 1];

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: "Holiday Master",
      // return Scaffold(
      //   backgroundColor: const Color(0xFFF4F6FA),
      //   appBar: AppBar(
      //     title: const Text("Holiday Master"),
      //     backgroundColor: Colors.indigo,
      //   ),
      body: Column(
        children: [
          _headerBar(),
          //  _yearSelector(),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _list(),
          ),
        ],
      ),
    );
  }

  Widget _headerBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text(
            "Holidays",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          DropdownButton<int>(
            value: selectedYear,
            underline: const SizedBox(),
            items: List.generate(endYear - startYear + 1, (i) {
              final y = startYear + i;
              return DropdownMenuItem(value: y, child: Text(y.toString()));
            }),
            onChanged: (v) {
              if (v == null) return;
              setState(() => selectedYear = v);
              fetchHolidays();
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.indigo),
            onPressed: addHolidayDialog,
          ),
        ],
      ),
    );
  }

  // Widget _yearSelector() {
  //   return Container(
  //     margin: const EdgeInsets.all(16),
  //     padding: const EdgeInsets.symmetric(horizontal: 16),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: DropdownButton<int>(
  //       value: selectedYear,
  //       underline: const SizedBox(),
  //       isExpanded: true,
  //       items: List.generate(endYear - startYear + 1, (i) {
  //         final y = startYear + i;
  //         return DropdownMenuItem(value: y, child: Text(y.toString()));
  //       }),
  //       onChanged: (v) {
  //         if (v == null) return;
  //         setState(() => selectedYear = v);
  //         fetchHolidays();
  //       },
  //     ),
  //   );
  // }

  Widget _list() {
    if (groupedHolidays.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "No holiday records found",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text("Clone from Previous Year"),
            onPressed: cloneFromPreviousYear,
          ),
        ],
      );
    }

    /// 🔴 SORT MONTHS HERE
    final sortedMonths = groupedHolidays.keys.toList()
      ..sort((a, b) => monthOrder.indexOf(a).compareTo(monthOrder.indexOf(b)));

    // return ListView(
    //   padding: const EdgeInsets.all(16),
    //   children: sortedMonths.map((month) {
    // return Scrollbar(
    //   controller: _scrollController,
    //   thumbVisibility: true,
    //   thickness: 6,
    //   radius: const Radius.circular(10),
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(10),
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: sortedMonths.map((month) {
            final holidays = groupedHolidays[month]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text(
                //   month,
                //   style: const TextStyle(
                //     fontSize: 18,
                //     fontWeight: FontWeight.bold,
                //     color: Colors.white,),
                // ),
                Text(
                  month,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                ...holidays.map(_holidayTile),
                const SizedBox(height: 24),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _holidayTile(Map<String, dynamic> h) {
    final isFixed = h["holidayType"] == "FIXED";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isFixed ? Icons.verified : Icons.event_available,
            color: isFixed ? Colors.grey : Colors.indigo,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h["message"],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${h["day"]} ${h["month"]}, ${h["year"]}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: isFixed ? null : () => updateHoliday(h),
          ),
          // IconButton(
          //  // icon: const Icon(Icons.delete, color: Colors.red),
          //   icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          //   onPressed: () => deleteHoliday(h["_id"]),
          // ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => confirmDeleteHoliday(h["_id"]),
          ),
        ],
      ),
    );
  }
}