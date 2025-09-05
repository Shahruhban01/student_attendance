// home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'theme_provider.dart';
import 'account_screen.dart';
import 'classes_screen.dart';
import 'students_screen.dart';
import 'attendance_screen.dart';
import 'reports_screen.dart';
import 'qr_attendance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;
  late AnimationController _fabAnimationController;
  User? user = FirebaseAuth.instance.currentUser;

  final List<Widget> _screens = [
    const DashboardTab(),
    const AttendanceScreen(),
    const ClassesScreen(),
    const StudentsScreen(),
    const ReportsScreen(),
    const AccountScreen(),
  ];

  final List<NavigationItem> _navItems = [
    NavigationItem(icon: Icons.dashboard_rounded, label: 'Home', title: 'BHSS Bomai'),
    NavigationItem(icon: Icons.check_circle_rounded, label: 'Take', title: 'Take Attendance'),
    NavigationItem(icon: Icons.class_, label: 'Classes', title: 'My Classes'),
    NavigationItem(icon: Icons.people_rounded, label: 'Students', title: 'Students'),
    NavigationItem(icon: Icons.analytics_rounded, label: 'Reports', title: 'Reports & Analytics'),
    NavigationItem(icon: Icons.account_circle_rounded, label: 'Account', title: 'My Account'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
    
    // Animate FAB
    _fabAnimationController.reverse().then((_) {
      _fabAnimationController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          _navItems[_selectedIndex].title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // QR Code Quick Access
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const QRAttendanceScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                ),
              );
            },
            icon: const Icon(Icons.qr_code_rounded),
            tooltip: 'QR Attendance',
          ),
          
          // User Avatar
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.indigo,
              backgroundImage: user?.photoURL != null 
                  ? NetworkImage(user!.photoURL!) 
                  : null,
              child: user?.photoURL == null 
                  ? Text(
                      user?.displayName?.substring(0, 1).toUpperCase() ?? 'T',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    )
                  : null,
            ),
          ),
        ],
      ),
body: Column(
  children: [
    Expanded(
      child: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _screens,
      ),
    ),
    const SizedBox(height: 90), // Space for custom navigation bar
  ],
),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 90,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = _selectedIndex == index;
                
                return Expanded(
                  child: InkWell(
                    onTap: () => _onNavTap(index),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.indigo.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.indigo : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.icon,
                              color: isSelected ? Colors.white : Colors.grey[600],
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              color: isSelected ? Colors.indigo : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            child: Text(item.label),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String title;
  
  NavigationItem({
    required this.icon,
    required this.label,
    required this.title,
  });
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return RefreshIndicator(
      onRefresh: () async {
        // Add refresh functionality
        await Future.delayed(const Duration(seconds: 1));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card with enhanced design
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.indigo.shade600,
                    Colors.indigo.shade400,
                    Colors.purple.shade400,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: user?.photoURL != null 
                            ? NetworkImage(user!.photoURL!) 
                            : null,
                        child: user?.photoURL == null 
                            ? Text(
                                user?.displayName?.substring(0, 1).toUpperCase() ?? 'T',
                                style: const TextStyle(color: Colors.white, fontSize: 20),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              user?.displayName ?? 'Teacher',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Quick Stats
            Text(
              'Quick Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
              children: [
                _DashboardCard(
                  title: 'Total Classes',
                  icon: Icons.class_,
                  color: Colors.blue,
                  future: _getTotalClasses(user?.uid ?? ''),
                ),
                _DashboardCard(
                  title: 'Total Students',
                  icon: Icons.people,
                  color: Colors.green,
                  future: _getTotalStudents(user?.uid ?? ''),
                ),
                _DashboardCard(
                  title: 'Today\'s Classes',
                  icon: Icons.today,
                  color: Colors.orange,
                  future: Future.value(0),
                ),
                _DashboardCard(
                  title: 'This Week',
                  icon: Icons.date_range,
                  color: Colors.purple,
                  future: _getWeeklyAttendance(user?.uid ?? ''),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Recent Activity
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildActivityItem(
                      icon: Icons.check_circle,
                      title: 'Attendance Marked',
                      subtitle: 'Mathematics - Class XII',
                      time: '2 hours ago',
                      color: Colors.green,
                    ),
                    const Divider(),
                    _buildActivityItem(
                      icon: Icons.person_add,
                      title: 'New Student Added',
                      subtitle: 'John Doe - Physics Class',
                      time: '1 day ago',
                      color: Colors.blue,
                    ),
                    const Divider(),
                    _buildActivityItem(
                      icon: Icons.analytics,
                      title: 'Report Generated',
                      subtitle: 'Monthly attendance report',
                      time: '2 days ago',
                      color: Colors.purple,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _getTotalClasses(String teacherId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getTotalStudents(String teacherId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getWeeklyAttendance(String teacherId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final startDate = DateFormat('yyyy-MM-dd').format(weekStart);
      final endDate = DateFormat('yyyy-MM-dd').format(now);
      
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('teacherId', isEqualTo: teacherId)
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .where('isPresent', isEqualTo: true)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Future<int> future;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            FutureBuilder<int>(
              future: future,
              builder: (context, snapshot) {
                return Text(
                  '${snapshot.data ?? 0}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
