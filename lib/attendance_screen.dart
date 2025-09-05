// attendance_screen.dart - Modern & Professional Design
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

class _AttendanceScreenState extends State<AttendanceScreen> 
    with TickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  String? selectedClassId;
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> students = [];
  Map<String, bool> attendanceMap = {};
  
  final TextEditingController _bulkRollController = TextEditingController();
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  Timer? _debounce;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _bulkRollController.dispose();
    _tabController.dispose();
    _animationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onAttendanceChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _saveAttendance(showMessage: false);
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

    try {
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
    } catch (e) {
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
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
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
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.indigo.shade50, Colors.white],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.shade100,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.school_outlined,
                size: 80,
                color: Colors.indigo.shade300,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Classes Available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first class to start\nmarking attendance',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade100,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Auto-save indicator
            if (_isSaving) _buildSaveIndicator(),
            if (_isSaving) const SizedBox(height: 16),
            
            // Class selection
            _buildClassSelector(),
            const SizedBox(height: 20),
            
            // Date selection
            _buildDateSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Auto-saving...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.class_, color: Colors.indigo.shade600, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<String>(
                value: selectedClassId,
                isExpanded: true,
                underline: const SizedBox(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.indigo.shade700,
                  fontWeight: FontWeight.w600,
                ),
                items: classes.map<DropdownMenuItem<String>>((cls) => 
                  DropdownMenuItem<String>(
                    value: cls['id'] as String,
                    child: Text('${cls['name']} - ${cls['subject']}'),
                  )
                ).toList(),
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
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.green.shade600, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, MMMM dd, yyyy').format(selectedDate),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.green.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [Colors.indigo.shade400, Colors.indigo.shade600],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.shade200,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        tabs: const [
          Tab(icon: Icon(Icons.person), text: 'Individual'),
          Tab(icon: Icon(Icons.groups), text: 'Bulk Entry'),
        ],
      ),
    );
  }

  Widget _buildIndividualTab() {
    return Column(
      children: [
        _buildQuickActions(),
        _buildAutoSaveInfo(),
        const SizedBox(height: 10),
        Expanded(
          child: students.isEmpty
              ? _buildNoStudentsState()
              : _buildStudentsList(),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _markAllPresent,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('All Present'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _markAllAbsent,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('All Absent'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoSaveInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 18, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Auto-saves after 1.5 seconds of inactivity',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoStudentsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No students in this class',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add students to start marking attendance',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final studentId = student['id'];
        final isPresent = attendanceMap[studentId] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPresent 
                      ? [Colors.green.shade400, Colors.green.shade600]
                      : [Colors.red.shade400, Colors.red.shade600],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: isPresent ? Colors.green.shade200 : Colors.red.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isPresent ? Icons.check : Icons.close,
                color: Colors.white,
                size: 24,
              ),
            ),
            title: Text(
              student['name'] ?? 'Unnamed',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Roll: ${student['rollNumber']}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing: Switch.adaptive(
              value: isPresent,
              onChanged: (value) {
                setState(() {
                  attendanceMap[studentId] = value;
                });
                _onAttendanceChanged();
              },
              activeColor: Colors.green.shade600,
            ),
            onTap: () {
              setState(() {
                attendanceMap[studentId] = !isPresent;
              });
              _onAttendanceChanged();
            },
          ),
        );
      },
    );
  }

  Widget _buildBulkEntryTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBulkEntryCard(),
          const SizedBox(height: 20),
          _buildStatusOverview(),
          const SizedBox(height: 5),
          Expanded(
            child: _buildStudentsStatusList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkEntryCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.indigo.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_note,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk Attendance Entry',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mark multiple students at once',
                        style: TextStyle(
                          color: Colors.indigo.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showPresentBulkDialog,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark Present'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAbsentBulkDialog,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Mark Absent'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverview() {
    final presentCount = attendanceMap.values.where((v) => v == true).length;
    final absentCount = attendanceMap.values.where((v) => v == false).length;
    final notMarkedCount = students.length - attendanceMap.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModernStatusCard('Present', presentCount, Colors.green),
              _buildModernStatusCard('Absent', absentCount, Colors.red),
              _buildModernStatusCard('Pending', notMarkedCount, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatusCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color is MaterialColor ? color.shade700 : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsStatusList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Student Status (${students.length} total)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                final studentId = student['id'];
                final isPresent = attendanceMap[studentId];
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isPresent == null 
                        ? Colors.grey.shade50
                        : isPresent 
                            ? Colors.green.shade50 
                            : Colors.red.shade50,
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isPresent == null 
                            ? Colors.grey.shade400
                            : isPresent 
                                ? Colors.green.shade500 
                                : Colors.red.shade500,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          student['rollNumber']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      student['name'] ?? 'Unnamed',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPresent == null 
                            ? Colors.grey.shade600
                            : isPresent 
                                ? Colors.green.shade600 
                                : Colors.red.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isPresent == null 
                            ? 'Pending' 
                            : isPresent 
                                ? 'Present' 
                                : 'Absent',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Keep all your existing methods (_showBulkDialog, _processBulkAttendance, etc.)
  // but update the dialog design:

  void _showBulkDialog(bool isPresent) {
    _bulkRollController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPresent ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPresent ? Icons.check_circle : Icons.cancel,
                color: isPresent ? Colors.green.shade600 : Colors.red.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mark ${isPresent ? 'Present' : 'Absent'} - Bulk',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter roll numbers (separated by commas, spaces, or new lines):',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bulkRollController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'e.g., 1, 2, 3\nor\n1 2 3\nor\n1\n2\n3',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelText: 'Roll Numbers',
                prefixIcon: Icon(
                  isPresent ? Icons.check_circle : Icons.cancel,
                  color: isPresent ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isPresent ? Colors.green : Colors.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: isPresent ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Students with these roll numbers will be marked as ${isPresent ? 'PRESENT' : 'ABSENT'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
                        fontWeight: FontWeight.w500,
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
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Mark ${isPresent ? 'Present' : 'Absent'}'),
          ),
        ],
      ),
    );
  }

  // Keep all your existing methods unchanged:
  // _showPresentBulkDialog, _showAbsentBulkDialog, _processBulkAttendance,
  // _selectDate, _markAllPresent, _markAllAbsent, _saveAttendance
  
  void _showPresentBulkDialog() => _showBulkDialog(true);
  void _showAbsentBulkDialog() => _showBulkDialog(false);

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

  // 🔥 ADD THIS LINE - Trigger auto-save after bulk changes
  _onAttendanceChanged();
}

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade600,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
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
    _onAttendanceChanged();
  }

  void _markAllAbsent() {
    setState(() {
      for (var student in students) {
        attendanceMap[student['id']] = false;
      }
    });
    _onAttendanceChanged();
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
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Attendance saved successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
