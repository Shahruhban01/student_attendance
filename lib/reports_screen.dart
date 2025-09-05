// reports_screen.dart
import 'dart:io';
import 'dart:ui' as fw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat, PdfColors;
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Updated to 4 tabs
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Datewise Report'), // New tab
            Tab(text: 'Class Reports'),
            Tab(text: 'Student Reports'),
            Tab(text: 'Analytics'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              DatewiseAttendanceReport(teacherId: user?.uid ?? ''), // New tab content
              ClassReportsTab(teacherId: user?.uid ?? ''),
              StudentReportsTab(teacherId: user?.uid ?? ''),
              AnalyticsTab(teacherId: user?.uid ?? ''),
            ],
          ),
        ),
      ],
    );
  }
}



// Complete DatewiseAttendanceReport class with export functionality
class DatewiseAttendanceReport extends StatefulWidget {
  final String teacherId;

  const DatewiseAttendanceReport({super.key, required this.teacherId});

  @override
  State<DatewiseAttendanceReport> createState() => _DatewiseAttendanceReportState();
}

class _DatewiseAttendanceReportState extends State<DatewiseAttendanceReport> {
  DateTime _selectedDate = DateTime.now();
  bool _isMonthly = false;
  String _searchQuery = '';
  String? _selectedClassId;
  
  List<Map<String, dynamic>> _attendanceReport = [];
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacherId', isEqualTo: widget.teacherId)
        .get();
    
    setState(() {
      _classes = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>
      }).toList();
      
      if (_classes.isNotEmpty && _selectedClassId == null) {
        _selectedClassId = _classes.first['id'];
        _fetchReport();
      }
    });
  }

  Future<void> _fetchReport() async {
    if (_selectedClassId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Get students for selected class
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('classIds', arrayContains: _selectedClassId)
          .get();

      final students = studentsSnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>
      }).toList();

      List<Map<String, dynamic>> reportData = [];

      if (_isMonthly) {
        // Monthly report
        final year = _selectedDate.year;
        final month = _selectedDate.month;
        final firstDay = DateTime(year, month, 1);
        final lastDay = DateTime(year, month + 1, 0);

        final startDateStr = DateFormat('yyyy-MM-dd').format(firstDay);
        final endDateStr = DateFormat('yyyy-MM-dd').format(lastDay);

        // Get all attendance records for the month
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .where('classId', isEqualTo: _selectedClassId)
            .where('date', isGreaterThanOrEqualTo: startDateStr)
            .where('date', isLessThanOrEqualTo: endDateStr)
            .get();

        // Group attendance by student
        Map<String, List<Map<String, dynamic>>> studentAttendance = {};
        for (var doc in attendanceSnapshot.docs) {
          final data = doc.data();
          final studentId = data['studentId'];
          studentAttendance.putIfAbsent(studentId, () => []);
          studentAttendance[studentId]!.add(data);
        }

        for (var student in students) {
          final studentId = student['id'];
          final records = studentAttendance[studentId] ?? [];
          
          int presentDays = records.where((r) => r['isPresent'] == true).length;
          int totalClasses = records.length;
          double attendancePercent = totalClasses == 0 ? 0 : (presentDays / totalClasses) * 100;

          reportData.add({
            'name': student['name'],
            'rollNumber': student['rollNumber'],
            'presentDays': presentDays,
            'totalClasses': totalClasses,
            'attendancePercent': attendancePercent,
          });
        }
      } else {
        // Daily report
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .where('classId', isEqualTo: _selectedClassId)
            .where('date', isEqualTo: dateStr)
            .get();

        Map<String, bool> attendanceMap = {};
        for (var doc in attendanceSnapshot.docs) {
          final data = doc.data();
          attendanceMap[data['studentId']] = data['isPresent'] ?? false;
        }

        for (var student in students) {
          final studentId = student['id'];
          final isPresent = attendanceMap[studentId];

          reportData.add({
            'name': student['name'],
            'rollNumber': student['rollNumber'],
            'isPresent': isPresent,
            'status': isPresent == null ? 'Not Marked' : (isPresent ? 'Present' : 'Absent'),
          });
        }
      }

      setState(() {
        _attendanceReport = reportData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _isMonthly = false;
      });
      _fetchReport();
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _isMonthly = true;
      });
      _fetchReport();
    }
  }

  // Export to CSV function
  Future<void> _exportToCSV() async {
    if (_attendanceReport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    try {
      List<List<String>> rows = [];
      
      // Add headers based on report type
      if (_isMonthly) {
        rows.add(['Name', 'Roll Number', 'Present Days', 'Total Classes', 'Attendance %']);
        
        // Add data rows
        for (var student in _attendanceReport) {
          rows.add([
            student['name'] ?? '',
            student['rollNumber']?.toString() ?? '',
            student['presentDays']?.toString() ?? '0',
            student['totalClasses']?.toString() ?? '0',
            '${(student['attendancePercent'] ?? 0).toStringAsFixed(1)}%',
          ]);
        }
      } else {
        rows.add(['Name', 'Roll Number', 'Status']);
        
        // Add data rows
        for (var student in _attendanceReport) {
          rows.add([
            student['name'] ?? '',
            student['rollNumber']?.toString() ?? '',
            student['status'] ?? 'Not Marked',
          ]);
        }
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);
      
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final reportType = _isMonthly ? 'Monthly' : 'Daily';
      final fileName = 'Attendance_Report_${reportType}_$dateStr.csv';
      final path = '${directory.path}/$fileName';
      final file = File(path);
      
      // Write CSV data to file
      await file.writeAsString(csv);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Attendance Report - $reportType $dateStr',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('CSV exported successfully'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting CSV: $e')),
      );
    }
  }

  // Export to PDF function
  Future<void> _exportToPDF() async {
    if (_attendanceReport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Prepare headers and data
      List<String> headers;
      List<List<String>> data;
      
      if (_isMonthly) {
        headers = ['Name', 'Roll No.', 'Present', 'Total', 'Attendance %'];
        data = _attendanceReport.map<List<String>>((student) => [
          student['name'] ?? '',
          student['rollNumber']?.toString() ?? '',
          student['presentDays']?.toString() ?? '0',
          student['totalClasses']?.toString() ?? '0',
          '${(student['attendancePercent'] ?? 0).toStringAsFixed(1)}%',
        ]).toList();
      } else {
        headers = ['Name', 'Roll No.', 'Status'];
        data = _attendanceReport.map<List<String>>((student) => [
          student['name'] ?? '',
          student['rollNumber']?.toString() ?? '',
          student['status'] ?? 'Not Marked',
        ]).toList();
      }

      // Get class name
      final selectedClass = _classes.firstWhere(
        (cls) => cls['id'] == _selectedClassId,
        orElse: () => {'name': 'Unknown', 'subject': 'Class'},
      );

      // Create PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 20),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(width: 2),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Attendance Report',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Class: ${selectedClass['name']} - ${selectedClass['subject']}',
                        style: pw.TextStyle(fontSize: 14),
                      ),
                      pw.Text(
                        _isMonthly 
                            ? 'Month: ${DateFormat('MMMM yyyy').format(_selectedDate)}'
                            : 'Date: ${DateFormat('dd MMMM yyyy').format(_selectedDate)}',
                        style: pw.TextStyle(fontSize: 14),
                      ),
                      pw.Text(
                        'Generated on: ${DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now())}',
                        style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Summary
                if (_isMonthly) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Column(
                          children: [
                            pw.Text(
                              '${_attendanceReport.length}',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text('Total Students', style: pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text(
                              '${_attendanceReport.where((s) => (s['attendancePercent'] ?? 0) >= 75).length}',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green,
                              ),
                            ),
                            pw.Text('Good Attendance', style: pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text(
                              '${_attendanceReport.where((s) => (s['attendancePercent'] ?? 0) < 75).length}',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.red,
                              ),
                            ),
                            pw.Text('Low Attendance', style: pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
                
                // Table
                pw.Table.fromTextArray(
                  headers: headers,
                  data: data,
                  border: pw.TableBorder.all(width: 0.5),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.indigo,
                  ),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: const pw.EdgeInsets.all(8),
                  oddRowDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey50,
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Show PDF
      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
        name: 'Attendance_Report_${_isMonthly ? 'Monthly' : 'Daily'}_${DateFormat('yyyy-MM-dd').format(_selectedDate)}.pdf',
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = _attendanceReport.where((student) {
      if (_searchQuery.isEmpty) return true;
      final rollNumber = (student['rollNumber'] ?? '').toString().toLowerCase();
      final name = (student['name'] ?? '').toString().toLowerCase();
      return rollNumber.contains(_searchQuery.toLowerCase()) || 
             name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Class',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      // Export buttons
                      if (!_isLoading && _attendanceReport.isNotEmpty) ...[
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _exportToCSV,
                              icon: const Icon(Icons.table_chart, size: 16),
                              label: const Text('CSV'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // ElevatedButton.icon(
                            //   onPressed: _exportToPDF,
                            //   icon: const Icon(Icons.picture_as_pdf, size: 16),
                            //   label: const Text('PDF'),
                            //   style: ElevatedButton.styleFrom(
                            //     backgroundColor: Colors.red,
                            //     foregroundColor: Colors.white,
                            //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            //   ),
                            // ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _selectedClassId,
                    isExpanded: true,
                    items: _classes.map<DropdownMenuItem<String>>((cls) => DropdownMenuItem<String>(
                      value: cls['id'] as String,
                      child: Text('${cls['name']} - ${cls['subject']}'),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedClassId = value;
                      });
                      _fetchReport();
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Date/Month Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isMonthly ? Icons.calendar_view_month : Icons.calendar_today,
                        color: Colors.indigo,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isMonthly 
                            ? 'Monthly Report: ${DateFormat('MMMM yyyy').format(_selectedDate)}'
                            : 'Daily Report: ${DateFormat('dd MMMM yyyy').format(_selectedDate)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Select Date'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_isMonthly ? Colors.indigo : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickMonth,
                          icon: const Icon(Icons.calendar_view_month),
                          label: const Text('Select Month'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isMonthly ? Colors.indigo : Colors.grey,
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

          // Search
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search by roll number or name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),

          const SizedBox(height: 16),

          // Results Summary
          if (!_isLoading && _attendanceReport.isNotEmpty)
            Card(
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${filteredData.length}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
                        ),
                        const Text('Total Students'),
                      ],
                    ),
                    if (_isMonthly) ...[
                      Column(
                        children: [
                          Text(
                            '${filteredData.where((s) => (s['attendancePercent'] ?? 0) >= 75).length}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const Text('Good Attendance'),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${filteredData.where((s) => (s['attendancePercent'] ?? 0) < 75).length}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          const Text('Low Attendance'),
                        ],
                      ),
                    ] else ...[
                      Column(
                        children: [
                          Text(
                            '${filteredData.where((s) => s['isPresent'] == true).length}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const Text('Present'),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${filteredData.where((s) => s['isPresent'] == false).length}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          const Text('Absent'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Attendance Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredData.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No data available for selected criteria'),
                          ],
                        ),
                      )
                    : Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(Colors.indigo.shade50),
                              columns: _isMonthly
                                  ? const [
                                      DataColumn(
                                        label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      DataColumn(
                                        label: Text('Roll No.', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      DataColumn(
                                        label: Text('Present', style: TextStyle(fontWeight: FontWeight.bold)),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                                        numeric: true,
                                      ),
                                      DataColumn(
                                        label: Text('Percentage', style: TextStyle(fontWeight: FontWeight.bold)),
                                        numeric: true,
                                      ),
                                    ]
                                  : const [
                                      DataColumn(
                                        label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      DataColumn(
                                        label: Text('Roll No.', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      DataColumn(
                                        label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                              rows: filteredData.map((student) {
                                if (_isMonthly) {
                                  final percentage = student['attendancePercent'] ?? 0.0;
                                  final color = percentage >= 75 
                                      ? Colors.green 
                                      : percentage >= 50 
                                        ? Colors.orange 
                                        : Colors.red;
                                  
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(student['name'] ?? 'Unknown')),
                                      DataCell(Text(student['rollNumber']?.toString() ?? '')),
                                      DataCell(Text('${student['presentDays'] ?? 0}')),
                                      DataCell(Text('${student['totalClasses'] ?? 0}')),
                                      DataCell(
                                        Text(
                                          '${percentage.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  final isPresent = student['isPresent'];
                                  final status = student['status'] ?? 'Not Marked';
                                  final color = isPresent == null 
                                      ? Colors.grey 
                                      : isPresent 
                                        ? Colors.green 
                                        : Colors.red;
                                  
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(student['name'] ?? 'Unknown')),
                                      DataCell(Text(student['rollNumber']?.toString() ?? '')),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isPresent == null 
                                                  ? Icons.help_outline 
                                                  : isPresent 
                                                    ? Icons.check_circle 
                                                    : Icons.cancel,
                                              color: color,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              status,
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}


class ClassReportsTab extends StatefulWidget {
  final String teacherId;

  const ClassReportsTab({super.key, required this.teacherId});

  @override
  State<ClassReportsTab> createState() => _ClassReportsTabState();
}

class _ClassReportsTabState extends State<ClassReportsTab> {
  List<Map<String, dynamic>> classes = [];
  String? selectedClassId;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacherId', isEqualTo: widget.teacherId)
        .get();
    
    setState(() {
      classes = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>
      }).toList();
      
      if (classes.isNotEmpty && selectedClassId == null) {
        selectedClassId = classes.first['id'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return const Center(child: Text('No classes available'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          DropdownButton<String>(
            value: selectedClassId,
            isExpanded: true,
            items: classes.map<DropdownMenuItem<String>>((cls) => DropdownMenuItem<String>(
              value: cls['id'] as String,
              child: Text('${cls['name']} - ${cls['subject']}'),
            )).toList(),
            onChanged: (value) {
              setState(() {
                selectedClassId = value;
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _getClassReport(selectedClassId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final report = snapshot.data ?? {};
                final students = report['students'] as List<Map<String, dynamic>>? ?? [];

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(report),
                      const SizedBox(height: 16),
                      const Text(
                        'Student-wise Attendance',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...students.map((student) => _buildStudentAttendanceCard(student)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Class Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total Students', '${report['totalStudents'] ?? 0}'),
                _buildStatItem('Total Classes', '${report['totalClasses'] ?? 0}'),
                _buildStatItem('Average Attendance', '${report['averageAttendance']?.toStringAsFixed(1) ?? 0}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildStudentAttendanceCard(Map<String, dynamic> student) {
    final attendanceRate = student['attendanceRate'] ?? 0.0;
    final color = attendanceRate >= 75 ? Colors.green : attendanceRate >= 50 ? Colors.orange : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Text(
            '${attendanceRate.toInt()}%',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text(student['name'] ?? 'Unknown'),
        subtitle: Text('Roll: ${student['rollNumber']} • ${student['presentDays']}/${student['totalDays']} days'),
        trailing: Icon(
          attendanceRate >= 75 ? Icons.trending_up : Icons.trending_down,
          color: color,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getClassReport(String classId) async {
    // Get students in this class
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('classIds', arrayContains: classId)
        .get();

    // Get attendance records for this class
    final attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .get();

    final students = studentsSnapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data()
    }).toList();

    // Calculate attendance for each student
    Map<String, Map<String, int>> studentAttendance = {};
    Set<String> allDates = {};

    for (var record in attendanceSnapshot.docs) {
      final data = record.data();
      final studentId = data['studentId'];
      final date = data['date'];
      final isPresent = data['isPresent'] ?? false;

      allDates.add(date);
      studentAttendance.putIfAbsent(studentId, () => {'present': 0, 'total': 0});
      studentAttendance[studentId]!['total'] = studentAttendance[studentId]!['total']! + 1;
      if (isPresent) {
        studentAttendance[studentId]!['present'] = studentAttendance[studentId]!['present']! + 1;
      }
    }

    // Calculate attendance rates
    List<Map<String, dynamic>> studentsWithAttendance = [];
    double totalAttendanceRate = 0;
    int validStudents = 0;

    for (var student in students) {
      final studentId = student['id'];
      final attendance = studentAttendance[studentId];
      final presentDays = attendance?['present'] ?? 0;
      final totalDays = attendance?['total'] ?? 0;
      final attendanceRate = totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0;

      if (totalDays > 0) {
        totalAttendanceRate += attendanceRate;
        validStudents++;
      }

      studentsWithAttendance.add({
        ...student,
        'presentDays': presentDays,
        'totalDays': totalDays,
        'attendanceRate': attendanceRate,
      });
    }

    final averageAttendance = validStudents > 0 ? totalAttendanceRate / validStudents : 0.0;

    return {
      'totalStudents': students.length,
      'totalClasses': allDates.length,
      'averageAttendance': averageAttendance,
      'students': studentsWithAttendance,
    };
  }
}

class StudentReportsTab extends StatelessWidget {
  final String teacherId;

  const StudentReportsTab({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllStudentsWithAttendance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final students = snapshot.data ?? [];

        if (students.isEmpty) {
          return const Center(child: Text('No students found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return _buildStudentReportCard(student);
          },
        );
      },
    );
  }

  Widget _buildStudentReportCard(Map<String, dynamic> student) {
    final classes = student['classes'] as List<Map<String, dynamic>>? ?? [];
    double overallAttendance = 0;
    int totalClasses = 0;

    for (var cls in classes) {
      overallAttendance += cls['attendanceRate'] ?? 0;
      totalClasses++;
    }

    final avgAttendance = totalClasses > 0 ? overallAttendance / totalClasses : 0.0;
    final color = avgAttendance >= 75 ? Colors.green : avgAttendance >= 50 ? Colors.orange : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Text(
            student['name']?.substring(0, 1).toUpperCase() ?? 'S',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(student['name'] ?? 'Unknown Student'),
        subtitle: Text('Overall: ${avgAttendance.toStringAsFixed(1)}% • Roll: ${student['rollNumber']}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: classes.map((cls) {
                final rate = cls['attendanceRate'] ?? 0.0;
                return ListTile(
                  title: Text(cls['className'] ?? 'Unknown Class'),
                  subtitle: Text('${cls['subject']} • ${cls['presentDays']}/${cls['totalDays']} classes'),
                  trailing: Text(
                    '${rate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: rate >= 75 ? Colors.green : rate >= 50 ? Colors.orange : Colors.red,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getAllStudentsWithAttendance() async {
    // Get all students
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    // Get all classes
    final classesSnapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    final classesMap = Map.fromEntries(
      classesSnapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
    );

    // Get all attendance records
    final attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    List<Map<String, dynamic>> studentsWithAttendance = [];

    for (var studentDoc in studentsSnapshot.docs) {
      final studentData = studentDoc.data();
      final studentId = studentDoc.id;
      final classIds = List<String>.from(studentData['classIds'] ?? []);

      List<Map<String, dynamic>> studentClasses = [];

      for (String classId in classIds) {
        final classData = classesMap[classId];
        if (classData == null) continue;

        // Calculate attendance for this student in this class
        final classAttendance = attendanceSnapshot.docs.where((doc) {
          final data = doc.data();
          return data['studentId'] == studentId && data['classId'] == classId;
        }).toList();

        int presentDays = 0;
        int totalDays = classAttendance.length;

        for (var attendance in classAttendance) {
          if (attendance.data()['isPresent'] == true) {
            presentDays++;
          }
        }

        final attendanceRate = totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0;

        studentClasses.add({
          'classId': classId,
          'className': classData['name'],
          'subject': classData['subject'],
          'presentDays': presentDays,
          'totalDays': totalDays,
          'attendanceRate': attendanceRate,
        });
      }

      studentsWithAttendance.add({
        ...studentData,
        'id': studentId,
        'classes': studentClasses,
      });
    }

    return studentsWithAttendance;
  }
}

class AnalyticsTab extends StatelessWidget {
  final String teacherId;

  const AnalyticsTab({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getAnalyticsData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final analytics = snapshot.data ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverallStats(analytics),
              const SizedBox(height: 16),
              _buildTrendAnalysis(analytics),
              const SizedBox(height: 16),
              _buildClassComparison(analytics),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverallStats(Map<String, dynamic> analytics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2,
              children: [
                _buildStatCard('Total Students', '${analytics['totalStudents'] ?? 0}', Icons.people, Colors.blue),
                _buildStatCard('Total Classes', '${analytics['totalClasses'] ?? 0}', Icons.class_, Colors.green),
                _buildStatCard('Avg Attendance', '${analytics['overallAttendance']?.toStringAsFixed(1) ?? 0}%', Icons.analytics, Colors.orange),
                _buildStatCard('Low Attendance', '${analytics['lowAttendanceCount'] ?? 0}', Icons.warning, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendAnalysis(Map<String, dynamic> analytics) {
    final recentTrend = analytics['recentTrend'] as List<Map<String, dynamic>>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Attendance Trend (Last 7 Days)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (recentTrend.isEmpty)
              const Text('No recent attendance data')
            else
              ...recentTrend.map((day) => ListTile(
                leading: Icon(
                  Icons.calendar_today,
                  color: (day['attendanceRate'] ?? 0) >= 75 ? Colors.green : Colors.orange,
                ),
                title: Text(day['date'] ?? ''),
                trailing: Text(
                  '${day['attendanceRate']?.toStringAsFixed(1) ?? 0}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: (day['attendanceRate'] ?? 0) >= 75 ? Colors.green : Colors.orange,
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildClassComparison(Map<String, dynamic> analytics) {
    final classComparison = analytics['classComparison'] as List<Map<String, dynamic>>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Class-wise Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (classComparison.isEmpty)
              const Text('No class data available')
            else
              ...classComparison.map((cls) {
                final rate = cls['attendanceRate'] ?? 0.0;
                final color = rate >= 75 ? Colors.green : rate >= 50 ? Colors.orange : Colors.red;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color,
                    child: Text(
                      cls['name']?.substring(0, 1).toUpperCase() ?? 'C',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text('${cls['name']} - ${cls['subject']}'),
                  subtitle: Text('${cls['totalStudents']} students'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${rate.toStringAsFixed(1)}%',
                        style: TextStyle(fontWeight: FontWeight.bold, color: color),
                      ),
                      Icon(
                        rate >= 75 ? Icons.trending_up : Icons.trending_down,
                        color: color,
                        size: 16,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getAnalyticsData() async {
    // Get all students
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    // Get all classes
    final classesSnapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    // Get all attendance records
    final attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    final totalStudents = studentsSnapshot.docs.length;
    final totalClasses = classesSnapshot.docs.length;

    // Calculate overall attendance
    int totalPresentDays = 0;
    int totalPossibleDays = 0;
    int lowAttendanceCount = 0;

    Map<String, int> studentPresentDays = {};
    Map<String, int> studentTotalDays = {};

    for (var record in attendanceSnapshot.docs) {
      final data = record.data();
      final studentId = data['studentId'];
      final isPresent = data['isPresent'] ?? false;

      studentTotalDays[studentId] = (studentTotalDays[studentId] ?? 0) + 1;
      if (isPresent) {
        studentPresentDays[studentId] = (studentPresentDays[studentId] ?? 0) + 1;
        totalPresentDays++;
      }
      totalPossibleDays++;
    }

    // Count low attendance students
    for (String studentId in studentTotalDays.keys) {
      final present = studentPresentDays[studentId] ?? 0;
      final total = studentTotalDays[studentId] ?? 0;
      if (total > 0 && (present / total) < 0.75) {
        lowAttendanceCount++;
      }
    }

    final overallAttendance = totalPossibleDays > 0 ? (totalPresentDays / totalPossibleDays) * 100 : 0.0;

    // Recent trend (last 7 days)
    final now = DateTime.now();
    List<Map<String, dynamic>> recentTrend = [];
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final dayRecords = attendanceSnapshot.docs.where((doc) => doc.data()['date'] == dateStr);
      int dayPresent = 0;
      int dayTotal = dayRecords.length;
      
      for (var record in dayRecords) {
        if (record.data()['isPresent'] == true) {
          dayPresent++;
        }
      }
      
      final dayRate = dayTotal > 0 ? (dayPresent / dayTotal) * 100 : 0.0;
      
      recentTrend.add({
        'date': dateStr,
        'attendanceRate': dayRate,
      });
    }

    // Class comparison
    List<Map<String, dynamic>> classComparison = [];
    
    for (var classDoc in classesSnapshot.docs) {
      final classData = classDoc.data();
      final classId = classDoc.id;
      
      final classAttendance = attendanceSnapshot.docs.where((doc) => doc.data()['classId'] == classId);
      int classPresent = 0;
      int classTotal = classAttendance.length;
      
      for (var record in classAttendance) {
        if (record.data()['isPresent'] == true) {
          classPresent++;
        }
      }
      
      final classRate = classTotal > 0 ? (classPresent / classTotal) * 100 : 0.0;
      final classStudents = (classData['studentIds'] as List?)?.length ?? 0;
      
      classComparison.add({
        'id': classId,
        'name': classData['name'],
        'subject': classData['subject'],
        'attendanceRate': classRate,
        'totalStudents': classStudents,
      });
    }

    // Sort by attendance rate
    classComparison.sort((a, b) => (b['attendanceRate'] as double).compareTo(a['attendanceRate'] as double));

    return {
      'totalStudents': totalStudents,
      'totalClasses': totalClasses,
      'overallAttendance': overallAttendance,
      'lowAttendanceCount': lowAttendanceCount,
      'recentTrend': recentTrend,
      'classComparison': classComparison,
    };
  }
}
