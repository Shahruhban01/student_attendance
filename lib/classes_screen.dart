// classes_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:student_attendance/services/export_service.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  final user = FirebaseAuth.instance.currentUser;

  void _showEditClassDialog(String classId, Map<String, dynamic> classData) {
  final nameController = TextEditingController(text: classData['name']);
  final subjectController = TextEditingController(text: classData['subject']);
  final scheduleController = TextEditingController(text: classData['schedule']);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Class'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Class Name'),
          ),
          TextField(
            controller: subjectController,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          TextField(
            controller: scheduleController,
            decoration: const InputDecoration(labelText: 'Schedule'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _updateClass(
            classId,
            nameController.text,
            subjectController.text,
            scheduleController.text,
          ),
          child: const Text('Update'),
        ),
      ],
    ),
  );
}

Future<void> _updateClass(String classId, String name, String subject, String schedule) async {
  if (name.isEmpty || subject.isEmpty) return;

  try {
    await FirebaseFirestore.instance.collection('classes').doc(classId).update({
      'name': name,
      'subject': subject,
      'schedule': schedule,
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Class updated successfully')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classes')
            .where('teacherId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final classes = snapshot.data?.docs ?? [];

          if (classes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.class_, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No classes yet', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Tap + to add your first class'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final classData = classes[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Text(
                      classData['name']?.substring(0, 1).toUpperCase() ?? 'C',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(classData['name'] ?? 'Unnamed Class'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subject: ${classData['subject'] ?? 'No subject'}'),
                      Text(
                        'Students: ${(classData['studentIds'] as List?)?.length ?? 0}',
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'export_students',
                        child: Text('Export Students'),
                      ),
                      const PopupMenuItem(
                        value: 'export_attendance',
                        child: Text('Export Attendance'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          // Add edit functionality here if needed
                          _showEditClassDialog(classes[index].id, classData);
                          break;
                        case 'export_students':
                          try {
                            await ExportService.exportStudentList(
                              user?.uid ?? '',
                              classes[index].id,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Student list exported successfully',
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Export failed: $e')),
                            );
                          }
                          break;
                        case 'export_attendance':
                          try {
                            await ExportService.exportAttendanceReport(
                              user?.uid ?? '',
                              classes[index].id,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Attendance report exported successfully',
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Export failed: $e')),
                            );
                          }
                          break;
                        case 'delete':
                          _deleteClass(classes[index].id);
                          break;
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddClassDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddClassDialog() {
    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    final scheduleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Class Name'),
            ),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            TextField(
              controller: scheduleController,
              decoration: const InputDecoration(labelText: 'Schedule'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _addClass(
              nameController.text,
              subjectController.text,
              scheduleController.text,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addClass(String name, String subject, String schedule) async {
    if (name.isEmpty || subject.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('classes').add({
        'name': name,
        'subject': subject,
        'schedule': schedule,
        'teacherId': user?.uid,
        'studentIds': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Class added successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteClass(String classId) async {
    try {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Class deleted')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
