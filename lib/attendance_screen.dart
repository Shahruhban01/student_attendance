// attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with TickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  String? selectedClassId;
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> students = [];
  Map<String, bool> attendanceMap = {};
  
  // For bulk entry
  final TextEditingController _bulkRollController = TextEditingController();
  late TabController _tabController;
  
  // For auto-save with debouncing
  Timer? _debounce;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _bulkRollController.dispose();
    _tabController.dispose();
    _debounce?.cancel(); // Cancel debounce timer
    super.dispose();
  }

  // Auto-save with debouncing to prevent too many database calls
  void _onAttendanceChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      _saveAttendance(showMessage: false); // Auto-save without success message
    });
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

    print('Loading students for classId: $selectedClassId'); // Debug log

    try {
      // Remove orderBy temporarily to avoid index issues
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('classIds', arrayContains: selectedClassId)
          // .orderBy('rollNumber') // Comment this out temporarily
          .get();
      
      print('Found ${snapshot.docs.length} students'); // Debug log
      
      // Log each student document
      for (var doc in snapshot.docs) {
        print('Student document: ${doc.data()}');
      }
      
      setState(() {
        students = snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>
        }).toList();
      });

      print('Students loaded: ${students.length}'); // Debug log
      await _loadExistingAttendance();
      
    } catch (e) {
      print('Error loading students: $e'); // Debug log
      setState(() {
        students = [];
      });
    }
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

    return Column(
      children: [
        // Class and Date Selection
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Auto-save indicator
              if (_isSaving)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Auto-saving...',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              
              if (_isSaving) const SizedBox(height: 12),
              
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
            ],
          ),
        ),

        // Tab Bar
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Individual'),
            Tab(icon: Icon(Icons.format_list_bulleted), text: 'Bulk Entry'),
          ],
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildIndividualTab(),
              _buildBulkEntryTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndividualTab() {
    return Column(
      children: [
        // Quick Actions
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _markAllPresent,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('All Present'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _markAllAbsent,
                  icon: const Icon(Icons.cancel),
                  label: const Text('All Absent'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ),
            ],
          ),
        ),

        // Auto-save info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(
                'Auto-saves after 1.5 seconds of inactivity',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Students List
        Expanded(
          child: students.isEmpty
              ? const Center(child: Text('No students in this class'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            _onAttendanceChanged(); // Auto-save with debounce
                          },
                          activeColor: Colors.green,
                        ),
                        onTap: () {
                          setState(() {
                            attendanceMap[studentId] = !isPresent;
                          });
                          _onAttendanceChanged(); // Auto-save with debounce
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBulkEntryTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bulk Attendance Entry',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter roll numbers separated by commas, spaces, or new lines',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Bulk Entry Methods
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showPresentBulkDialog,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Mark Present'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showAbsentBulkDialog,
                          icon: const Icon(Icons.cancel),
                          label: const Text('Mark Absent'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Current Status
          Text(
            'Current Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatusCard(
                          'Present',
                          attendanceMap.values.where((v) => v == true).length,
                          Colors.green,
                        ),
                        _buildStatusCard(
                          'Absent',
                          attendanceMap.values.where((v) => v == false).length,
                          Colors.red,
                        ),
                        _buildStatusCard(
                          'Not Marked',
                          students.length - attendanceMap.length,
                          Colors.grey,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Student List with Status
                    Expanded(
                      child: ListView.builder(
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          final studentId = student['id'];
                          final isPresent = attendanceMap[studentId];
                          
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isPresent == null 
                                  ? Colors.grey 
                                  : isPresent 
                                    ? Colors.green 
                                    : Colors.red,
                              child: Text(
                                student['rollNumber'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            title: Text(student['name'] ?? 'Unnamed'),
                            subtitle: Text('Roll: ${student['rollNumber']}'),
                            trailing: Text(
                              isPresent == null 
                                  ? 'Not Marked' 
                                  : isPresent 
                                    ? 'Present' 
                                    : 'Absent',
                              style: TextStyle(
                                color: isPresent == null 
                                    ? Colors.grey 
                                    : isPresent 
                                      ? Colors.green 
                                      : Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
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

  Widget _buildStatusCard(String title, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showPresentBulkDialog() {
    _showBulkDialog(true);
  }

  void _showAbsentBulkDialog() {
    _showBulkDialog(false);
  }

  void _showBulkDialog(bool isPresent) {
    _bulkRollController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark ${isPresent ? 'Present' : 'Absent'} - Bulk'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter roll numbers (separated by commas, spaces, or new lines):',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bulkRollController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'e.g., 1, 2, 3\nor\n1 2 3\nor\n1\n2\n3',
                border: const OutlineInputBorder(),
                labelText: 'Roll Numbers',
                prefixIcon: Icon(
                  isPresent ? Icons.check_circle : Icons.cancel,
                  color: isPresent ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isPresent ? Colors.green : Colors.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: isPresent ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Students with these roll numbers will be marked as ${isPresent ? 'PRESENT' : 'ABSENT'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isPresent ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _processBulkAttendance(isPresent),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPresent ? Colors.green : Colors.red,
            ),
            child: Text('Mark ${isPresent ? 'Present' : 'Absent'}'),
          ),
        ],
      ),
    );
  }

  void _processBulkAttendance(bool isPresent) {
    final rollNumbers = _bulkRollController.text
        .replaceAll(RegExp(r'[,\s\n]+'), ' ')
        .trim()
        .split(' ')
        .where((roll) => roll.isNotEmpty)
        .toList();

    if (rollNumbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter roll numbers')),
      );
      return;
    }

    int markedCount = 0;
    List<String> notFoundRolls = [];

    for (String rollNumber in rollNumbers) {
      final student = students.firstWhere(
        (s) => s['rollNumber'].toString().trim() == rollNumber.trim(),
        orElse: () => {},
      );

      if (student.isNotEmpty) {
        setState(() {
          attendanceMap[student['id']] = isPresent;
        });
        markedCount++;
      } else {
        notFoundRolls.add(rollNumber);
      }
    }

    Navigator.pop(context);

    // Show result
    String message = '$markedCount students marked as ${isPresent ? 'present' : 'absent'}';
    if (notFoundRolls.isNotEmpty) {
      message += '\nNot found: ${notFoundRolls.join(', ')}';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: markedCount > 0 ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );

    // Auto-save bulk changes
    _onAttendanceChanged();
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
    _onAttendanceChanged(); // Auto-save
  }

  void _markAllAbsent() {
    setState(() {
      for (var student in students) {
        attendanceMap[student['id']] = false;
      }
    });
    _onAttendanceChanged(); // Auto-save
  }

  Future<void> _saveAttendance({bool showMessage = true}) async {
    if (selectedClassId == null || students.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

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
      
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Attendance saved successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Error saving attendance: $e'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
