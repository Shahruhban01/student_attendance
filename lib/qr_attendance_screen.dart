// qr_attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class QRAttendanceScreen extends StatefulWidget {
  const QRAttendanceScreen({super.key});

  @override
  State<QRAttendanceScreen> createState() => _QRAttendanceScreenState();
}

class _QRAttendanceScreenState extends State<QRAttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Attendance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: 'Generate QR'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          QRGeneratorTab(teacherId: user?.uid ?? ''),
          QRScannerTab(teacherId: user?.uid ?? ''),
        ],
      ),
    );
  }
}

class QRGeneratorTab extends StatefulWidget {
  final String teacherId;

  const QRGeneratorTab({super.key, required this.teacherId});

  @override
  State<QRGeneratorTab> createState() => _QRGeneratorTabState();
}

class _QRGeneratorTabState extends State<QRGeneratorTab> {
  String? selectedClassId;
  List<Map<String, dynamic>> classes = [];
  String? qrData;
  DateTime selectedDate = DateTime.now();

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
        ...doc.data()
      }).toList();
      
      if (classes.isNotEmpty && selectedClassId == null) {
        selectedClassId = classes.first['id'];
        _generateQR();
      }
    });
  }

  void _generateQR() {
    if (selectedClassId == null) return;

    final qrPayload = {
      'classId': selectedClassId,
      'teacherId': widget.teacherId,
      'date': DateFormat('yyyy-MM-dd').format(selectedDate),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    setState(() {
      qrData = jsonEncode(qrPayload);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Class Selection
          if (classes.isNotEmpty)
            DropdownButton<String>(
              value: selectedClassId,
              isExpanded: true,
              hint: const Text('Select Class'),
              items: classes.map((cls) => DropdownMenuItem<String>(
                value: cls['id'] as String,
                child: Text('${cls['name']} - ${cls['subject']}'),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  selectedClassId = value;
                  _generateQR();
                });
              },
            ),
          const SizedBox(height: 16),

          // Date Selection
          ListTile(
            title: const Text('Date'),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 7)),
              );
              if (picked != null && picked != selectedDate) {
                setState(() {
                  selectedDate = picked;
                  _generateQR();
                });
              }
            },
          ),
          const SizedBox(height: 32),

          // QR Code Display
          if (qrData != null) ...[
            const Text(
              'Students can scan this QR code to mark attendance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: qrData!,
                version: QrVersions.auto,
                size: 250.0,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generateQR,
              icon: const Icon(Icons.refresh),
              label: const Text('Generate New QR Code'),
            ),
          ] else if (classes.isEmpty) ...[
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.class_, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No classes available'),
                  SizedBox(height: 8),
                  Text('Create classes first to generate QR codes'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class QRScannerTab extends StatefulWidget {
  final String teacherId;

  const QRScannerTab({super.key, required this.teacherId});

  @override
  State<QRScannerTab> createState() => _QRScannerTabState();
}

class _QRScannerTabState extends State<QRScannerTab> {
  MobileScannerController cameraController = MobileScannerController();
  bool isProcessing = false;
  bool flashOn = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              MobileScanner(
                controller: cameraController,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (!isProcessing && barcodes.isNotEmpty) {
                    final String? code = barcodes.first.rawValue;
                    if (code != null) {
                      _processQRData(code);
                    }
                  }
                },
              ),
              // Scanning overlay - simplified version
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.transparent),
                ),
                child: Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isProcessing)
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Processing attendance...'),
                    ],
                  )
                else
                  const Text(
                    'Point camera at QR code to scan',
                    style: TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton.filled(
                      onPressed: () {
                        cameraController.toggleTorch();
                        setState(() {
                          flashOn = !flashOn;
                        });
                      },
                      icon: Icon(
                        flashOn ? Icons.flash_on : Icons.flash_off,
                        color: flashOn ? Colors.yellow : Colors.grey,
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () => cameraController.switchCamera(),
                      icon: const Icon(Icons.camera_front),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _processQRData(String qrData) async {
    if (isProcessing) return;
    
    setState(() {
      isProcessing = true;
    });

    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      final classId = data['classId'];
      final teacherId = data['teacherId'];
      final date = data['date'];
      final timestamp = data['timestamp'];

      // Verify the QR code is not too old (e.g., 1 hour)
      final qrTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(qrTime).inHours > 1) {
        if (mounted) {
          _showMessage('QR Code expired. Please ask teacher for a new one.');
        }
        return;
      }

      // Show dialog for student to enter their details
      if (mounted) {
        _showStudentIdentificationDialog(classId, teacherId, date);
      }

    } catch (e) {
      if (mounted) {
        _showMessage('Invalid QR Code');
      }
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  void _showStudentIdentificationDialog(String classId, String teacherId, String date) {
    final rollController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your roll number:'),
            const SizedBox(height: 8),
            TextField(
              controller: rollController,
              decoration: const InputDecoration(labelText: 'Roll Number'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _markAttendance(classId, rollController.text, date),
            child: const Text('Mark Present'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAttendance(String classId, String rollNumber, String date) async {
    if (rollNumber.trim().isEmpty) {
      _showMessage('Please enter roll number');
      return;
    }

    try {
      // Find student by roll number and class
      final studentQuery = await FirebaseFirestore.instance
          .collection('students')
          .where('rollNumber', isEqualTo: rollNumber.trim())
          .where('classIds', arrayContains: classId)
          .get();

      if (studentQuery.docs.isEmpty) {
        _showMessage('Student not found in this class');
        return;
      }

      final studentId = studentQuery.docs.first.id;
      final studentName = studentQuery.docs.first.data()['name'] ?? 'Unknown';
      final attendanceId = '${classId}_${studentId}_$date';

      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(attendanceId)
          .set({
        'classId': classId,
        'studentId': studentId,
        'date': date,
        'isPresent': true,
        'markedAt': FieldValue.serverTimestamp(),
        'markedViaQR': true,
        'teacherId': widget.teacherId,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        _showMessage('Attendance marked for $studentName!');
      }

    } catch (e) {
      if (mounted) {
        _showMessage('Error marking attendance: $e');
      }
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
