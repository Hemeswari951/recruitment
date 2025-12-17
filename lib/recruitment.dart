import 'package:flutter/material.dart';
import 'package:zeai_project/inviteTracker.dart';
import 'on_campus_page.dart';
import 'off_campus_page.dart';
import 'onboard.dart';
import 'exit_home_page.dart';
import 'sidebar.dart';
import 'dart:ui';

class RecruitmentHomePage extends StatelessWidget {
  const RecruitmentHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: "", // keep it empty since you don't want a title in header
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Material(
      color: const Color(0xFF0F1020),
      child: Column(
        children: [
          // ---------- HEADER SAME AS ON-CAMPUS PAGE ----------
          // Container(
          //   height: 70,
          //   padding: const EdgeInsets.symmetric(horizontal: 20),
          //   decoration: BoxDecoration(
          //     color: const Color(0xFF1A1B2E),
          //     boxShadow: [
          //       BoxShadow(
          //         color: Colors.black.withOpacity(0.3),
          //         blurRadius: 10,
          //         offset: const Offset(0, 4),
          //       ),
          //     ],
          //   ),
          //   child: Row(
          //     children: [
          //       // left: optional empty space or logo
          //       const SizedBox(width: 10),

          //       // center: nothing since title is empty
          //       const Spacer(),

          //       // right icon
          //       const Icon(Icons.people, color: Colors.white, size: 28),
          //     ],
          //   ),
          // ),

          // ---------- BODY CARDS ----------
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Wrap(
                  spacing: 35,
                  runSpacing: 35,
                  children: [
                    _menuCard(
                      context,
                      "Campus Invite",
                      Icons.mail_outline,
                      const InviteTrackerPage(),
                      Colors.purpleAccent,
                    ),
                    _menuCard(
                      context,
                      "On Campus Recruitment",
                      Icons.school,
                      const OnCampusPage(),
                      Colors.lightBlueAccent,
                    ),
                    _menuCard(
                      context,
                      "Off Campus Recruitment",
                      Icons.location_city,
                      const OffCampusPage(),
                      Colors.tealAccent,
                    ),
                    _menuCard(
                     context,
                      "OnBoard",
                      Icons.login,
                      const OnBoardPage(),
                      Colors.orangeAccent,
                    ),
                                        
                    _menuCard(
                      context,
                      "Exit",
                      Icons.exit_to_app,
                      const ExitHomePage(),
                      Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _menuCard(
    BuildContext context,
    String title,
    IconData icon,
    Widget page,
    Color color,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      child: Container(
        width: 260,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 55, color: color),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
