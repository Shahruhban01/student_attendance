// students_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String selectedClassFilter = 'All';
  List<Map<String, dynamic>> classes = [];

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Filter by class
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Filter by class: '),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedClassFilter,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: 'All', child: Text('All Students')),
                      ...classes.map((cls) => DropdownMenuItem(
                        value: cls['id'],
                        child: Text(cls['name']),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedClassFilter = value ?? 'All';
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          // Students list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getStudentsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final students = snapshot.data?.docs ?? [];

                if (students.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No students yet', style: TextStyle(fontSize: 18)),
                        SizedBox(height: 8),
                        Text('Tap + to add your first student'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final studentData = students[index].data() as Map<String, dynamic>;
                    final studentClasses = _getStudentClasses(studentData['classIds'] as List?);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Text(
                            studentData['name']?.substring(0, 1).toUpperCase() ?? 'S',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(studentData['name'] ?? 'Unnamed Student'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Roll: ${studentData['rollNumber'] ?? 'N/A'}'),
                            Text('Email: ${studentData['email'] ?? 'N/A'}'),
                            if (studentClasses.isNotEmpty)
                              Text('Classes: ${studentClasses.join(', ')}'),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'assign', child: Text('Assign Classes')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _showEditStudentDialog(students[index].id, studentData);
                                break;
                              case 'assign':
                                _showAssignClassesDialog(students[index].id, studentData);
                                break;
                              case 'delete':
                                _deleteStudent(students[index].id);
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStudentDialog(),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Stream<QuerySnapshot> _getStudentsStream() {
    Query query = FirebaseFirestore.instance
        .collection('students')
        .where('teacherId', isEqualTo: user?.uid);

    if (selectedClassFilter != 'All') {
      query = query.where('classIds', arrayContains: selectedClassFilter);
    }

    return query.snapshots();
  }

  List<String> _getStudentClasses(List? classIds) {
    if (classIds == null) return [];
    return classes
        .where((cls) => classIds.contains(cls['id']))
        .map((cls) => cls['name'] as String)
        .toList();
  }

  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final rollController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Student Name'),
            ),
            TextField(
              controller: rollController,
              decoration: const InputDecoration(labelText: 'Roll Number'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _addStudent(
              nameController.text,
              rollController.text,
              emailController.text,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditStudentDialog(String studentId, Map<String, dynamic> studentData) {
    final nameController = TextEditingController(text: studentData['name']);
    final rollController = TextEditingController(text: studentData['rollNumber']);
    final emailController = TextEditingController(text: studentData['email']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Student Name'),
            ),
            TextField(
              controller: rollController,
              decoration: const InputDecoration(labelText: 'Roll Number'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _updateStudent(
              studentId,
              nameController.text,
              rollController.text,
              emailController.text,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showAssignClassesDialog(String studentId, Map<String, dynamic> studentData) {
    List<String> selectedClasses = List<String>.from(studentData['classIds'] ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Assign Classes to ${studentData['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: classes.map((cls) {
              final isSelected = selectedClasses.contains(cls['id']);
              return CheckboxListTile(
                title: Text(cls['name']),
                subtitle: Text(cls['subject']),
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      selectedClasses.add(cls['id']);
                    } else {
                      selectedClasses.remove(cls['id']);
                    }
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _assignClassesToStudent(studentId, selectedClasses),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addStudent(String name, String rollNumber, String email) async {
    if (name.isEmpty || rollNumber.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('students').add({
        'name': name,
        'rollNumber': rollNumber,
        'email': email,
        'teacherId': user?.uid,
        'classIds': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _updateStudent(String studentId, String name, String rollNumber, String email) async {
    try {
      await FirebaseFirestore.instance.collection('students').doc(studentId).update({
        'name': name,
        'rollNumber': rollNumber,
        'email': email,
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _assignClassesToStudent(String studentId, List<String> classIds) async {
    try {
      await FirebaseFirestore.instance.collection('students').doc(studentId).update({
        'classIds': classIds,
      });

      // Update class documents to include this student
      for (String classId in classIds) {
        await FirebaseFirestore.instance.collection('classes').doc(classId).update({
          'studentIds': FieldValue.arrayUnion([studentId]),
        });
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Classes assigned successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteStudent(String studentId) async {
    try {
      await FirebaseFirestore.instance.collection('students').doc(studentId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
