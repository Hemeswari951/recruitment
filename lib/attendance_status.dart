// attendance_status.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'sidebar.dart';
import 'package:zeai_project/admin_dashboard.dart';
import 'package:zeai_project/employee_dashboard.dart';
import 'package:zeai_project/superadmin_dashboard.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <<-- added
import 'notifications_helper.dart'; // <<-- NOTIFICATIONS HELPER IMPORT (A)

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // basic states
  bool isLoginDisabled = false;
  bool isLogoutDisabled = true;
  bool isBreakActive = false;
  bool attendanceSubmitted = false;
  bool isLoginReasonSubmitted = false;
  bool isLogoutReasonSubmitted = false;

  String loginTime = "";
  String logoutTime = "";
  String breakStart = ""; // string time from server or local
  String breakEnd = "";
  String loginReason = "";
  String logoutReason = "";

  List<Map<String, String>> attendanceData = [];

  final loginReasonController = TextEditingController();
  final logoutReasonController = TextEditingController();

  Timer? monitorTimer; // 15s server poll

  // server accumulated minutes from previous segments (not including current ongoing segment)
  int serverAccumulatedMinutes = 0;

  // saved messenger to avoid ancestor lookups during dispose()
  late ScaffoldMessengerState _scaffoldMessenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // safe to look up ancestor here — widget is active
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void initState() {
    super.initState();
    fetchLatestStatus();
    fetchAttendanceHistory();
    startBreakAndTotalMonitor();
  }

  @override
  void dispose() {
    monitorTimer?.cancel();
    loginReasonController.dispose();
    logoutReasonController.dispose();
    // clear any banners using the saved messenger (safe)
    try {
      _scaffoldMessenger.clearMaterialBanners();
    } catch (_) {}
    super.dispose();
  }

  String getCurrentTime() => DateFormat('hh:mm:ss a').format(DateTime.now());
  String getCurrentDate() => DateFormat('dd-MM-yyyy').format(DateTime.now());

  /// Fetch today's attendance record & restore UI state.
  Future<void> fetchLatestStatus() async {
    final employeeId = Provider.of<UserProvider>(context, listen: false).employeeId ?? '';
    var url = Uri.parse('https://company-04bz.onrender.com/attendance/attendance/status/$employeeId');

    try {
      var response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final todayDate = getCurrentDate();

        // New day or no record -> reset UI (and reset alerts)
        if (data['date'] != todayDate) {
          setState(() {
            isBreakActive = false;
            isLoginDisabled = false;
            isLogoutDisabled = true;
            loginTime = "";
            logoutTime = "";
            loginReason = "";
            logoutReason = "";
            breakStart = "";
            serverAccumulatedMinutes = 0;
          });
          // clear banners if any
          if (context.mounted) ScaffoldMessenger.of(context).clearMaterialBanners();
          return;
        }

        setState(() {
          loginTime = data['loginTime'] ?? "";
          logoutTime = data['logoutTime'] ?? "";
          loginReason = data['loginReason'] ?? "";
          logoutReason = data['logoutReason'] ?? "";

          // update controllers
          loginReasonController.text = loginReason;
          logoutReasonController.text = logoutReason;

          isLoginReasonSubmitted = loginReason.isNotEmpty && loginReason != "-";
          isLogoutReasonSubmitted = logoutReason.isNotEmpty && logoutReason != "-";

          // hide login button after login
          isLoginDisabled = data['status'] == "Login" || data['status'] == "Break";
          isLogoutDisabled = data['status'] == "Logout" || data['status'] == "None";
        });

        // restore server-accumulated total (parse Total: X mins)
        final breakTimeStr = data['breakTime'] ?? '-';
        int serverTotal = 0;
        final match = RegExp(r'\(Total:\s*(\d+)\s*mins\)').firstMatch(breakTimeStr);
        if (match != null) serverTotal = int.parse(match.group(1)!);

        // >>> HIGHLIGHT: keep serverAccumulatedMinutes in sync here (B)
        // This value is used to compute scheduling offsets for notifications
        serverAccumulatedMinutes = serverTotal;

        // restore break state from server
        if (data['breakInProgress'] != null && data['status'] == "Break") {
          setState(() {
            isBreakActive = true;
            breakStart = data['breakInProgress'];
            // DO NOT start a per-second setState in the parent anymore.
            // BreakTimerDisplay will handle local per-second counting and alarms.
          });
        } else {
          // not on break
          setState(() {
            isBreakActive = false;
            breakStart = "";
            // clear banners
            if (context.mounted) ScaffoldMessenger.of(context).clearMaterialBanners();
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching status: $e');
    }
  }

  /// Combined monitor that polls server every 15s to:
  /// - read stored total (Total: X mins) into serverAccumulatedMinutes
  /// - read breakInProgress (server start) to keep UI in sync
  void startBreakAndTotalMonitor() {
    // cancel any existing monitor
    monitorTimer?.cancel();
    monitorTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final employeeId = Provider.of<UserProvider>(context, listen: false).employeeId ?? '';
        final url = Uri.parse('https://company-04bz.onrender.com/attendance/attendance/status/$employeeId');
        final response = await http.get(url);
        if (response.statusCode != 200) return;
        final data = jsonDecode(response.body);

        final breakTimeStr = data['breakTime'] ?? '-';
        int serverTotal = 0;
        final match = RegExp(r'\(Total:\s*(\d+)\s*mins\)').firstMatch(breakTimeStr);
        if (match != null) serverTotal = int.parse(match.group(1)!);

        // >>> HIGHLIGHT: update serverAccumulatedMinutes used by BreakTimerDisplay thresholds (B)
        setState(() {
          serverAccumulatedMinutes = serverTotal;
        });

        // If server indicates break in progress, ensure local state matches (BreakTimerDisplay will pick this up via props)
        if (data['status'] == "Break" && data['breakInProgress'] != null) {
          final serverBreakStart = data['breakInProgress'] ?? '';
          // re-sync UI state if necessary
          setState(() {
            isBreakActive = true;
            breakStart = serverBreakStart;
          });
        } else {
          // server says not on break -> ensure parent state reflects this
          if (isBreakActive) {
            setState(() {
              isBreakActive = false;
              breakStart = "";
            });
            // clear any banner
            if (context.mounted) ScaffoldMessenger.of(context).clearMaterialBanners();
          } else {
            setState(() {
              isBreakActive = false;
            });
          }
        }
      } catch (e) {
        print('❌ Error in monitor: $e');
      }
    });
  }

  // POST new login (unchanged)
  Future<void> postAttendanceData() async {
    final employeeId = Provider.of<UserProvider>(context, listen: false).employeeId ?? '';
    var url = Uri.parse('https://company-04bz.onrender.com/attendance/attendance/mark/$employeeId');

    var body = {
      'date': getCurrentDate(),
      'loginTime': loginTime,
      'breakTime': (breakStart.isNotEmpty && breakEnd.isNotEmpty) ? "$breakStart to $breakEnd" : "-",
      'loginReason': loginReason,
      'logoutReason': logoutReason,
      'status': "Login",
    };

    try {
      var response = await http.post(url, body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 201) {
        attendanceSubmitted = true;
        fetchAttendanceHistory();
      }
    } catch (e) {
      print('❌ Exception: $e');
    }
  }

  // PUT update (logout/break) general (unchanged)
  Future<void> updateAttendanceData({bool isLogout = false}) async {
    final employeeId = Provider.of<UserProvider>(context, listen: false).employeeId ?? '';
    var url = Uri.parse('https://company-04bz.onrender.com/attendance/attendance/update/$employeeId');

    var body = {
      'date': getCurrentDate(),
      'loginTime': loginTime,
      'breakTime': (breakStart.isNotEmpty && breakEnd.isNotEmpty) ? "$breakStart to $breakEnd" : "-",
      'loginReason': loginReason,
      'logoutReason': logoutReason,
      'status': isLogout ? "Logout" : "Login",
    };

    if (isLogout) body['logoutTime'] = logoutTime;

    try {
      var response = await http.put(url, body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 200) {
        await fetchAttendanceHistory();
      }
    } catch (e) {
      print('❌ Exception during update: $e');
    }
  }

  // fetch last 5 records — history UI shows overtime if > 60
  // changed: display only last break segment per-day (user request)
  Future<void> fetchAttendanceHistory() async {
    try {
      final employeeId = Provider.of<UserProvider>(context, listen: false).employeeId ?? '';
      var url = Uri.parse('https://company-04bz.onrender.com/attendance/attendance/history/$employeeId');
      var response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          attendanceData = data.take(5).map<Map<String, String>>((item) {
            String breakTime = item['breakTime'] ?? '-';
            String displayBreak = "-";
            int total = 0;
            final m = RegExp(r'\(Total:\s*(\d+)\s*mins\)').firstMatch(breakTime);
            if (m != null) {
              total = int.parse(m.group(1)!);
            }

            // extract last break segment only (if breaks exist)
            if (breakTime != "-" && breakTime.trim().isNotEmpty) {
              final withoutTotal = breakTime.replaceAll(RegExp(r'\(Total:.*\)'), '').trim();
              final segments = withoutTotal.split(',').map((s) => s.trim()).where((s) => s.contains('to')).toList();
              if (segments.isNotEmpty) {
                displayBreak = segments.last;
                if (total > 0) {
                  displayBreak = "$displayBreak  • Total: $total mins";
                  if (total > 60) {
                    final overtime = total - 60;
                    displayBreak = "$displayBreak  • Overtime: $overtime mins";
                  }
                }
              } else {
                displayBreak = breakTime;
              }
            } else {
              displayBreak = "-";
            }

            return {
              'date': item['date'] ?? '',
              'status': item['status'] ?? '-',
              'break': displayBreak,
              'login': item['loginTime'] ?? '',
              'logout': item['logoutTime'] ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      print('❌ Error fetching history: $e');
    }
  }

  // Reason dialogs (kept from original)
  Future<bool> showLoginReasonDialog() async {
    final originalReason = loginReasonController.text;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Reason for Early/Late Login"),
          content: TextField(controller: loginReasonController, decoration: const InputDecoration(hintText: "Enter reason")),
          actions: [
            TextButton(onPressed: () {
              if (loginReasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠ Please enter a reason before submitting."), backgroundColor: Colors.orange));
                return;
              }
              loginReason = loginReasonController.text.trim();
              isLoginReasonSubmitted = true;
              Navigator.of(context).pop(true);
            }, child: const Text("Submit")),
            TextButton(onPressed: () { loginReasonController.text = originalReason; Navigator.of(context).pop(false); }, child: const Text("Cancel")),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<bool> showLogoutReasonDialog() async {
    final originalReason = logoutReasonController.text;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Reason for Early/Late Logout"),
          content: TextField(controller: logoutReasonController, decoration: const InputDecoration(hintText: "Enter reason")),
          actions: [
            TextButton(onPressed: () {
              if (logoutReasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠ Please enter a reason before submitting."), backgroundColor: Colors.orange));
                return;
              }
              logoutReason = logoutReasonController.text.trim();
              isLogoutReasonSubmitted = true;
              Navigator.of(context).pop(true);
            }, child: const Text("Submit")),
            TextButton(onPressed: () { logoutReasonController.text = originalReason; Navigator.of(context).pop(false); }, child: const Text("Cancel")),
          ],
        );
      },
    );
    return result ?? false;
  }

  void showAlreadyLoggedOutDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Already Logged Out"), content: const Text("You have already logged off this day."), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }

  // Login handler (kept)
  void handleLogin() async {
    if (logoutTime.isNotEmpty) {
      showAlreadyLoggedOutDialog();
      return;
    }
    DateTime now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day, 08, 55);
    DateTime end = DateTime(now.year, now.month, now.day, 09, 05);
    if (now.isBefore(start) || now.isAfter(end)) {
      bool submitted = await showLoginReasonDialog();
      if (!submitted) return;
    }
    String timeNow = getCurrentTime();
    setState(() {
      loginTime = timeNow;
      isLoginDisabled = true; // hide login (we check this in build)
      isLogoutDisabled = false;
      loginReason = loginReasonController.text.trim();
    });
    await postAttendanceData();
    setState(() {
      loginReasonController.text = loginReason;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Logged in successfully!"), backgroundColor: Colors.green));
  }

  // Break handler uses a same-sized ElevatedButton toggle
  void handleBreak() async {
    final employeeId = Provider.of<UserProvider>(context, listen: false).employeeId ?? '';
    if (logoutTime.isNotEmpty) { showAlreadyLoggedOutDialog(); return; }
    final currentTime = getCurrentTime();

    if (!isBreakActive) {

  if (serverAccumulatedMinutes >= 60 && !isBreakActive) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Break limit reached for today."),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
      // optimistic UI update: show break start immediately
      setState(() {
        breakStart = currentTime;
        isBreakActive = true;
      });

      try {
        var url = Uri.parse('https://company-04bz.onrender.com/attendance/attendance/update/$employeeId');
        var body = jsonEncode({'date': getCurrentDate(), 'breakTime': currentTime, 'breakStatus': 'BreakIn', 'status': 'Break'});
        var response = await http.put(url, body: body, headers: {'Content-Type': 'application/json'});

        // fetch status to sync server time (server sets breakInProgress to server timestamp and serverAccumulatedMinutes)
        await fetchLatestStatus();

        // >>> HIGHLIGHT: schedule local notifications for 58/60 minute warnings (C)
        // (scheduling here uses serverAccumulatedMinutes set by fetchLatestStatus above)
        try {
          final empId = Provider.of<UserProvider>(context, listen: false).employeeId ?? 'emp_default';

          // compute elapsed minutes from breakStart (breakStart is a string "hh:mm:ss a")
          DateTime parsedStart;
          try {
            final parsed = DateFormat('hh:mm:ss a').parse(breakStart);
            final now = DateTime.now();
            parsedStart = DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute, parsed.second);
          } catch (_) {
            parsedStart = DateTime.now();
          }

          final elapsedMinutes = DateTime.now().difference(parsedStart).inMinutes;
          final currentTotal = serverAccumulatedMinutes + elapsedMinutes;

          final rem58 = 58 - currentTotal;
          final rem60 = 60 - currentTotal;

          // Schedule 58-min warning if needed
          if (rem58 > 0) {
            await NotificationHelper.schedule(
              'break58_$empId', // id
              minutesFromNow: rem58,
              title: '2 minutes left',
              body: 'You have used $currentTotal minutes of break. 2 minutes remaining.',
              soundFileName: 'warning.mp3',
              payload: 'attendance:open',
            );
          }

          // Schedule 60-min alarm if needed
          if (rem60 > 0) {
            await NotificationHelper.schedule(
              'break60_$empId', // id
              minutesFromNow: rem60,
              title: 'Break limit reached',
              body: 'Your break has reached 60 minutes. Please end break.',
              soundFileName: 'alarm.mp3',
              payload: 'attendance:open',
            );
          }
        } catch (notifyErr) {
          print('⚠ Notification scheduling failed: $notifyErr');
        }

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("⏸ Break started"), backgroundColor: Colors.orange));
        } else {
          final data = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? "Break started"), backgroundColor: Colors.orange));
        }
      } catch (e) {
        print('❌ Error starting break: $e');
      }
    } else {
      // end break
      await endBreak(employeeId, currentTime);
    }
  }

  // End break — backend will compute full total (may be >60) and return overtimeMinutes
  Future<void> endBreak(String employeeId, String currentTime) async {
    // >>> HIGHLIGHT: cancel any scheduled break notifications when break ends (D)
    try {
      final empId = Provider.of<UserProvider>(context, listen: false).employeeId ?? 'emp_default';
      await NotificationHelper.cancelBreakNotifications(empId);
    } catch (cancelErr) {
      print('⚠ Notification cancel failed: $cancelErr');
    }

    setState(() {
      breakEnd = currentTime;
      isBreakActive = false;
    });

    try {
      var url = Uri.parse('https://company-04bz.onrender.com/attendance/attendance/update/$employeeId');
      var body = jsonEncode({'date': getCurrentDate(), 'breakTime': breakEnd, 'breakStatus': 'BreakOff', 'status': 'Login'});
      var response = await http.put(url, body: body, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['overtimeMinutes'] != null && data['overtimeMinutes'] > 0) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("⏰ Break ended. Overtime: ${data['overtimeMinutes']} mins"), backgroundColor: Colors.deepOrange));
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("▶ Break ended at $breakEnd"), backgroundColor: Colors.green));
          }
        }
        // sync server state and refresh history
        await fetchLatestStatus();
        await fetchAttendanceHistory();
        // clear any banner shown for 60-min alarm
        if (context.mounted) ScaffoldMessenger.of(context).clearMaterialBanners();
      } else {
        // handle server messages (if any)
        final data = jsonDecode(response.body);
        if (data != null && data['message'] != null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.orange));
          }
        }
      }
    } catch (e) {
      print('❌ Error ending break: $e');
    }
  }

  void handleLogout() async {
    if (logoutTime.isNotEmpty) { showAlreadyLoggedOutDialog(); return; }
    DateTime now = DateTime.now();
    DateTime logoutStart = DateTime(now.year, now.month, now.day, 18, 00);
    DateTime logoutEnd = DateTime(now.year, now.month, now.day, 18, 10);
    if (now.isBefore(logoutStart) || now.isAfter(logoutEnd)) {
      bool reasonSubmitted = await showLogoutReasonDialog();
      if (!reasonSubmitted) return;
    }
    String timeNow = getCurrentTime();
    setState(() {
      logoutTime = timeNow;
      isLogoutDisabled = true;
      isLoginDisabled = true;
      isBreakActive = false;
      loginReason = loginReasonController.text.trim();
      logoutReason = logoutReasonController.text.trim();
    });

    if (attendanceSubmitted) {
      await updateAttendanceData(isLogout: true);
    } else {
      await postAttendanceData();
      await updateAttendanceData(isLogout: true);
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Logged out successfully!"), backgroundColor: Colors.green));
  }

  String _formatSecondsToMMSS(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  // common button style so LOGIN / BREAK / LOGOUT match (reduced size)
  ButtonStyle _mainButtonStyle(Color color) => ElevatedButton.styleFrom(
    backgroundColor: color,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    minimumSize: const Size(150, 44),
    elevation: 6,
  );

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: 'Attendance Logs',
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            const SizedBox(height: 6),

            // Top action area: three columns (login above left reason, break center, logout above right reason)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: Login + reason
                  Expanded(
                    child: Column(
                      children: [
                        // login button (disappears after login; keep space via SizedBox to align)
                        if (!isLoginDisabled)
                          ElevatedButton.icon(
                            onPressed: !isLoginDisabled ? handleLogin : null,
                            icon: const Icon(Icons.login, size: 18),
                            label: const Text("LOGIN"),
                            style: _mainButtonStyle(Colors.green),
                          )
                        else
                          const SizedBox(height: 44), // keep space so center stays aligned

                        const SizedBox(height: 10),
                        // reason box beneath login
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 320),
                          height: 80,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                          child: IgnorePointer(
                            child: TextField(
                              controller: loginReasonController,
                              readOnly: true,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: const InputDecoration(labelText: "Reason for Early/Late Login 👋", border: OutlineInputBorder()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // CENTER: BreakTimerDisplay + Break toggle (switch remains in parent)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Replace the per-second animated text with the BreakTimerDisplay widget
                        BreakTimerDisplay(
                          serverAccumulatedMinutes: serverAccumulatedMinutes,
                          serverBreakStart: breakStart,
                          isBreakActive: isBreakActive,
                          // pass the parent's handler so 60-minute popup End Break can call it
                          onEndBreakRequested: () {
                            // call parent end-break flow (when called, handleBreak will detect isBreakActive and end)
                            handleBreak();
                          },
                        ),

                        const SizedBox(height: 12),

                        // Break toggle - large switch (toggle behavior)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Break:", style: TextStyle(color: Colors.white70)),
                            const SizedBox(width: 8),
                            Transform.scale(
                              scale: 1.25,
                              child: Switch.adaptive(
                                value: isBreakActive,
                                activeColor: Colors.orange,
                                onChanged: serverAccumulatedMinutes >= 60 ? null: (val) {
                                  // same handler as the button version, but now triggered by the toggle
                                  // if user toggles on -> start break; toggles off -> end break
                                  handleBreak();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(isBreakActive ? "ON" : "OFF", style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // RIGHT: Logout + reason
                  Expanded(
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: !isLogoutDisabled ? handleLogout : null,
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text("LOGOUT"),
                          style: _mainButtonStyle(Colors.red),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 320),
                          height: 80,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                          child: IgnorePointer(
                            child: TextField(
                              controller: logoutReasonController,
                              readOnly: true,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: const InputDecoration(labelText: "Reason for Early/Late Logout 👋", border: OutlineInputBorder()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Attendance table - compact modern card style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Card(
                elevation: 6,
                color: Colors.grey[850],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      dataRowHeight: 44,
                      headingRowHeight: 48,
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade700),
                      dataRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                      columns: const [
                        DataColumn(label: Text('Date', style: TextStyle(color: Colors.white, fontSize: 14))),
                        DataColumn(label: Text('Status', style: TextStyle(color: Colors.white, fontSize: 14))),
                        DataColumn(label: Text('Break', style: TextStyle(color: Colors.white, fontSize: 14))),
                        DataColumn(label: Text('Login', style: TextStyle(color: Colors.white, fontSize: 14))),
                        DataColumn(label: Text('Logout', style: TextStyle(color: Colors.white, fontSize: 14))),
                      ],
                      rows: attendanceData.map((data) {
                        final status = data['status'] ?? '-';
                        final breakCell = data['break'] ?? '-';
                        final isOvertime = (breakCell.contains("Overtime:"));
                        return DataRow(cells: [
                          DataCell(Text(data['date'] ?? '', style: const TextStyle(fontSize: 13))),
                          DataCell(Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: status == "Login" ? Colors.green : Colors.red, fontSize: 13))),
                          // aligned as plain text now (fixes vertical offset)
                          DataCell(Text(breakCell, style: TextStyle(color: isOvertime ? Colors.redAccent : Colors.black, fontSize: 13))),
                          DataCell(Text(data['login'] ?? '', style: const TextStyle(fontSize: 13))),
                          DataCell(Text(data['logout'] ?? '', style: const TextStyle(fontSize: 13))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // smaller back to dashboard button
            ElevatedButton(
              onPressed: () {
                final userProvider = Provider.of<UserProvider>(context, listen: false);
                final position = userProvider.position?.trim() ?? "";
                Widget dashboard;
                if (position == "TL") {
                  dashboard = const AdminDashboard();
                } else if (position == "Founder" || position == "HR") {
                  dashboard = const SuperAdminDashboard();
                } else {
                  dashboard = const EmployeeDashboard();
                }
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => dashboard), (route) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                minimumSize: const Size(160, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text("Back to Dashboard", style: TextStyle(color: Colors.white, fontSize: 14)),
            ),

            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// BreakTimerDisplay widget — isolates per-second updates, dialogs, and audio.
/// - serverAccumulatedMinutes (int)
/// - serverBreakStart (String like "05:12:05 PM")
/// - isBreakActive (bool)
/// - onEndBreakRequested: callback to ask parent to end break (used for 60-min popup)
/// ---------------------------------------------------------------------------
class BreakTimerDisplay extends StatefulWidget {
  /// serverAccumulatedMinutes comes from server (previous break segments)
  final int serverAccumulatedMinutes;
  /// server break start string like "05:12:05 PM" (empty if starting now)
  final String serverBreakStart;
  /// whether break is currently active
  final bool isBreakActive;
  /// callback parent -> end break
  final VoidCallback? onEndBreakRequested;

  const BreakTimerDisplay({
    super.key,
    required this.serverAccumulatedMinutes,
    required this.serverBreakStart,
    required this.isBreakActive,
    this.onEndBreakRequested,
  });

  @override
  State<BreakTimerDisplay> createState() => _BreakTimerDisplayState();
}

class _BreakTimerDisplayState extends State<BreakTimerDisplay> {
  Timer? _timer;
  int _elapsedSeconds = 0; // current ongoing segment seconds
  Color _timerColor = Colors.lightBlueAccent;
  final AudioPlayer _player = AudioPlayer();
  late ScaffoldMessengerState _scaffoldMessenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  DateTime _computeBreakStartDateTime(String serverTimeStr) {
    try {
      final parsed = DateFormat('hh:mm:ss a').parse(serverTimeStr);
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute, parsed.second);
    } catch (e) {
      return DateTime.now();
    }
  }

  void _startTimerFrom(String serverBreakStart) {
    _timer?.cancel();
    _elapsedSeconds = 0;
    DateTime start = serverBreakStart.isNotEmpty ? _computeBreakStartDateTime(serverBreakStart) : DateTime.now();

    // If server start is in past, compute initial elapsed
    final now = DateTime.now();
    if (start.isBefore(now)) {
      _elapsedSeconds = now.difference(start).inSeconds;
    }

    // run every second and update only this widget
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
      _checkThresholdsAndNotify();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _elapsedSeconds = 0;
    setState(() => _timerColor = Colors.lightBlueAccent);
  }

  Future<void> _checkThresholdsAndNotify() async {
    if (!mounted) return;
    final realtimeTotalMinutes = widget.serverAccumulatedMinutes + (_elapsedSeconds ~/ 60);

    // update color
    if (!mounted) return;

setState(() {
  if (realtimeTotalMinutes >= 60) {
    _timerColor = Colors.redAccent;
  } else if (realtimeTotalMinutes >= 58) {
    _timerColor = Colors.orangeAccent;
  } else {
    _timerColor = Colors.lightBlueAccent;
  }
});

    // Use per-employee per-day SharedPreferences flags so these popups fire only once per day
    final prefs = await SharedPreferences.getInstance();
    final empId = Provider.of<UserProvider>(context, listen: false).employeeId ?? 'default';
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final key58 = 'break58_$empId';
    final key60 = 'break60_$empId';

    // 58-min warning: one-shot popup + one-shot sound, only once per day
    if (realtimeTotalMinutes >= 58) {
      final last58 = prefs.getString(key58) ?? '';
      if (last58 != todayKey) {
        // mark shown now
        await prefs.setString(key58, todayKey);

        // play one-shot short sound
        try {
          await _player.stop(); // stop any current
          await _player.setReleaseMode(ReleaseMode.stop);
          await _player.play(AssetSource('sounds/warning.mp3'));
        } catch (_) {}

        if (mounted) {
          // show a simple dialog (visible popup)
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) {
              return AlertDialog(
                title: const Text("2 minutes left"),
                content: Text("⚠ You've used $realtimeTotalMinutes minutes of break. 2 minutes remaining before final warning."),
                actions: [
                  TextButton(onPressed: () {
                    Navigator.of(ctx).pop();
                  }, child: const Text("OK")),
                ],
              );
            },
          );
        }
      }
    }

    // 60-min final warning: one-shot popup + one-shot sound, only once per day.
    if (realtimeTotalMinutes >= 60) {
      final last60 = prefs.getString(key60) ?? '';
      if (last60 != todayKey) {
        await prefs.setString(key60, todayKey);
        // 🔥 STOP TIMER BEFORE SHOWING DIALOG
    _timer?.cancel();

        // play one-shot alarm sound (non-looping)
        try {
          await _player.stop();
          await _player.setReleaseMode(ReleaseMode.stop);
          await _player.play(AssetSource('sounds/alarm.mp3'));
        } catch (_) {}

        if (mounted) {
          // Show a dialog with a single button "End Break" that invokes parent's end-break flow.
          showDialog(
            context: context,
            barrierDismissible: false, // user must press End Break
            builder: (ctx) {
              return AlertDialog(
                title: const Text("⏰ Break Limit Reached"),
                content: const Text("Your total break time for today has reached 60 minutes. Press End Break to stop the break and record overtime."),
                actions: [
                  TextButton(
                    onPressed: () {
                      // stop sound (one-shot already), close dialog, and request parent to end break
                      try { _player.stop(); } catch (_) {}
                      Navigator.of(ctx).pop();
                      if (widget.onEndBreakRequested != null) {
                        widget.onEndBreakRequested!();
                      }
                    },
                    child: const Text("End Break"),
                  ),
                ],
              );
            },
          );
        }
      }
    }

    // ensure UI updated
    // if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.isBreakActive) _startTimerFrom(widget.serverBreakStart);
  }

  @override
  void didUpdateWidget(covariant BreakTimerDisplay old) {
    super.didUpdateWidget(old);
    // if break activated or server start changed -> start
    if (widget.isBreakActive && !old.isBreakActive) {
      _startTimerFrom(widget.serverBreakStart);
    } else if (!widget.isBreakActive && old.isBreakActive) {
      _stopTimer();
      // stop any sound and clear dialogs/banners if needed
      try { _player.stop(); } catch (_) {}
      // try clearing material banners safely
      try { _scaffoldMessenger.clearMaterialBanners(); } catch (_) {}
    } else if (widget.serverAccumulatedMinutes != old.serverAccumulatedMinutes) {
      // server total changed — thresholds should be re-evaluated
      _checkThresholdsAndNotify();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    try { _player.stop(); _player.dispose(); } catch (_) {}
    // clear banners safely via saved messenger
    try {
      _scaffoldMessenger.clearMaterialBanners();
    } catch (_) {}
    super.dispose();
  }

  String _formatSecondsToMMSS(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  @override
Widget build(BuildContext context) {
  final totalMinutes =
      widget.serverAccumulatedMinutes + (_elapsedSeconds ~/ 60);

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        "Total Break: $totalMinutes mins",
        style: TextStyle(
          color: _timerColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}
}