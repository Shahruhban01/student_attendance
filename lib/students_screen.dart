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

  String? _lastSelectedClassId;

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
      classes = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
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
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text(
                  'Filter by class: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedClassFilter,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(
                          value: 'All',
                          child: Text(
                            'All Students',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        ...classes.map(
                          (cls) => DropdownMenuItem(
                            value: cls['id'],
                            child: Text('${cls['name']} - ${cls['subject']}'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedClassFilter = value ?? 'All';
                        });
                      },
                    ),
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.people_outline,
                            size: 48,
                            color: Colors.indigo.shade400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No students yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the + button to add your first student',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final studentData =
                        students[index].data() as Map<String, dynamic>;
                    final studentClasses = _getStudentClasses(
                      studentData['classIds'] as List?,
                    );

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Hero(
                          tag: 'student_${students[index].id}',
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.indigo,
                            child: Text(
                              studentData['name']
                                      ?.substring(0, 1)
                                      .toUpperCase() ??
                                  'S',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          studentData['name'] ?? 'Unnamed Student',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Roll: ${studentData['rollNumber'] ?? 'N/A'}',
                                    style: TextStyle(
                                      color: Colors.indigo.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (studentData['phoneNumber']?.isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 4),
                              Text(
                                studentData['phoneNumber'],
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (studentClasses.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                children: studentClasses
                                    .map(
                                      (className) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          className,
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Edit'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'assign',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.class_,
                                    size: 18,
                                    color: Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Assign Classes'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _showEditStudentDialog(
                                  students[index].id,
                                  studentData,
                                );
                                break;
                              case 'assign':
                                _showAssignClassesDialog(
                                  students[index].id,
                                  studentData,
                                );
                                break;
                              case 'delete':
                                _deleteStudent(
                                  students[index].id,
                                  studentData['name'] ?? 'Student',
                                );
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStudentDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  Stream<QuerySnapshot> _getStudentsStream() {
    Query query = FirebaseFirestore.instance
        .collection('students')
        .where('teacherId', isEqualTo: user?.uid)
        .orderBy('rollNumber');

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

  // ENHANCED ADD STUDENT DIALOG - WITH CLASS DROPDOWN & PHONE NUMBER
  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final rollController = TextEditingController();
    final phoneController = TextEditingController();

    // Prefill with previously selected class or first available class
    String? selectedClassId =
        _lastSelectedClassId ??
        (classes.isNotEmpty ? classes.first['id'] : null);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setState) {
          bool isLoading = false;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person_add,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add New Student',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Fill in the details below',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Form Fields
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Student Name *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      enabled: !isLoading,
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: rollController,
                      decoration: InputDecoration(
                        labelText: 'Roll Number *',
                        prefixIcon: const Icon(Icons.numbers),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !isLoading,
                    ),

                    const SizedBox(height: 16),

                    // Class Dropdown
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                        color: Colors.grey.shade50,
                      ),
                      child: DropdownButtonFormField<String>(
                        value: selectedClassId,
                        decoration: const InputDecoration(
                          labelText: 'Select Class *',
                          prefixIcon: Icon(Icons.class_),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        items: classes.isEmpty
                            ? [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('No classes available'),
                                ),
                              ]
                            : classes.map<DropdownMenuItem<String>>((cls) {
                                return DropdownMenuItem<String>(
                                  value: cls['id'],
                                  child: Text(
                                    '${cls['name']} - ${cls['subject']}',
                                  ),
                                );
                              }).toList(),
                        onChanged: isLoading || classes.isEmpty
                            ? null
                            : (String? newValue) {
                                setState(() {
                                  selectedClassId = newValue;
                                });
                              },
                        hint: const Text('Choose a class for the student'),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      keyboardType: TextInputType.phone,
                      enabled: !isLoading,
                    ),

                    const SizedBox(height: 8),
                    Text(
                      '* Required fields',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isLoading
                                ? null
                                : () => Navigator.of(ctx).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    setState(() {
                                      isLoading = true;
                                    });

                                    await _addStudentAndContinue(
                                      ctx,
                                      setState,
                                      nameController,
                                      rollController,
                                      phoneController,
                                      selectedClassId,
                                    );

                                    setState(() {
                                      isLoading = false;
                                    });
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_circle_outline, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Add Student',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<int> _getNextRollNumber() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('teacherId', isEqualTo: user?.uid)
          .get();

      if (snapshot.docs.isEmpty) return 1;

      // Find the highest roll number
      int maxRoll = 0;
      for (var doc in snapshot.docs) {
        final rollStr = doc.data()['rollNumber'] as String?;
        final roll = int.tryParse(rollStr ?? '0') ?? 0;
        if (roll > maxRoll) maxRoll = roll;
      }

      return maxRoll + 1;
    } catch (e) {
      return 1;
    }
  }

  Future<void> _addStudentAndContinue(
    BuildContext ctx,
    StateSetter setState,
    TextEditingController nameController,
    TextEditingController rollController,
    TextEditingController phoneController,
    String? selectedClassId,
  ) async {
    final name = nameController.text.trim();
    final rollNumber = rollController.text.trim();
    final phoneNumber = phoneController.text.trim();

    if (name.isEmpty || rollNumber.isEmpty || selectedClassId == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Name, Roll Number, and Class are required'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('students').add({
        'name': name,
        'rollNumber': rollNumber,
        'phoneNumber': phoneNumber,
        'teacherId': user?.uid,
        'classIds': [selectedClassId], // Assign to selected class
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update the class document to include this student
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(selectedClassId)
          .update({
            'studentIds': FieldValue.arrayUnion([
              'temp_id',
            ]), // We'll update this with actual ID
          });

      // Remember the selected class for next time
      _lastSelectedClassId = selectedClassId;

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('$name added successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });

      // Increment roll number and clear other fields
      final currentRoll = int.tryParse(rollNumber) ?? 0;
      final nextRoll = currentRoll + 1;

      setState(() {
        nameController.clear();
        phoneController.clear();
        rollController.text = nextRoll.toString();
        // Keep the same class selected for next student
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(ctx).requestFocus(FocusNode());
        }
      });
    } catch (e) {
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Error adding student: $e'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  // EXISTING METHODS (Enhanced with better UI)
  void _showEditStudentDialog(
    String studentId,
    Map<String, dynamic> studentData,
  ) {
    final nameController = TextEditingController(text: studentData['name']);
    final rollController = TextEditingController(
      text: studentData['rollNumber']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: studentData['phoneNumber'],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Student Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: rollController,
              decoration: const InputDecoration(
                labelText: 'Roll Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
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
              phoneController.text,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStudent(
    String studentId,
    String name,
    String rollNumber,
    String phoneNumber,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .update({
            'name': name,
            'rollNumber': rollNumber,
            'phoneNumber': phoneNumber,
          });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showAssignClassesDialog(
    String studentId,
    Map<String, dynamic> studentData,
  ) {
    List<String> selectedClasses = List<String>.from(
      studentData['classIds'] ?? [],
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Assign Classes to ${studentData['name']}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  _assignClassesToStudent(studentId, selectedClasses),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  // Future<void> _updateStudent(
  //   String studentId,
  //   String name,
  //   String rollNumber,
  //   String email,
  // ) async {
  //   try {
  //     await FirebaseFirestore.instance
  //         .collection('students')
  //         .doc(studentId)
  //         .update({'name': name, 'rollNumber': rollNumber, 'email': email});
  //     Navigator.pop(context);
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Student updated successfully'),
  //         backgroundColor: Colors.green,
  //       ),
  //     );
  //   } catch (e) {
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text('Error: $e')));
  //   }
  // }

  Future<void> _assignClassesToStudent(
    String studentId,
    List<String> classIds,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .update({'classIds': classIds});

      // Update class documents to include this student
      for (String classId in classIds) {
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .update({
              'studentIds': FieldValue.arrayUnion([studentId]),
            });
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Classes assigned successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteStudent(String studentId, String studentName) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Student'),
        content: Text(
          'Are you sure you want to delete "$studentName"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Student "$studentName" deleted'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
