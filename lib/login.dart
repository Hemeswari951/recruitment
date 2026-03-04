// login.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zeai_project/admin_dashboard.dart' as admin;
import 'package:zeai_project/employee_dashboard.dart' as employee;
import 'package:zeai_project/superadmin_dashboard.dart' as superadmin;

import 'user_provider.dart';

class LoginApp extends StatelessWidget {
  const LoginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginPage();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// ✅ Save login session function
Future<void> saveLoginSession(
  String employeeId,
  String employeeName,
  String position,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('employeeId', employeeId);
  await prefs.setString('employeeName', employeeName);
  await prefs.setString('position', position);
  print('>> saved session: id="$employeeId" name="$employeeName" position="$position"');
  print('>> SAVED: id="$employeeId" name="$employeeName" position="$position"');
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController employeeIdController = TextEditingController();
  final TextEditingController employeeNameController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode _employeeIdFocusNode = FocusNode();
  final FocusNode _employeeNameFocusNode = FocusNode();
  final FocusNode _positionFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool isLoading = false;
  bool _isFetchingDetails = false;

  // remember password toggle
  bool rememberPassword = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _employeeIdFocusNode.addListener(_onEmployeeIdFocusChange);
  }

  // Load saved credentials (employeeId, employeeName, position, optional savedPassword & remember flag)
  // Future<void> _loadSavedCredentials() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final savedId = prefs.getString('employeeId');
  //   final savedName = prefs.getString('employeeName');
  //   final savedPosition = prefs.getString('position');
  //   print('>> prefs loaded: id=${prefs.getString('employeeId')}, name=${prefs.getString('employeeName')}, position=$savedPosition');
  //   final savedPass = prefs.getString('savedPassword');
  //   final rem = prefs.getBool('rememberPassword') ?? false;

  //   setState(() {
  //     if (savedId != null && savedId.isNotEmpty) {
  //       employeeIdController.text = savedId;
  //     }
  //     if (savedName != null && savedName.isNotEmpty) {
  //       employeeNameController.text = savedName;
  //     }
  //     if (savedPosition != null && savedPosition.isNotEmpty) {
  //       positionController.text = savedPosition;
  //     }
  //     rememberPassword = rem;
  //     if (rememberPassword && savedPass != null && savedPass.isNotEmpty) {
  //       passwordController.text = savedPass;
  //     }
  //   });
  // }

  Future<void> _loadSavedCredentials() async {
  final prefs = await SharedPreferences.getInstance();
  final savedId = prefs.getString('employeeId') ?? '';
  final savedName = prefs.getString('employeeName') ?? '';
  final savedPosition = prefs.getString('position') ?? '';
  final savedPass = prefs.getString('savedPassword') ?? '';
  final rem = prefs.getBool('rememberPassword') ?? false;

  // debug: show what was read from prefs
  print('>> prefs: id="$savedId", name="$savedName", position="$savedPosition", remember=$rem');

  // assign AFTER first frame to avoid platform autofill or other races
  WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;

  // small delay to ensure browser autofill finished painting
  Future.delayed(const Duration(milliseconds: 200), () {
    if (!mounted) return;
    setState(() {
      employeeIdController.text = savedId;
      employeeNameController.text = savedName;
      positionController.text = savedPosition;
      rememberPassword = rem;
      if (rememberPassword && savedPass.isNotEmpty) {
        passwordController.text = savedPass;
      }
    });

    print('>> controllers set (delayed): id="${employeeIdController.text}", name="${employeeNameController.text}", position="${positionController.text}"');
  });
});
}



  // Save or remove the saved password depending on remember flag
  Future<void> _updateSavedPasswordPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberPassword', rememberPassword);
    if (rememberPassword) {
      await prefs.setString('savedPassword', passwordController.text.trim());
    } else {
      await prefs.remove('savedPassword');
    }
  }

  void _onEmployeeIdFocusChange() {
    // When the user moves focus away from the Employee ID field,
    // trigger fetching the details.
    if (!_employeeIdFocusNode.hasFocus) {
      _fetchEmployeeDetails();
    }
  }

  Future<void> _fetchEmployeeDetails() async {
    final employeeId = employeeIdController.text.trim();
    if (employeeId.isEmpty) {
      // Clear other fields if ID is cleared
      setState(() {
        employeeNameController.clear();
        positionController.clear();
      });
      return;
    }

    setState(() {
      _isFetchingDetails = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://company-04bz.onrender.com/get-employee-name/$employeeId'),
      );

      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          employeeNameController.text = data['employeeName'] ?? '';
          positionController.text = data['position'] ?? '';
        });
      } else if (mounted) {
        // If employee not found or error, clear the fields
        setState(() {
          employeeNameController.clear();
          positionController.clear();
        });
      }
    } catch (e) {
      print('❌ Error fetching employee details: $e');
    } finally {
      if (mounted) {
        setState(() => _isFetchingDetails = false);
      }
    }
  }

  Future<void> sendLoginDetails() async {
    if (employeeIdController.text.isEmpty ||
        employeeNameController.text.isEmpty ||
        positionController.text.isEmpty ||
        passwordController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Missing Details"),
          content: const Text("Please fill all fields."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
          'https://company-04bz.onrender.com/api/employee-login',
        ), // change your render url here!
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'employeeId': employeeIdController.text.trim(),
          'employeeName': employeeNameController.text.trim(),
          'position': positionController.text.trim(),
          'password': passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        print('✅ Login Successful');
        final position = positionController.text.trim();

        // ✅ Save session
        await saveLoginSession(
          employeeIdController.text.trim(),
          employeeNameController.text.trim(),
          positionController.text.trim(),
        );

        // Save or remove saved password preference
        await _updateSavedPasswordPreference();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          userProvider.setEmployeeId(employeeIdController.text.trim());
          userProvider.setEmployeeName(employeeNameController.text.trim());
          userProvider.setPosition(positionController.text.trim());

          // ✅ Navigate after provider is updated
          if (position == "TL") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const admin.AdminDashboard(),
              ),
            );
          } else if (position == "Founder" || position == "HR") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const superadmin.SuperAdminDashboard(),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const employee.EmployeeDashboard(),
              ),
            );
          }
        });
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Invalid Credentials ❌"),
            content: const Text(
              "Please check your Employee ID, Name, Position or Password.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Server Error"),
            content: Text("Status Code: ${response.statusCode}"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ Network Error: $e');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Network Error"),
          content: Text("Error: $e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    employeeIdController.dispose();
    employeeNameController.dispose();
    positionController.dispose();
    passwordController.dispose();
    _employeeNameFocusNode.dispose();
    _positionFocusNode.dispose();
    _passwordFocusNode.dispose();
    _employeeIdFocusNode.removeListener(_onEmployeeIdFocusChange);
    _employeeIdFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF171A30),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double screenWidth = constraints.maxWidth;
          double loginBoxWidth = screenWidth > 1000 ? 500 : screenWidth * 0.8;
          double imageWidth = screenWidth > 1000 ? 400 : screenWidth * 0.4;
          double spacing = screenWidth > 1000 ? 80 : 30;

          return Column(
            children: [
              // ✅ Top Navbar (search removed)
              Container(
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFF171A30),
                  border: Border(
                    top: BorderSide(color: Colors.black, width: 2),
                    bottom: BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                child: Row(
                  children: const [
                    SizedBox(width: 16),
                    Image(
                      image: AssetImage('assets/logo_z.png'),
                      width: 100,
                      height: 50,
                    ),
                    Spacer(),
                    Image(
                      image: AssetImage('assets/logo_zeai.png'),
                      width: 140,
                      height: 140,
                    ),
                    SizedBox(width: 700),
                  ],
                ),
              ),

              // ✅ Main Body
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/png1.png',
                          width: imageWidth,
                          height: 350,
                        ),
                        SizedBox(width: spacing),

                        // ✅ Login Box
                        Container(
                          width: loginBoxWidth,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromARGB(255, 158, 27, 219),
                                blurRadius: 12,
                                offset: Offset(6, 6),
                              ),
                            ],
                          ),
                          child: AutofillGroup(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Employee/Admin Login',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF171A30),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                buildTextFieldRow(
                                  "Employee ID :",
                                  "Enter_id",
                                  employeeIdController,
                                  autofillHint: AutofillHints.username,
                                  onSubmitted: (_) => FocusScope.of(context)
                                      .requestFocus(_employeeNameFocusNode),
                                  focusNode: _employeeIdFocusNode,
                                  isFetching: _isFetchingDetails,
                                ),
                                const SizedBox(height: 16),
                                buildTextFieldRow(
                                  "Employee Name :",
                                  "Enter_Name",
                                  employeeNameController,
                                  focusNode: _employeeNameFocusNode,
                                  autofillHint: AutofillHints.name,
                                  onSubmitted: (_) => FocusScope.of(context)
                                      .requestFocus(_positionFocusNode),
                                ),
                                const SizedBox(height: 16),
                                buildTextFieldRow(
                                  "Position :",
                                  "Enter_position",
                                  positionController,
                                  focusNode: _positionFocusNode,
                                  autofillHint: AutofillHints.jobTitle,
                                  onSubmitted: (_) => FocusScope.of(context)
                                      .requestFocus(_passwordFocusNode),
                                ),
                             const SizedBox(height: 16),
                               // 🔴 Added Password Field
                                buildPasswordFieldRow(
                                  "Password :",
                                  "Enter_password",
                                  passwordController,
                                  focusNode: _passwordFocusNode,
                                  onSubmitted: (_) {
                                    if (!isLoading) {
                                      sendLoginDetails();
                                    }
                                  },
                                  autofillHint: AutofillHints.password,
                                ), // 🔴

                                // Remember password toggle + small security hint
                                Row(
                                  children: [
                                    Checkbox(
                                      value: rememberPassword,
                                      onChanged: (val) {
                                        setState(() {
                                          rememberPassword = val ?? false;
                                        });
                                        // Do not immediately save password to prefs here,
                                        // let it be saved after a successful login.
                                      },
                                    ),
                                    const Expanded(
                                      child: Text(
                                        "Remember password (optional)",
                                        style: TextStyle(
                                            fontSize: 14, color: Colors.black),
                                      ),
                                    ),
                                  ],
                                ),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "Warning: Saved locally and not encrypted. Use only on trusted devices.",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                SizedBox(
                                  width: 100,
                                  child: ElevatedButton(
                                    onPressed:
                                        isLoading ? null : sendLoginDetails,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF171A30),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Login',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildTextFieldRow(
    String label,
    String hint,
    TextEditingController controller, {
    String? autofillHint,
    FocusNode? focusNode,
    bool isFetching = false,
    void Function(String)? onSubmitted,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: onSubmitted,
            autofillHints: autofillHint != null ? [autofillHint] : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color.fromRGBO(53, 64, 85, 0.77),
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color.fromARGB(255, 183, 181, 181),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (isFetching)
          const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF171A30)),
            ),
          ),
      ],
    );
  }

  bool _obscurePassword = true;
  // 🔴 Added new Password Field widget
  Widget buildPasswordFieldRow(
    String label,
    String hint,
    TextEditingController controller, {
    String? autofillHint,
    FocusNode? focusNode,
    void Function(String)? onSubmitted,
  }) {
    // 🔴
    return Row(
      // 🔴
      crossAxisAlignment: CrossAxisAlignment.center, // 🔴
      children: [
        // 🔴
        SizedBox(
          // 🔴
          width: 130, // 🔴
          child: Text(
            // 🔴
            label, // 🔴
            style: const TextStyle(
              // 🔴
              color: Colors.black, // 🔴
              fontWeight: FontWeight.w900, // 🔴
            ), // 🔴
          ), // 🔴
        ), // 🔴
        Expanded(
          // 🔴
          child: TextField(
            // 🔴
            controller: controller, // 🔴
            focusNode: focusNode,
            onSubmitted: onSubmitted,
            obscureText: _obscurePassword, // 👁️ Use the state variable // 🔴 hide password
            autofillHints: autofillHint != null ? [autofillHint] : null,
            decoration: InputDecoration(
              // 🔴
              filled: true, // 🔴
              fillColor: const Color.fromRGBO(53, 64, 85, 0.77), // 🔴
              hintText: hint, // 🔴
              hintStyle: const TextStyle(
                // 🔴
                color: Color.fromARGB(255, 183, 181, 181), // 🔴
              ), // 🔴
              border: OutlineInputBorder(
                // 🔴
                borderRadius: BorderRadius.circular(10), // 🔴
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white, // 👁️ make the icon visible
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ), // 🔴
            ), // 🔴
          ), // 🔴
        ), // 🔴
      ], // 🔴
    ); // 🔴
  } // 🔴
}