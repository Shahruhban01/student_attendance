// models/attendance.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final String classId;
  final String studentId;
  final DateTime date;
  final bool isPresent;
  final String? remarks;
  final DateTime markedAt;

  AttendanceRecord({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.date,
    required this.isPresent,
    this.remarks,
    required this.markedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classId': classId,
      'studentId': studentId,
      'date': date,
      'isPresent': isPresent,
      'remarks': remarks,
      'markedAt': markedAt,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] ?? '',
      classId: map['classId'] ?? '',
      studentId: map['studentId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      isPresent: map['isPresent'] ?? false,
      remarks: map['remarks'],
      markedAt: (map['markedAt'] as Timestamp).toDate(),
    );
  }
}
