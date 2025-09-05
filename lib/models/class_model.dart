// models/class_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String name;
  final String subject;
  final String teacherId;
  final List<String> studentIds;
  final String schedule; // e.g., "Mon, Wed, Fri 10:00-11:00"
  final DateTime createdAt;

  ClassModel({
    required this.id,
    required this.name,
    required this.subject,
    required this.teacherId,
    required this.studentIds,
    required this.schedule,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'teacherId': teacherId,
      'studentIds': studentIds,
      'schedule': schedule,
      'createdAt': createdAt,
    };
  }

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      subject: map['subject'] ?? '',
      teacherId: map['teacherId'] ?? '',
      studentIds: List<String>.from(map['studentIds'] ?? []),
      schedule: map['schedule'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
