// models/student.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String id;
  final String name;
  final String rollNumber;
  final String email;
  final String teacherId;
  final List<String> classIds;
  final DateTime createdAt;

  Student({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.email,
    required this.teacherId,
    required this.classIds,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rollNumber': rollNumber,
      'email': email,
      'teacherId': teacherId,
      'classIds': classIds,
      'createdAt': createdAt,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      rollNumber: map['rollNumber'] ?? '',
      email: map['email'] ?? '',
      teacherId: map['teacherId'] ?? '',
      classIds: List<String>.from(map['classIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
