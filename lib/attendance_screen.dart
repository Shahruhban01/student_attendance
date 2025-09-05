// attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String? selectedClassId;
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> students = [];
  Map<String, bool> attendanceMap = {};

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacherId', isEqualTo: user?.uid)
        .get();
    
    setState(() {
      classes = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>
      }).toList();
      
      if (classes.isNotEmpty && selectedClassId == null) {
        selectedClassId = classes.first['id'];
        _loadStudents();
      }
    });
  }

  Future<void> _loadStudents() async {
    if (selectedClassId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('classIds', arrayContains: selectedClassId)
        .get();
    
    setState(() {
      students = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>
      }).toList();
    });

    await _loadExistingAttendance();
  }

  Future<void> _loadExistingAttendance() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('classId', isEqualTo: selectedClassId)
        .where('date', isEqualTo: dateStr)
        .get();

    Map<String, bool> existingAttendance = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      existingAttendance[data['studentId']] = data['isPresent'] ?? false;
    }

    setState(() {
      attendanceMap = existingAttendance;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No classes available'),
            SizedBox(height: 8),
            Text('Add classes first to mark attendance'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class Selection
          Row(
            children: [
              const Text('Class: '),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: selectedClassId,
                  isExpanded: true,
                  items: classes.map<DropdownMenuItem<String>>((cls) => DropdownMenuItem<String>(
                    value: cls['id'] as String,
                    child: Text('${cls['name']} - ${cls['subject']}'),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedClassId = value;
                      _loadStudents();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Date Selection
          Row(
            children: [
              const Text('Date: '),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _markAllPresent,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark All Present'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _markAllAbsent,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Mark All Absent'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Students List
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('No students in this class'))
                : ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final studentId = student['id'];
                      final isPresent = attendanceMap[studentId] ?? false;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPresent ? Colors.green : Colors.red,
                            child: Icon(
                              isPresent ? Icons.check : Icons.close,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(student['name'] ?? 'Unnamed'),
                          subtitle: Text('Roll: ${student['rollNumber']}'),
                          trailing: Switch(
                            value: isPresent,
                            onChanged: (value) {
                              setState(() {
                                attendanceMap[studentId] = value;
                              });
                            },
                            activeColor: Colors.green,
                          ),
                          onTap: () {
                            setState(() {
                              attendanceMap[studentId] = !isPresent;
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveAttendance,
              icon: const Icon(Icons.save),
              label: const Text('Save Attendance'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      await _loadExistingAttendance();
    }
  }

  void _markAllPresent() {
    setState(() {
      for (var student in students) {
        attendanceMap[student['id']] = true;
      }
    });
  }

  void _markAllAbsent() {
    setState(() {
      for (var student in students) {
        attendanceMap[student['id']] = false;
      }
    });
  }

  Future<void> _saveAttendance() async {
    if (selectedClassId == null || students.isEmpty) return;

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final batch = FirebaseFirestore.instance.batch();

      for (var student in students) {
        final studentId = student['id'];
        final isPresent = attendanceMap[studentId] ?? false;
        
        final attendanceId = '${selectedClassId}_${studentId}_$dateStr';
        final attendanceRef = FirebaseFirestore.instance
            .collection('attendance')
            .doc(attendanceId);

        batch.set(attendanceRef, {
          'classId': selectedClassId,
          'studentId': studentId,
          'date': dateStr,
          'isPresent': isPresent,
          'markedAt': FieldValue.serverTimestamp(),
          'teacherId': user?.uid,
        }, SetOptions(merge: true));
      }

      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving attendance: $e')),
      );
    }
  }
}
