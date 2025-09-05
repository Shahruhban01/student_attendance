// services/export_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  static Future<void> exportAttendanceReport(String teacherId, String classId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      startDate ??= DateTime.now().subtract(const Duration(days: 30));
      endDate ??= DateTime.now();

      // Get class info
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();
      final classData = classDoc.data() ?? {};

      // Get students
      final studentsQuery = await FirebaseFirestore.instance
          .collection('students')
          .where('classIds', arrayContains: classId)
          .get();

      // Get attendance records
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate))
          .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate))
          .get();

      // Process data
      List<List<dynamic>> csvData = [];
      
      // Header row
      List<String> headers = ['Student Name', 'Roll Number'];
      Set<String> dates = {};
      
      for (var record in attendanceQuery.docs) {
        dates.add(record.data()['date']);
      }
      
      List<String> sortedDates = dates.toList()..sort();
      headers.addAll(sortedDates);
      headers.add('Total Present');
      headers.add('Total Days');
      headers.add('Attendance %');
      csvData.add(headers);

      // Student rows
      for (var studentDoc in studentsQuery.docs) {
        final studentData = studentDoc.data();
        List<dynamic> row = [
          studentData['name'] ?? '',
          studentData['rollNumber'] ?? '',
        ];

        int totalPresent = 0;
        for (String date in sortedDates) {
          final attendance = attendanceQuery.docs
              .where((doc) => doc.data()['studentId'] == studentDoc.id && doc.data()['date'] == date)
              .firstOrNull;
          
          final isPresent = attendance?.data()['isPresent'] ?? false;
          row.add(isPresent ? 'P' : 'A');
          if (isPresent) totalPresent++;
        }

        row.add(totalPresent);
        row.add(sortedDates.length);
        row.add(sortedDates.isNotEmpty ? '${((totalPresent / sortedDates.length) * 100).toStringAsFixed(1)}%' : '0%');
        
        csvData.add(row);
      }

      // Create CSV content
      String csvContent = csvData.map((row) => row.join(',')).join('\n');

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'attendance_${classData['name']}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvContent);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance Report for ${classData['name']}',
      );

    } catch (e) {
      throw Exception('Failed to export report: $e');
    }
  }

  static Future<void> exportStudentList(String teacherId, String classId) async {
    try {
      // Get class info
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();
      final classData = classDoc.data() ?? {};

      // Get students
      final studentsQuery = await FirebaseFirestore.instance
          .collection('students')
          .where('classIds', arrayContains: classId)
          .get();

      // Create CSV content
      List<List<dynamic>> csvData = [
        ['Name', 'Roll Number', 'Email', 'Date Added']
      ];

      for (var studentDoc in studentsQuery.docs) {
        final studentData = studentDoc.data();
        csvData.add([
          studentData['name'] ?? '',
          studentData['rollNumber'] ?? '',
          studentData['email'] ?? '',
          studentData['createdAt'] != null 
              ? DateFormat('yyyy-MM-dd').format((studentData['createdAt'] as Timestamp).toDate())
              : '',
        ]);
      }

      String csvContent = csvData.map((row) => row.join(',')).join('\n');

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'students_${classData['name']}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvContent);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Student List for ${classData['name']}',
      );

    } catch (e) {
      throw Exception('Failed to export student list: $e');
    }
  }
}
