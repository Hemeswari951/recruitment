//company_events.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'sidebar.dart';

// Reusable model for events
class CompanyEvent {
  final String id;
  final String title;
  final String? description;
  final String venue;
  final DateTime dateTime;
  final String? specialGuest;
  final String company;
  final String? bannerUrl;

  CompanyEvent({
    required this.id,
    required this.title,
    required this.company,
    required this.venue,
    required this.dateTime,
    this.specialGuest,
    this.description,
    this.bannerUrl,
  });

  factory CompanyEvent.fromJson(Map<String, dynamic> json) => CompanyEvent(
        id: json['_id'] ?? json['id'] ?? '',
        title: json['title'] ?? '',
        company: json['company'] ?? 'ZeAI Soft',
        venue: json['venue'] ?? '',
        specialGuest: json['specialGuest'],
        description: json['description'],
        bannerUrl: json['bannerUrl'],
        dateTime: DateTime.parse(json['dateTime']).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'company': company,
        'venue': venue,
        'specialGuest': specialGuest,
        'description': description,
        'bannerUrl': bannerUrl,
        'dateTime': dateTime.toIso8601String(),
      };
}

class CompanyEventsScreen extends StatefulWidget {
  final bool isHR; // ✅ Determines if HR is logged in

  const CompanyEventsScreen({super.key, this.isHR = false});

  @override
  State<CompanyEventsScreen> createState() => _CompanyEventsScreenState();
}

class _CompanyEventsScreenState extends State<CompanyEventsScreen> {
  final List<CompanyEvent> _events = [];
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    try {
      final response =
          await http.get(Uri.parse('http://localhost:5000/company-events'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<CompanyEvent> fetchedEvents =
            data.map((e) => CompanyEvent.fromJson(e)).toList();

        setState(() {
          _events.clear();
          _events.addAll(fetchedEvents);
          _isLoading = false;
        });
      } else {
        debugPrint('Failed to load events: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addOrEditEvent({CompanyEvent? existingEvent}) async {
    final isEditing = existingEvent != null;

    final titleController =
        TextEditingController(text: existingEvent?.title ?? '');
    final venueController =
        TextEditingController(text: existingEvent?.venue ?? '');
    final companyController =
        TextEditingController(text: existingEvent?.company ?? 'ZeAI Soft');
    final guestController =
        TextEditingController(text: existingEvent?.specialGuest ?? '');
    final descController =
        TextEditingController(text: existingEvent?.description ?? '');

    DateTime selectedDate =
        existingEvent?.dateTime ?? DateTime.now().add(const Duration(days: 1));

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Event' : 'Add New Event'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Event Title *'),
              ),
              TextField(
                controller: venueController,
                decoration: const InputDecoration(labelText: 'Venue *'),
              ),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(labelText: 'Company'),
              ),
              TextField(
                controller: guestController,
                decoration: const InputDecoration(labelText: 'Special Guest'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Date: ${_dateFormat.format(selectedDate)}'),
                  IconButton(
                    icon: const Icon(Icons.calendar_today, color: Colors.blue),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDate),
                        );
                        if (time != null) {
                          setState(() {
                            selectedDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty ||
                  venueController.text.trim().isEmpty) {
                return;
              }

              final event = CompanyEvent(
                id: existingEvent?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleController.text.trim(),
                company: companyController.text.trim(),
                venue: venueController.text.trim(),
                specialGuest: guestController.text.trim(),
                description: descController.text.trim(),
                dateTime: selectedDate,
              );

              final url = isEditing
                  ? 'http://localhost:5000/company-events/${event.id}'
                  : 'http://localhost:5000/company-events';
              final method = isEditing ? 'PUT' : 'POST';

              final response = await (method == 'POST'
                  ? http.post(Uri.parse(url),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(event.toJson()))
                  : http.put(Uri.parse(url),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(event.toJson())));

              if (response.statusCode == 200 || response.statusCode == 201) {
                Navigator.pop(context);
                _fetchEvents(); // refresh list
              }
            },
            child: Text(isEditing ? 'Save Changes' : 'Add Event'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(String id) async {
    final response =
        await http.delete(Uri.parse('http://localhost:5000/company-events/$id'));
    if (response.statusCode == 200) {
      _fetchEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      title: 'Events',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Events',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.isHR)
                  ElevatedButton.icon(
                    onPressed: () => _addOrEditEvent(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Event'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? const Center(
                        child: Text(
                          'No upcoming events',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: ListView.builder(
                          itemCount: _events.length,
                          itemBuilder: (context, index) {
                            final event = _events[index];
                            return GestureDetector(
                              onTap: widget.isHR
                                  ? () => _addOrEditEvent(existingEvent: event) // 👈 Tap to edit
                                  : null,
                              child: EventTile(
                                day: DateFormat('dd').format(event.dateTime),
                                weekday: DateFormat('EEE').format(event.dateTime),
                                title: event.title,
                                description: event.description ?? '',
                                company: event.company,
                                time: _dateFormat.format(event.dateTime),
                                onDelete: widget.isHR
                                    ? () async {
                                        final confirm = await showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Event'),
                                            content: Text('Are you sure you want to delete "${event.title}"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.redAccent,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) _deleteEvent(event.id);
                                      }
                                    : null,
                              ),
                            );


                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class EventTile extends StatelessWidget {
  final String day;
  final String weekday;
  final String title;
  final String company;
  final String? description; 
  final String time;
  final VoidCallback? onDelete;

  const EventTile({
    super.key,
    required this.day,
    required this.weekday,
    required this.title,
    required this.company,
    this.description,
    required this.time,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2D2F41),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  weekday,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4, // better readability for long text
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  company,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
