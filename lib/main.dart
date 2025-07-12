import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'ai_config.dart';
import 'dart:async';

// Notification Service
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    _initialized = true;
  }

  static Future<bool> requestPermissions() async {
    if (!_initialized) await initialize();
    // Android permissions are handled by the OS or use permission_handler for Android 13+
    return true; // iOS permissions are handled during initialization
  }

  static Future<void> scheduleBedtimeReminder(TimeOfDay targetBedtime) async {
    if (!_initialized) await initialize();
    
    // Calculate reminder time (30 minutes before bedtime)
    final now = DateTime.now();
    final bedtimeDateTime = DateTime(now.year, now.month, now.day, targetBedtime.hour, targetBedtime.minute);
    final reminderTime = bedtimeDateTime.subtract(const Duration(minutes: 30));
    
    // If the reminder time has passed today, schedule for tomorrow
    final scheduledTime = reminderTime.isBefore(now) 
        ? reminderTime.add(const Duration(days: 1))
        : reminderTime;

    await _notifications.zonedSchedule(
      3, // Bedtime reminder ID
      'Sleep Fixer AI',
      'Time to start winding down! 🌙 Your target bedtime is in 30 minutes.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sleep_bedtime_reminder',
          'Bedtime Reminder',
          channelDescription: 'Daily bedtime reminder',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleMorningCheckIn(TimeOfDay wakeUpTime) async {
    if (!_initialized) await initialize();
    
    // Schedule notification 30 minutes after wake up time
    final now = DateTime.now();
    final wakeUpDateTime = DateTime(now.year, now.month, now.day, wakeUpTime.hour, wakeUpTime.minute);
    final notificationTime = wakeUpDateTime.add(const Duration(minutes: 30));
    
    // If the time has passed today, schedule for tomorrow
    final scheduledTime = notificationTime.isBefore(now) 
        ? notificationTime.add(const Duration(days: 1))
        : notificationTime;

    await _notifications.zonedSchedule(
      1, // Morning check-in ID
      'Sleep Fixer AI',
      'How did your sleep go last night? 🌅',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sleep_morning_checkin',
          'Morning Check-in',
          channelDescription: 'Daily morning sleep progress check-in',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleWeeklyReport() async {
    if (!_initialized) await initialize();
    
    // Schedule for Sunday at 9 AM
    final now = DateTime.now();
    final nextSunday = now.add(Duration(days: (7 - now.weekday) % 7));
    final scheduledTime = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 9, 0);
    
    await _notifications.zonedSchedule(
      2, // Weekly report ID
      'Sleep Fixer AI',
      'Your weekly sleep report is ready! 📊',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sleep_weekly_report',
          'Weekly Report',
          channelDescription: 'Weekly sleep progress report',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelAllNotifications() async {
    if (!_initialized) await initialize();
    await _notifications.cancelAll();
  }

  static Future<void> showPersonalizedNotification(String title, String body, {int id = 0}) async {
    if (!_initialized) await initialize();
    
    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sleep_personalized',
          'Personalized Sleep Tips',
          channelDescription: 'AI-generated personalized sleep advice',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

// AI Notification Text Generator
class AINotificationGenerator {
  static final math.Random _random = math.Random();
  
  static String getMorningCheckInText(SleepProgress? lastNight, int streak) {
    if (lastNight == null) {
      return _getRandomText([
        "Good morning! 🌅 How did your sleep go last night? Tracking helps identify patterns.",
        "Rise and shine! ☀️ Ready to assess your sleep progress?",
        "Morning! 🌟 Let's see how well you stuck to your sleep plan today.",
        "Good morning! 🌙 How was your bedtime last night? Every night counts.",
      ]);
    }

    switch (lastNight.status) {
      case ProgressStatus.onTarget:
        return _getRandomText([
          "Excellent! 🌟 You hit your target bedtime. Consistency like this builds lasting sleep habits.",
          "Perfect timing! ✨ Your circadian rhythm is responding well to this schedule.",
          "Outstanding! 💤 You're demonstrating excellent sleep discipline. Keep this up!",
          "Impressive! 🎯 You're showing real commitment to your sleep health.",
        ]);
      
      case ProgressStatus.within30Min:
        return _getRandomText([
          "Great progress! ⏰ You're very close to your target. Small adjustments will get you there.",
          "Almost perfect! 🌙 Being within 30 minutes shows good consistency. You're on the right track.",
          "Solid work! ✨ You're building the foundation for better sleep habits.",
          "Well done! 💪 You're showing real commitment to improving your sleep schedule.",
        ]);
      
      case ProgressStatus.within1Hour:
        return _getRandomText([
          "Good effort! 🌅 You're making progress toward your goal. Every step counts.",
          "You're getting there! ⏰ Within an hour shows you're working on consistency.",
          "Keep going! 💤 You're building awareness of your sleep patterns.",
          "Stay focused! ✨ Progress takes time, and you're moving in the right direction.",
        ]);
      
      case ProgressStatus.offTarget:
        return _getRandomText([
          "Don't worry! 🌅 Every day offers a fresh opportunity. Focus on tonight's goal.",
          "It happens! 🌙 Life can disrupt sleep schedules. Tomorrow is a new chance to improve.",
          "Stay positive! ⭐ Setbacks are part of the learning process. You can do this!",
          "Fresh start! 🌟 Yesterday's challenges don't define today's success.",
        ]);
      
      case ProgressStatus.notTracked:
        return _getRandomText([
          "Good morning! 🌅 How did your sleep go last night? Tracking helps identify patterns.",
          "Rise and shine! ☀️ Ready to assess your sleep progress?",
          "Morning! 🌟 Let's see how well you stuck to your sleep plan today.",
          "Good morning! 🌙 How was your bedtime last night? Every night counts.",
        ]);
    }
  }

  static Future<String> getWeeklyReportText(List<SleepProgress> weekProgress) async {
    return "Hey! How's your week going? 💫";
  }

  static Future<void> showPersonalizedMorningNotification(SleepProgress? lastNight, int streak) async {
    final message = getMorningCheckInText(lastNight, streak);
    await NotificationService.showPersonalizedNotification(
      'Sleep Fixer AI',
      message,
      id: 10, // Unique ID for morning notifications
    );
  }

  static Future<void> showPersonalizedWeeklyNotification(List<SleepProgress> weekProgress) async {
    await NotificationService.showPersonalizedNotification(
      'Sleep Fixer AI',
      "Hey! How's your week going? 💫",
      id: 11, // Unique ID for weekly notifications
    );
  }

  static String _getRandomText(List<String> options) {
    return options[_random.nextInt(options.length)];
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone data
  tz.initializeTimeZones();
  
  // Initialize services
  await ProgressTrackingService.initialize();
  await NotificationService.initialize();
  
  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
  runApp(MyRootApp(hasSeenOnboarding: hasSeenOnboarding));
}

class MyRootApp extends StatelessWidget {
  final bool hasSeenOnboarding;
  const MyRootApp({super.key, required this.hasSeenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sleep Fixer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: hasSeenOnboarding ? SplashScreen() : OnboardingScreen(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sleep Fixer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MyApp()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/sleep_fixer_background.png', width: 120, height: 120),
            const SizedBox(height: 24),
            const Text(
              'Sleep Fixer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _pageIndex = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Welcome to Sleep Fixer!',
      'desc': 'Let\'s fix your sleep schedule together. Get ready for better nights and brighter days! 😴',
    },
    {
      'title': 'How it Works',
      'desc': 'We\'ll help you shift your bedtime gradually, track your progress, and keep you motivated with AI tips.',
    },
    {
      'title': 'Get Started',
      'desc': 'Create your personalized sleep plan and start your journey to better sleep! 💫',
    },
  ];

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _pageIndex = i),
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (i == 0)
                          Image.asset('assets/sleep_fixer_background.png', width: 100, height: 100),
                        const SizedBox(height: 32),
                        Text(
                          _pages[i]['title']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _pages[i]['desc']!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _pageIndex == i ? Colors.white : Colors.white24,
                  shape: BoxShape.circle,
                ),
              )),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_pageIndex < _pages.length - 1)
                    TextButton(
                      onPressed: _finishOnboarding,
                      child: const Text('Skip', style: TextStyle(color: Colors.white70)),
                    ),
                  if (_pageIndex == _pages.length - 1)
                    const SizedBox(width: 64),
                  ElevatedButton(
                    onPressed: _pageIndex == _pages.length - 1
                        ? _finishOnboarding
                        : () => _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text(_pageIndex == _pages.length - 1 ? 'Done' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool planCreated = false; // Track if plan has been created
  TimeOfDay? currentSleepTime; // Store plan data
  TimeOfDay? goalSleepTime;
  bool? use30MinuteShifts;

  final List<Widget> _screens = [
    const FullPlanScreen(),
    const ProfileScreen(),
  ];

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return FullPlanScreen(
          currentSleepTime: currentSleepTime,
          goalSleepTime: goalSleepTime,
          use30MinuteShifts: use30MinuteShifts,
        );
      case 1:
        return AIChatScreen(
          currentSleepTime: currentSleepTime ?? const TimeOfDay(hour: 23, minute: 0),
          goalSleepTime: goalSleepTime ?? const TimeOfDay(hour: 22, minute: 0),
        );
      case 2:
        return const ProfileScreen();
      default:
        return const FullPlanScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/sleep_fixer_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _currentIndex == 0 
                  ? (planCreated ? DashboardScreen(
                      currentSleepTime: currentSleepTime!,
                      goalSleepTime: goalSleepTime!,
                      use30MinuteShifts: use30MinuteShifts!,
                    ) : SleepShiftScreen(
                      onPlanCreated: (current, goal, use30Min) {
                        setState(() {
                          planCreated = true;
                          currentSleepTime = current;
                          goalSleepTime = goal;
                          use30MinuteShifts = use30Min;
                        });
                      },
                    ))
                  : _getScreen(_currentIndex - 1),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  selectedItemColor: Colors.indigo,
                  unselectedItemColor: Colors.grey,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.bedtime),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.calendar_today),
                      label: 'View Full Plan',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.nightlight),
                      label: 'Sleep Fixer AI',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.person),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Full Plan Screen
class FullPlanScreen extends StatefulWidget {
  final TimeOfDay? currentSleepTime;
  final TimeOfDay? goalSleepTime;
  final bool? use30MinuteShifts;

  const FullPlanScreen({
    super.key,
    this.currentSleepTime,
    this.goalSleepTime,
    this.use30MinuteShifts,
  });

  @override
  State<FullPlanScreen> createState() => _FullPlanScreenState();
}

class _FullPlanScreenState extends State<FullPlanScreen> {
  late List<bool> _dayCompleted;
  late List<bool> _reminderEnabled;
  late List<Map<String, dynamic>> _planDays;
  late Set<DateTime> _daysOff;

  bool _planInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_planInitialized) {
      _daysOff = {};
      _calculatePlan();
      _planInitialized = true;
    }
  }

  void _calculatePlan() {
    // Check if plan data is available
    if (widget.currentSleepTime == null || widget.goalSleepTime == null || widget.use30MinuteShifts == null) {
      // Initialize with default values if no plan
      _dayCompleted = [];
      _reminderEnabled = [];
      _planDays = [];
      return;
    }
    
    int currentMinutes = widget.currentSleepTime!.hour * 60 + widget.currentSleepTime!.minute;
    int goalMinutes = widget.goalSleepTime!.hour * 60 + widget.goalSleepTime!.minute;
    
    int difference = currentMinutes - goalMinutes;
    if (difference < 0) {
      difference += 24 * 60; // Add 24 hours if goal is earlier
    }
    
    // Smart shift size calculation
    int shiftSize;
    if (difference <= 60) {
      shiftSize = 15;
    } else if (difference <= 180) {
      shiftSize = 20;
    } else {
      shiftSize = 30;
    }
    int daysPerShift = difference <= 120 ? 1 : 2;
    
    // Initialize state lists
    _planDays = [];
    _dayCompleted = [];
    _reminderEnabled = [];
    DateTime startDate = DateTime.now();
    int currentTargetMinutes = currentMinutes;
    int dayIndex = 0;
    bool reachedGoal = false;
    while (!reachedGoal) {
      // Calculate next target time
      int nextTargetMinutes = currentTargetMinutes - shiftSize;
      if (nextTargetMinutes < 0) {
        nextTargetMinutes += 24 * 60;
      }
      // Check if next shift would reach or pass the goal
      int minutesToGoal = (nextTargetMinutes - goalMinutes) % (24 * 60);
      if (minutesToGoal <= 0 || nextTargetMinutes == goalMinutes) {
        // Last day: set to goal time
        nextTargetMinutes = goalMinutes;
        reachedGoal = true;
      }
      int hours = nextTargetMinutes ~/ 60;
      int minutes = nextTargetMinutes % 60;
      TimeOfDay targetTime = TimeOfDay(hour: hours, minute: minutes);
      DateTime dayDate = startDate.add(Duration(days: dayIndex));
      String dateStr = _formatDate(dayDate, targetTime);
      String description;
      Color color;
      if (dayIndex == 0) {
        description = 'Start your sleep journey';
        color = Colors.blue;
      } else if (reachedGoal) {
        description = 'Goal achieved!';
        color = Colors.green;
      } else if (dayIndex == 1) {
        description = 'Building consistency';
        color = Colors.green;
      } else if (dayIndex % 2 == 0) {
        description = 'Getting into rhythm';
        color = Colors.blue;
      } else {
        description = 'Final stretch';
        color = Colors.teal;
      }
      _planDays.add({
        'day': 'Day ${dayIndex + 1}',
        'date': dateStr,
        'description': description,
        'color': color,
        'targetTime': targetTime,
      });
      _dayCompleted.add(false);
      _reminderEnabled.add(true);
      currentTargetMinutes = nextTargetMinutes;
      dayIndex++;
    }
  }

  String _getDayName(DateTime date) {
    List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _formatDate(DateTime date, TimeOfDay time) {
    List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    String month = months[date.month - 1];
    String day = date.day.toString();
    String timeStr = time.format(context);
    
    return '${_getDayName(date)}, $month $day - $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    // Check if plan data is available
    if (widget.currentSleepTime == null || widget.goalSleepTime == null || widget.use30MinuteShifts == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 400 ? 24.0 : 16.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Header
                Text(
                  'Your Full Sleep Plan',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width > 400 ? 32 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a sleep plan first to see your full schedule',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 50),
                
                // No Plan Message
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.withOpacity(0.25), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bedtime,
                        color: Colors.indigo,
                        size: 64,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No Sleep Plan Created',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Go to the Home tab and create your personalized sleep plan to see your full schedule here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 400 ? 24.0 : 16.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Header
                Text(
                  'Your Full Sleep Plan',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width > 400 ? 32 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete ${_planDays.length}-day sleep schedule',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Reassuring Message
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.18), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.sentiment_satisfied_alt, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Don't worry if you miss a day! Life happens. We'll help you adjust your plan if you need to. Progress, not perfection.",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Progress Summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.withOpacity(0.25), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: Colors.indigo,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_dayCompleted.where((completed) => completed).length}/${_planDays.length} Days Completed',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _planDays.isEmpty 
                                  ? '0% of your plan completed'
                                  : '${((_dayCompleted.where((completed) => completed).length / _planDays.length) * 100).round()}% of your plan completed',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Dynamic Day Schedule
                if (_planDays.isNotEmpty)
                  ..._planDays.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> day = entry.value;
                    return _buildDayCard(
                      day: day['day'],
                      date: day['date'],
                      description: day['description'],
                      isCompleted: _dayCompleted[index],
                      reminderEnabled: _reminderEnabled[index],
                      color: day['color'],
                      dayIndex: index,
                    );
                  }).toList(),
                
                const SizedBox(height: 30),
                
                // Tips Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.withOpacity(0.25), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigoAccent.withOpacity(0.18),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb,
                            color: Colors.yellow,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Tips for Success',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTip('Set a reminder 30 minutes before bedtime'),
                      _buildTip('Avoid screens 1 hour before sleep'),
                      _buildTip('Keep your bedroom cool and dark'),
                      _buildTip('Stick to the schedule even on weekends'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCard({
    required String day,
    required String date,
    required String description,
    required bool isCompleted,
    required bool reminderEnabled,
    required Color color,
    required int dayIndex,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? color.withOpacity(0.5) : Colors.indigo.withOpacity(0.25),
          width: isCompleted ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCompleted 
                ? color.withOpacity(0.2)
                : Colors.indigoAccent.withOpacity(0.18),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Checkbox
          GestureDetector(
            onTap: () {
              setState(() {
                _dayCompleted[dayIndex] = !_dayCompleted[dayIndex];
              });
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isCompleted ? color : Colors.grey.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? color : Colors.grey.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.bedtime,
                color: isCompleted ? Colors.white : Colors.grey,
                size: 24,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Day Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? color : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isCompleted)
                      Icon(
                        Icons.check_circle,
                        color: color,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 16,
                    color: isCompleted ? color.withOpacity(0.8) : Colors.white,
                    fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isCompleted ? Colors.grey : Colors.grey.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          
          // Bell Icon (Reminder Toggle)
          GestureDetector(
            onTap: () {
              setState(() {
                _reminderEnabled[dayIndex] = !_reminderEnabled[dayIndex];
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: reminderEnabled 
                    ? Colors.amber.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: reminderEnabled 
                      ? Colors.amber.withOpacity(0.5)
                      : Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                reminderEnabled ? Icons.notifications_active : Icons.notifications_off,
                color: reminderEnabled ? Colors.amber : Colors.grey,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.yellow,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    // Show current month, highlight plan days, allow day-off selection
    DateTime now = DateTime.now();
    DateTime firstDay = DateTime(now.year, now.month, 1);
    DateTime lastDay = DateTime(now.year, now.month + 1, 0);
    int daysInMonth = lastDay.day;
    List<Widget> rows = [];
    int weekDayOffset = firstDay.weekday % 7;
    List<Widget> week = List.generate(weekDayOffset, (_) => Expanded(child: Container()));
    for (int day = 1; day <= daysInMonth; day++) {
      DateTime date = DateTime(now.year, now.month, day);
      Map<String, dynamic>? planDay = _planDays.isEmpty ? null : (() {
        for (final d in _planDays) {
          if (d['dateObj'] != null &&
              d['dateObj'].year == date.year &&
              d['dateObj'].month == date.month &&
              d['dateObj'].day == date.day) {
            return d;
          }
        }
        return null;
      })();
      bool isDayOff = planDay != null && planDay['isDayOff'] == true;
      bool isPlanDay = planDay != null && !isDayOff;
      week.add(Expanded(
        child: GestureDetector(
          onTap: isPlanDay || isDayOff
              ? () {
                  setState(() {
                    if (_daysOff.contains(date)) {
                      _daysOff.remove(date);
                    } else {
                      _daysOff.add(date);
                    }
                    _planInitialized = false;
                  });
                }
              : null,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isDayOff
                  ? Colors.grey
                  : isPlanDay
                      ? planDay!['color'].withOpacity(0.7)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPlanDay || isDayOff ? Colors.indigo : Colors.transparent,
                width: 1.5,
              ),
            ),
            height: 48,
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  color: isDayOff
                      ? Colors.white
                      : isPlanDay
                          ? Colors.white
                          : Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ));
      if ((week.length) == 7) {
        rows.add(Row(children: week));
        week = [];
      }
    }
    if (week.isNotEmpty) {
      while (week.length < 7) {
        week.add(Expanded(child: Container()));
      }
      rows.add(Row(children: week));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Plan Calendar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('${_daysOff.length} days off', style: TextStyle(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        ...rows,
        const SizedBox(height: 12),
        Row(
          children: [
            _buildLegendBox(Colors.blue, 'Plan Day'),
            const SizedBox(width: 8),
            _buildLegendBox(Colors.grey, 'Day Off'),
            const SizedBox(width: 8),
            _buildLegendBox(Colors.transparent, 'Non-Plan'),
          ],
        ),
        const SizedBox(height: 8),
        Text('Plan end date: ${_planDays.isNotEmpty ? _planDays.last['date'] : '-'}', style: TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildLegendBox(Color color, String label) {
    return Row(
      children: [
        Container(width: 18, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.indigo)),),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}



// Profile Screen
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 400 ? 24.0 : 16.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Header
                Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width > 400 ? 32 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage your sleep journey',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Profile Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.withOpacity(0.25), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigoAccent.withOpacity(0.18),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.2),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.indigo,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Sleep Enthusiast',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'On a journey to better sleep',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Stats Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.withOpacity(0.25), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigoAccent.withOpacity(0.18),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.analytics,
                            color: Colors.green,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Your Stats',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildStatRow('Days in Plan', '0', Colors.blue),
                      const SizedBox(height: 12),
                      _buildStatRow('Current Streak', '0 days', Colors.green),
                      const SizedBox(height: 12),
                      _buildStatRow('Best Streak', '0 days', Colors.blue),
                      const SizedBox(height: 12),
                      _buildStatRow('Sleep Score', '--', Colors.purple),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Settings Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.withOpacity(0.25), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigoAccent.withOpacity(0.18),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.settings,
                            color: Colors.blue,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSettingRow(
                        icon: Icons.notifications,
                        title: 'Notifications',
                        subtitle: 'Manage sleep reminders',
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      _buildSettingRow(
                        icon: Icons.edit,
                        title: 'Edit Plan',
                        subtitle: 'Modify your sleep schedule',
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      _buildSettingRow(
                        icon: Icons.data_usage,
                        title: 'Data & Privacy',
                        subtitle: 'Manage your data',
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      _buildSettingRow(
                        icon: Icons.help,
                        title: 'Help & Support',
                        subtitle: 'Get help with the app',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Reset Plan Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Plan reset! Start fresh with a new sleep schedule.'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Reset Plan 🔄',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
            ),
            child: Icon(
              icon,
              color: Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: Colors.grey,
            size: 16,
          ),
        ],
      ),
    );
  }
}

// Plan Summary Screen
class PlanSummaryScreen extends StatefulWidget {
  final TimeOfDay currentSleepTime;
  final TimeOfDay goalSleepTime;
  final bool use30MinuteShifts;

  const PlanSummaryScreen({
    super.key,
    required this.currentSleepTime,
    required this.goalSleepTime,
    required this.use30MinuteShifts,
  });

  @override
  State<PlanSummaryScreen> createState() => _PlanSummaryScreenState();
}

class _PlanSummaryScreenState extends State<PlanSummaryScreen> {
  bool planStarted = false;
  TimeOfDay morningSunlightTime = const TimeOfDay(hour: 7, minute: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Your Sleep Plan',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Plan Overview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.indigo.withOpacity(0.25), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigoAccent.withOpacity(0.18),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.rocket_launch,
                          color: Colors.indigo,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Plan Overview',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPlanRow('Current Sleep Time', widget.currentSleepTime.format(context), Colors.blue),
                    const SizedBox(height: 8),
                    _buildPlanRow('Goal Sleep Time', widget.goalSleepTime.format(context), Colors.green),
                    const SizedBox(height: 8),
                    _buildPlanRow('Shift Speed', widget.use30MinuteShifts ? '30 minutes' : '15 minutes', Colors.purple),
                    const SizedBox(height: 8),
                    _buildPlanRow('Total Duration', _getDaysNeeded() + ' days', Colors.indigo),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Today's Target Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.today,
                          color: Colors.green,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Today\'s Target',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getTodayTarget().format(context),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Go to bed at this time tonight',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_active,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'We will remind you 30 mins before bedtime',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Go to bed at this time tonight',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Reminders Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple.withOpacity(0.3), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notifications,
                          color: Colors.purple,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Reminders',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Sleep Time Reminder
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sleep Time Reminder',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '30 minutes before ${_getTodayTarget().format(context)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: true, // Default to enabled
                          onChanged: (value) {
                            // Handle reminder toggle
                          },
                          activeColor: Colors.purple,
                          activeTrackColor: Colors.purple.withOpacity(0.3),
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.withOpacity(0.3),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Morning Sunlight Reminder
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '☀️ Get Morning Sunlight',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Within 30-60 minutes of waking (10-30 min outdoor, no sunglasses)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: true, // Default to enabled since it's crucial for sleep
                          onChanged: (value) {
                            // Handle morning sunlight reminder toggle
                          },
                          activeColor: Colors.purple,
                          activeTrackColor: Colors.purple.withOpacity(0.3),
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.withOpacity(0.3),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Morning Sunlight Time Picker (shown when enabled)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.purple,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Reminder at: ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          GestureDetector(
                            onTap: _selectMorningSunlightTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                morningSunlightTime.format(context),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Dinner Shift Reminder
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Shift Dinner Earlier',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Optional: Eat 2-3 hours before bed',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: false, // Default to disabled
                          onChanged: (value) {
                            // Handle dinner reminder toggle
                          },
                          activeColor: Colors.purple,
                          activeTrackColor: Colors.purple.withOpacity(0.3),
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.withOpacity(0.3),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Dinner Time Picker (shown when enabled)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.purple,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Dinner reminder at: ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              // Show time picker for dinner reminder
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '6:00 PM',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Weekly Preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.indigo.withOpacity(0.25), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigoAccent.withOpacity(0.18),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'This Week',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._getWeeklySchedule(),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Start Plan Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      planStarted = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: planStarted ? Colors.grey : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    planStarted ? 'Plan Started! ✅' : 'Start My Sleep Journey 🌙',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _getDaysNeeded() {
    int currentMinutes = widget.currentSleepTime.hour * 60 + widget.currentSleepTime.minute;
    int goalMinutes = widget.goalSleepTime.hour * 60 + widget.goalSleepTime.minute;
    
    int difference = currentMinutes - goalMinutes;
    
    if (difference < 0) {
      difference += 24 * 60; // Add 24 hours if goal is earlier
    }
    
    int shiftSize = widget.use30MinuteShifts ? 30 : 15;
    int shiftsNeeded = (difference / shiftSize).ceil();
    int daysPerShift = difference <= 120 ? 1 : 2;
    int daysNeeded = shiftsNeeded * daysPerShift;
    
    return daysNeeded.toString();
  }

  TimeOfDay _getTodayTarget() {
    // Calculate today's target based on current progress
    int currentMinutes = widget.currentSleepTime.hour * 60 + widget.currentSleepTime.minute;
    int goalMinutes = widget.goalSleepTime.hour * 60 + widget.goalSleepTime.minute;
    
    int difference = currentMinutes - goalMinutes;
    if (difference < 0) {
      difference += 24 * 60;
    }
    
    // Smart shift size calculation
    int shiftSize;
    if (difference <= 60) {
      shiftSize = 15;
    } else if (difference <= 180) {
      shiftSize = 20;
    } else {
      shiftSize = 30;
    }
    
    // For now, return the first step (Day 1 target)
    // In a real app, you'd track which day the user is on
    int firstStepShift = shiftSize;
    int newMinutes = currentMinutes - firstStepShift;
    
    if (newMinutes < 0) {
      newMinutes += 24 * 60;
    }
    
    int hours = newMinutes ~/ 60;
    int minutes = newMinutes % 60;
    
    return TimeOfDay(hour: hours, minute: minutes);
  }

  List<Widget> _getWeeklySchedule() {
    List<Widget> schedule = [];
    DateTime today = DateTime.now();
    int totalDays = _getTotalPlanDays();
    
    for (int i = 0; i < totalDays; i++) {
      DateTime date = today.add(Duration(days: i));
      String dayName = _getDayName(date.weekday);
      String targetTime = widget.currentSleepTime.format(context); // Simplified for now
      
      schedule.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayName,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              Text(
                targetTime,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return schedule;
  }

  String _getDayName(int weekday) {
    List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  int _getTotalPlanDays() {
    // Calculate total days based on the actual plan
    int currentMinutes = widget.currentSleepTime.hour * 60 + widget.currentSleepTime.minute;
    int goalMinutes = widget.goalSleepTime.hour * 60 + widget.goalSleepTime.minute;
    
    int difference = currentMinutes - goalMinutes;
    if (difference < 0) {
      difference += 24 * 60;
    }
    
    // Smart shift size calculation
    int shiftSize;
    if (difference <= 60) {
      shiftSize = 15;
    } else if (difference <= 180) {
      shiftSize = 20;
    } else {
      shiftSize = 30;
    }
    
    int shiftsNeeded = (difference / shiftSize).ceil();
    int daysPerShift = difference <= 120 ? 1 : 2;
    int totalDays = shiftsNeeded * daysPerShift;
    
    return totalDays;
  }

  Future<void> _selectMorningSunlightTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: morningSunlightTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Color(0xFF16213E),
              hourMinuteTextColor: Colors.white,
              hourMinuteColor: Colors.purple,
              dialHandColor: Colors.purple,
              dialBackgroundColor: Color(0xFF1A1A2E),
              dialTextColor: Colors.white,
              entryModeIconColor: Colors.white,
              hourMinuteTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              dayPeriodTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              dialTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        morningSunlightTime = picked;
      });
    }
  }
}

// Dashboard Screen (Home after plan is created)
class DashboardScreen extends StatefulWidget {
  final TimeOfDay currentSleepTime;
  final TimeOfDay goalSleepTime;
  final bool use30MinuteShifts;

  const DashboardScreen({
    super.key,
    required this.currentSleepTime,
    required this.goalSleepTime,
    required this.use30MinuteShifts,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool sleepReminderEnabled = true;
  bool dinnerReminderEnabled = false;
  bool customReminderEnabled = false;
  bool morningSunlightEnabled = false;
  TimeOfDay dinnerReminderTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay customReminderTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay morningSunlightTime = const TimeOfDay(hour: 7, minute: 0);
  String customReminderTitle = 'Stop Screens';
  String customReminderDescription = 'Avoid screens 1 hour before bed';
  String deviceType = 'Unknown';
  String blueLightFilterName = 'Blue Light Filter';
  String blueLightFilterInstructions = 'Enable your device\'s blue light filter';
  
  // Progress tracking
  int currentStreak = 0;
  List<SleepProgress> weekProgress = [];
  bool progressTrackingEnabled = true;

  final List<Map<String, dynamic>> reminderOptions = [
    {
      'title': 'Stop Screens',
      'description': 'Avoid screens 1 hour before bed',
      'icon': Icons.phone_android,
    },
    {
      'title': 'Start Wind Down',
      'description': 'Begin your bedtime routine',
      'icon': Icons.bedtime,
    },
    {
      'title': 'Take Melatonin',
      'description': 'If recommended by your doctor',
      'icon': Icons.medication,
    },
    {
      'title': 'Set Temperature',
      'description': 'Cool your room to 65-68°F',
      'icon': Icons.thermostat,
    },
    {
      'title': 'Drink Water',
      'description': 'Stay hydrated but not too much',
      'icon': Icons.water_drop,
    },
  ];

  @override
  void initState() {
    super.initState();
    _setDefaultDinnerTime();
    _detectDevice();
    _loadProgressData();
    _scheduleNotifications();
    _requestNotificationPermissions();
  }

  Future<void> _loadProgressData() async {
    setState(() {
      currentStreak = ProgressTrackingService.getCurrentStreak();
      weekProgress = ProgressTrackingService.getWeekProgress(
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1))
      );
    });
  }

  Future<void> _scheduleNotifications() async {
    if (progressTrackingEnabled) {
      // Schedule morning check-in (30 minutes after wake-up time)
      final wakeUpTime = TimeOfDay(hour: 7, minute: 0); // Default 7 AM
      await ProgressTrackingService.scheduleMorningCheckIn(wakeUpTime);
      await ProgressTrackingService.scheduleWeeklyReport();
      
      // Schedule bedtime reminder (30 minutes before target bedtime)
      final targetBedtime = _getTodayTarget();
      await ProgressTrackingService.scheduleBedtimeReminder(targetBedtime);
    }
  }

  Future<void> _requestNotificationPermissions() async {
    final granted = await NotificationService.requestPermissions();
    if (!granted) {
      // Show a dialog explaining why notifications are important
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black.withOpacity(0.9),
            title: const Text(
              'Enable Notifications',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Sleep Fixer AI can send you personalized sleep tips and progress reminders. This helps you stay on track with your sleep goals!',
              style: TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Maybe Later',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  NotificationService.requestPermissions();
                },
                child: const Text(
                  'Enable',
                  style: TextStyle(color: Colors.indigo),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showProgressTrackingDialog() {
    final lastNight = ProgressTrackingService.getProgress(
      DateTime.now().subtract(const Duration(days: 1))
    );
    
    showDialog(
      context: context,
      builder: (context) => ProgressTrackingDialog(
        targetTime: _getTodayTarget(),
        lastNight: lastNight,
      ),
    ).then((_) {
      _loadProgressData(); // Refresh data after dialog closes
    });
  }

  Future<void> _detectDevice() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    
    try {
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        setState(() {
          deviceType = 'iOS';
          blueLightFilterName = 'Night Shift';
          blueLightFilterInstructions = 'Settings > Display & Brightness > Night Shift';
        });
      } else if (Theme.of(context).platform == TargetPlatform.android) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        String manufacturer = androidInfo.manufacturer.toLowerCase();
        
        if (manufacturer.contains('samsung')) {
          setState(() {
            deviceType = 'Samsung';
            blueLightFilterName = 'Eye Comfort Shield';
            blueLightFilterInstructions = 'Settings > Display > Eye comfort shield';
          });
        } else if (manufacturer.contains('oneplus')) {
          setState(() {
            deviceType = 'OnePlus';
            blueLightFilterName = 'Reading Mode';
            blueLightFilterInstructions = 'Settings > Display > Reading mode';
          });
        } else {
          setState(() {
            deviceType = 'Android';
            blueLightFilterName = 'Night Light';
            blueLightFilterInstructions = 'Settings > Display > Night light';
          });
        }
      }
    } catch (e) {
      // Fallback to generic settings
      setState(() {
        deviceType = 'Device';
        blueLightFilterName = 'Blue Light Filter';
        blueLightFilterInstructions = 'Check your device settings for blue light filter options';
      });
    }
  }

  Future<void> _openBlueLightFilterSettings() async {
    String url = '';
    
    if (deviceType == 'iOS') {
      url = 'App-Prefs:DISPLAY';
    } else if (deviceType == 'Samsung') {
      url = 'android-app://com.android.settings/.display.DisplaySettings';
    } else if (deviceType == 'OnePlus') {
      url = 'android-app://com.android.settings/.display.DisplaySettings';
    } else {
      url = 'android-app://com.android.settings/.display.DisplaySettings';
    }
    
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        // Fallback: show instructions
        _showBlueLightFilterInstructions();
      }
    } catch (e) {
      // Fallback: show instructions
      _showBlueLightFilterInstructions();
    }
  }

  void _showBlueLightFilterInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        title: Text(
          'Enable $blueLightFilterName',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          blueLightFilterInstructions,
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.indigo),
            ),
          ),
        ],
      ),
    );
  }

  void _setDefaultDinnerTime() {
    // Set dinner time to 2.5 hours before today's target
    TimeOfDay todayTarget = _getTodayTarget();
    int targetHour = todayTarget.hour;
    int targetMinute = todayTarget.minute;
    
    // Calculate 2.5 hours earlier
    int dinnerHour = targetHour - 2;
    int dinnerMinute = targetMinute - 30;
    
    // Handle negative minutes
    if (dinnerMinute < 0) {
      dinnerHour -= 1;
      dinnerMinute += 60;
    }
    
    // Handle negative hours (overnight)
    if (dinnerHour < 0) {
      dinnerHour += 24;
    }
    
    setState(() {
      dinnerReminderTime = TimeOfDay(hour: dinnerHour, minute: dinnerMinute);
    });
  }

  Future<void> _selectDinnerTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: dinnerReminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Color(0xFF16213E),
              hourMinuteTextColor: Colors.white,
              hourMinuteColor: Colors.indigo,
              dialHandColor: Colors.indigo,
              dialBackgroundColor: Color(0xFF1A1A2E),
              dialTextColor: Colors.white,
              entryModeIconColor: Colors.white,
              hourMinuteTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              dayPeriodTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              dialTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        dinnerReminderTime = picked;
      });
    }
  }

  Future<void> _selectCustomTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: customReminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Color(0xFF16213E),
              hourMinuteTextColor: Colors.white,
              hourMinuteColor: Colors.indigo,
              dialHandColor: Colors.indigo,
              dialBackgroundColor: Color(0xFF1A1A2E),
              dialTextColor: Colors.white,
              entryModeIconColor: Colors.white,
              hourMinuteTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              dayPeriodTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              dialTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        customReminderTime = picked;
      });
    }
  }

  Future<void> _selectMorningSunlightTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: morningSunlightTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Color(0xFF16213E),
              hourMinuteTextColor: Colors.white,
              hourMinuteColor: Colors.purple,
              dialHandColor: Colors.purple,
              dialBackgroundColor: Color(0xFF1A1A2E),
              dialTextColor: Colors.white,
              entryModeIconColor: Colors.white,
              hourMinuteTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              dayPeriodTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              dialTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        morningSunlightTime = picked;
      });
    }
  }

  void _showReminderOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose Reminder Type',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: reminderOptions.length,
                itemBuilder: (context, index) {
                  final option = reminderOptions[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        customReminderTitle = option['title'];
                        customReminderDescription = option['description'];
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigo.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            option['icon'],
                            color: Colors.indigo,
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option['title'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  option['description'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  TimeOfDay _getTodayTarget() {
    // Calculate today's target based on current progress
    int currentMinutes = widget.currentSleepTime.hour * 60 + widget.currentSleepTime.minute;
    int goalMinutes = widget.goalSleepTime.hour * 60 + widget.goalSleepTime.minute;
    
    int difference = currentMinutes - goalMinutes;
    if (difference < 0) {
      difference += 24 * 60;
    }
    
    // Smart shift size calculation
    int shiftSize;
    if (difference <= 60) {
      shiftSize = 15;
    } else if (difference <= 180) {
      shiftSize = 20;
    } else {
      shiftSize = 30;
    }
    
    // For now, return the first step (Day 1 target)
    // In a real app, you'd track which day the user is on
    int firstStepShift = shiftSize;
    int newMinutes = currentMinutes - firstStepShift;
    
    if (newMinutes < 0) {
      newMinutes += 24 * 60;
    }
    
    int hours = newMinutes ~/ 60;
    int minutes = newMinutes % 60;
    
    return TimeOfDay(hour: hours, minute: minutes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 400 ? 24.0 : 16.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Header
                Text(
                  'Your Sleep Plan',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width > 400 ? 32 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Track your progress and stay on schedule',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Reassuring Message
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.18), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.sentiment_satisfied_alt, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "It's okay if you miss a day or two—life happens! Your plan will adjust, and you can always get back on track. No pressure!",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Plan Overview Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.withOpacity(0.25), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigoAccent.withOpacity(0.18),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bedtime,
                            color: Colors.indigo,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Plan Overview',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildPlanRow('Current Sleep Time', widget.currentSleepTime.format(context), Colors.blue),
                      const SizedBox(height: 12),
                      _buildPlanRow('Goal Sleep Time', widget.goalSleepTime.format(context), Colors.green),
                      const SizedBox(height: 12),
                      _buildPlanRow('Shift Speed', _getShiftSize(), Colors.purple),
                      const SizedBox(height: 12),
                      _buildPlanRow('Total Plan Days', '${_getTotalPlanDays()} days', Colors.orange),
                    ],
                  ),
                ),
                
                // AI Chat Button
                const SizedBox(height: 20),
                
                const SizedBox(height: 20),
                
                // Today's Target Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.today,
                            color: Colors.green,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Today\'s Target',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getTodayTarget().format(context),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Go to bed at this time tonight',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_active,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'We will remind you 30 mins before bedtime',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.amber,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Progress Tracking Card (Redesigned)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active,
                            color: Colors.green,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Sleep Progress',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Progress bar with label
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Day ${_getCurrentPlanDay()} of ${_getTotalPlanDays()}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: _getTotalPlanDays() > 0 ? _getDaysCompleted() / _getTotalPlanDays() : 0,
                                  backgroundColor: Colors.grey.withOpacity(0.3),
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                  minHeight: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.notifications,
                            color: Colors.white.withOpacity(0.7),
                            size: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Supportive message
                      const Text(
                        "Don't worry if you miss a day—your plan will adjust! Keep going, you're doing great!",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Blue Light Filter Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.3), width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.nightlight,
                            color: Colors.amber,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Blue Light Filter',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Reduce blue light exposure in the evening to help your body prepare for sleep.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  blueLightFilterName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  blueLightFilterInstructions,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _openBlueLightFilterSettings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Open Settings',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Additional Tips Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.2), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Additional Tips',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildTipItem(
                              '💻 Enable on all devices: computers, laptops, and even televisions',
                              Colors.amber,
                            ),
                            const SizedBox(height: 8),
                            _buildTipItem(
                              '⚙️ Adjust the strength to your comfort level - some filter is better than none',
                              Colors.amber,
                            ),
                            const SizedBox(height: 8),
                            _buildTipItem(
                              '🌙 Start using it 1-2 hours before bedtime for best results',
                              Colors.amber,
                            ),
                            const SizedBox(height: 8),
                            _buildTipItem(
                              '💡 Avoid bright lighting and use gentle, warm lights when possible',
                              Colors.amber,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Subtle Reset Option
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.settings,
                            color: Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Advanced',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.black.withOpacity(0.9),
                              title: const Text(
                                'Reset Sleep Plan?',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: const Text(
                                'This will clear your current sleep plan and progress. You\'ll need to create a new plan.',
                                style: TextStyle(color: Colors.grey),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Plan reset! Start fresh with a new sleep schedule.'),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Reset',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        child: const Text(
                          'Reset Plan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Sleep Progress Card (AI Notifications)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.withOpacity(0.25), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigoAccent.withOpacity(0.18),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications_active, color: Colors.amber, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "We'll send you personalized AI notifications to help you stay on track.",
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Progress bar
                      LinearProgressIndicator(
                        value: _getTotalPlanDays() > 0 ? _getDaysCompleted() / _getTotalPlanDays() : 0,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Day ${_getDaysCompleted() + 1} of ${_getTotalPlanDays()}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "You're making great progress! Don't worry if you miss a day—your plan will adjust and we'll keep cheering you on. 💚",
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ),
      ],
    );
  }

  // Add these helper methods to DashboardScreen:
  int _getDaysCompleted() {
    // For now, return 0 since we don't have actual progress tracking yet
    // In a real app, this would check actual completed days from storage
    return 0;
  }

  int _getCurrentPlanDay() {
    // Replace with your actual logic for current day in plan
    // For now, return 1 as a placeholder
    return 1;
  }

  int _getTotalPlanDays() {
    // Calculate total days based on the actual plan
    int currentMinutes = widget.currentSleepTime.hour * 60 + widget.currentSleepTime.minute;
    int goalMinutes = widget.goalSleepTime.hour * 60 + widget.goalSleepTime.minute;
    
    int difference = currentMinutes - goalMinutes;
    if (difference < 0) {
      difference += 24 * 60;
    }
    
    // Smart shift size calculation
    int shiftSize;
    if (difference <= 60) {
      shiftSize = 15;
    } else if (difference <= 180) {
      shiftSize = 20;
    } else {
      shiftSize = 30;
    }
    
    int shiftsNeeded = (difference / shiftSize).ceil();
    int daysPerShift = difference <= 120 ? 1 : 2;
    int totalDays = shiftsNeeded * daysPerShift;
    
    return totalDays;
  }

  String _getShiftSize() {
    int currentMinutes = widget.currentSleepTime.hour * 60 + widget.currentSleepTime.minute;
    int goalMinutes = widget.goalSleepTime.hour * 60 + widget.goalSleepTime.minute;
    int difference = currentMinutes - goalMinutes;
    if (difference < 0) {
      difference += 24 * 60;
    }
    if (difference <= 60) {
      return '15 min per shift';
    } else if (difference <= 180) {
      return '20 min per shift';
    } else {
      return '30 min per shift';
    }
  }
}

// Progress Tracking Service
class ProgressTrackingService {
  static const String _progressBoxName = 'sleep_progress';
  static const String _settingsBoxName = 'sleep_settings';
  
  static late Box<dynamic> _progressBox;
  static late Box<dynamic> _settingsBox;

  static Future<void> initialize() async {
    await Hive.initFlutter();
    _progressBox = await Hive.openBox(_progressBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  static Future<void> saveProgress(SleepProgress progress) async {
    final key = DateFormat('yyyy-MM-dd').format(progress.date);
    await _progressBox.put(key, progress.toJson());
  }

  static SleepProgress? getProgress(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    final data = _progressBox.get(key);
    if (data != null) {
      return SleepProgress.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  static List<SleepProgress> getWeekProgress(DateTime weekStart) {
    final List<SleepProgress> weekProgress = [];
    // Use actual plan length instead of hardcoded 7
    int planLength = 7; // Default fallback
    for (int i = 0; i < planLength; i++) {
      final date = weekStart.add(Duration(days: i));
      final progress = getProgress(date);
      if (progress != null) {
        weekProgress.add(progress);
      }
    }
    return weekProgress;
  }

  static int getCurrentStreak() {
    int streak = 0;
    DateTime currentDate = DateTime.now();
    
    while (true) {
      final progress = getProgress(currentDate);
      if (progress == null || progress.status == ProgressStatus.notTracked) {
        break;
      }
      if (progress.status == ProgressStatus.onTarget || 
          progress.status == ProgressStatus.within30Min) {
        streak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  static Future<void> scheduleMorningCheckIn(TimeOfDay wakeUpTime) async {
    await NotificationService.scheduleMorningCheckIn(wakeUpTime);
  }

  static Future<void> scheduleWeeklyReport() async {
    await NotificationService.scheduleWeeklyReport();
  }

  static Future<void> scheduleBedtimeReminder(TimeOfDay targetBedtime) async {
    await NotificationService.scheduleBedtimeReminder(targetBedtime);
  }

  static Future<void> cancelAllNotifications() async {
    await NotificationService.cancelAllNotifications();
  }
}

// Progress Tracking Dialog
class ProgressTrackingDialog extends StatefulWidget {
  final TimeOfDay targetTime;
  final SleepProgress? lastNight;

  const ProgressTrackingDialog({
    super.key,
    required this.targetTime,
    this.lastNight,
  });

  @override
  State<ProgressTrackingDialog> createState() => _ProgressTrackingDialogState();
}

class _ProgressTrackingDialogState extends State<ProgressTrackingDialog> {
  ProgressStatus? selectedStatus;
  TimeOfDay? actualTime;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.track_changes,
                  color: Colors.indigo,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sleep Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Target time display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.indigo, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Target: ${widget.targetTime.format(context)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Progress options
            const Text(
              'How did you do last night?',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Option buttons
            _buildOptionButton(
              ProgressStatus.onTarget,
              '✅ On Target',
              'Went to bed at target time',
              Colors.green,
            ),
            
            _buildOptionButton(
              ProgressStatus.within30Min,
              '⏰ Within 30 min',
              'Close to target time',
              Colors.blue,
            ),
            
            _buildOptionButton(
              ProgressStatus.within1Hour,
              '🌙 Within 1 hour',
              'Within an hour of target',
              Colors.orange,
            ),
            
            _buildOptionButton(
              ProgressStatus.offTarget,
              '❌ Off Target',
              'More than an hour off',
              Colors.red,
            ),
            
            const SizedBox(height: 20),
            
            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedStatus != null ? _saveProgress : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save Progress',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(ProgressStatus status, String title, String subtitle, Color color) {
    final isSelected = selectedStatus == status;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedStatus = status;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? color : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? color.withOpacity(0.8) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveProgress() async {
    if (selectedStatus == null) return;
    
    final progress = SleepProgress(
      date: DateTime.now().subtract(const Duration(days: 1)),
      targetTime: widget.targetTime,
      actualTime: actualTime,
      status: selectedStatus!,
    );
    
    await ProgressTrackingService.saveProgress(progress);
    
    if (mounted) {
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedStatus == ProgressStatus.onTarget 
                ? '🎉 Amazing! Keep up the great work!'
                : '📝 Progress saved! Every day is a new opportunity.',
          ),
          backgroundColor: Colors.indigo,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class SleepShiftScreen extends StatefulWidget {
  final Function(TimeOfDay, TimeOfDay, bool)? onPlanCreated;

  const SleepShiftScreen({super.key, this.onPlanCreated});

  @override
  State<SleepShiftScreen> createState() => _SleepShiftScreenState();
}

class _SleepShiftScreenState extends State<SleepShiftScreen> {
  TimeOfDay currentSleepTime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay goalSleepTime = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay currentWakeTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay goalWakeTime = const TimeOfDay(hour: 6, minute: 0);
  
  // Constraint toggles
  bool currentSleepConstraint = false;
  bool currentWakeConstraint = false;
  bool goalSleepConstraint = false;
  bool goalWakeConstraint = false;
  
  // First time helper
  bool showHelper = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 100,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 400 ? 24.0 : 16.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Header
                    Text(
                      'Sleep Fixer',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width > 400 ? 32 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Let\'s fix your sleep schedule',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Top right button for users who already sleep well
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AlreadySleepWellScreen(
                                  onCompleted: (sleepTime, wakeTime, hasConstraint) {
                                    widget.onPlanCreated?.call(sleepTime, wakeTime, hasConstraint);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Welcome! Explore our sleep tools and tips! ✨'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'I already sleep when I want 💤',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 22),
                    
                    // First time helper
                    if (showHelper)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.4), width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '💡 Tip: Use the "Fixed?" toggles if your times are set by work, school, or other obligations',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  showHelper = false;
                                });
                              },
                              icon: Icon(
                                Icons.close,
                                color: Colors.blue,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    
                    // Current Schedule Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schedule, color: Colors.blue, size: 24),
                              const SizedBox(width: 12),
                              const Text(
                                'Current Schedule',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTimeSection(
                                  title: 'Sleep Time',
                      subtitle: 'When do you usually go to bed?',
                      time: currentSleepTime,
                      onTap: () => _selectTime(context, true),
                      color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTimeSection(
                                  title: 'Wake Time',
                                  subtitle: 'When do you usually wake up?',
                                  time: currentWakeTime,
                                  onTap: () => _selectWakeTime(context, true),
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Constraint toggles for current schedule
                          Row(
                            children: [
                              Expanded(
                                child: _buildConstraintToggle(
                                  title: 'Fixed?',
                                  value: currentSleepConstraint,
                                  onChanged: (value) {
                                    setState(() {
                                      currentSleepConstraint = value;
                                    });
                                  },
                                  color: Colors.blue,
                                  tooltip: 'Toggle if your current sleep time is fixed by work, school, or other obligations',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildConstraintToggle(
                                  title: 'Fixed?',
                                  value: currentWakeConstraint,
                                  onChanged: (value) {
                                    setState(() {
                                      currentWakeConstraint = value;
                                    });
                                  },
                                  color: Colors.orange,
                                  tooltip: 'Toggle if your current wake time is fixed by work, school, or other obligations',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Goal Schedule Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.flag, color: Colors.green, size: 24),
                              const SizedBox(width: 12),
                              const Text(
                                'Goal Schedule',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTimeSection(
                                  title: 'Sleep Time',
                      subtitle: 'When do you want to go to bed?',
                      time: goalSleepTime,
                      onTap: () => _selectTime(context, false),
                      color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTimeSection(
                                  title: 'Wake Time',
                                  subtitle: 'When do you want to wake up?',
                                  time: goalWakeTime,
                                  onTap: () => _selectWakeTime(context, false),
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Constraint toggles for goal schedule
                          Row(
                            children: [
                              Expanded(
                                child: _buildConstraintToggle(
                                  title: 'Fixed?',
                                  value: goalSleepConstraint,
                                  onChanged: (value) {
                                    setState(() {
                                      goalSleepConstraint = value;
                                    });
                                  },
                                  color: Colors.green,
                                  tooltip: 'Toggle if your goal sleep time is fixed by work, school, or other obligations',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildConstraintToggle(
                                  title: 'Fixed?',
                                  value: goalWakeConstraint,
                                  onChanged: (value) {
                                    setState(() {
                                      goalWakeConstraint = value;
                                    });
                                  },
                                  color: Colors.purple,
                                  tooltip: 'Toggle if your goal wake time is fixed by work, school, or other obligations',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Current sleep duration note
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getCurrentSleepQualityIcon(),
                            color: _getCurrentSleepQualityColor(),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getCurrentSleepNote(),
                              style: TextStyle(
                                fontSize: 14,
                                color: _getCurrentSleepQualityColor(),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Goal sleep duration note
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getGoalSleepNote(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Smart Shift Info
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purple.withOpacity(0.3), width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.nightlight,
                                color: Colors.purple,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Smart Sleep Shifts',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'We\'ll automatically adjust your bedtime by 15-30 minutes each night based on sleep science recommendations.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              const Text(
                                'Small shifts = better success',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Sleep Shift Calculation
                    if (!_isSameTime())
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  color: Colors.indigo,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Your Sleep Shift Plan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildCalculationRow(
                              'Total Shift Needed',
                              _getShiftTime(),
                              Colors.blue,
                            ),
                            const SizedBox(height: 8),
                            _buildCalculationRow(
                              'Shift Size',
                              _getShiftSize(),
                              Colors.purple,
                            ),
                            const SizedBox(height: 8),
                            _buildCalculationRow(
                              'Days to Complete',
                              '${_getDaysNeeded()} days',
                              Colors.green,
                            ),
                            const SizedBox(height: 8),
                            _buildCalculationRow(
                              'Target End Date',
                              _getEndDate(),
                              Colors.indigo,
                            ),
                          ],
                        ),
                      ),
                    
                    // Conditional message when times are the same
                    if (_isSameTime())
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Great job!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your current and goal sleep times are the same. Check out our other features for more sleep improvement tips!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 30),
                    
                    // Create Plan Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          widget.onPlanCreated?.call(currentSleepTime, goalSleepTime, _getUse30MinuteShifts());
                          
                          // Schedule notifications for the new plan
                          final targetBedtime = _getTodayTarget();
                          await ProgressTrackingService.scheduleBedtimeReminder(targetBedtime);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sleep plan created! 🚀'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Create Plan 🚀',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSection({
    required String title,
    required String subtitle,
    required TimeOfDay time,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(MediaQuery.of(context).size.width > 400 ? 16.0 : 12.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.indigo.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.indigoAccent.withOpacity(0.18),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width > 400 ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width > 400 ? 12 : 11,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: color,
                  size: MediaQuery.of(context).size.width > 400 ? 20 : 18,
                ),
                const SizedBox(width: 8),
                Text(
                  time.format(context),
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width > 400 ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstraintToggle({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? 'Toggle if this time is fixed by work, school, or other obligations',
      preferBelow: false,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2), width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.7,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: color,
                activeTrackColor: color.withOpacity(0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, bool isCurrentTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isCurrentTime ? currentSleepTime : goalSleepTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Color(0xFF16213E),
              hourMinuteTextColor: Colors.white,
              hourMinuteColor: Colors.purple,
              dialHandColor: Colors.purple,
              dialBackgroundColor: Color(0xFF1A1A2E),
              dialTextColor: Colors.white,
              entryModeIconColor: Colors.white,
              hourMinuteTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              dayPeriodTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              dialTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isCurrentTime) {
          currentSleepTime = picked;
        } else {
          goalSleepTime = picked;
        }
      });
    }
  }

  Future<void> _selectWakeTime(BuildContext context, bool isCurrentTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isCurrentTime ? currentWakeTime : goalWakeTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Color(0xFF16213E),
              hourMinuteTextColor: Colors.white,
              hourMinuteColor: Colors.orange,
              dialHandColor: Colors.orange,
              dialBackgroundColor: Color(0xFF1A1A2E),
              dialTextColor: Colors.white,
              entryModeIconColor: Colors.white,
              hourMinuteTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              dayPeriodTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              dialTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isCurrentTime) {
          currentWakeTime = picked;
        } else {
          goalWakeTime = picked;
        }
      });
    }
  }

  bool _isSameTime() {
    return currentSleepTime.hour == goalSleepTime.hour && 
           currentSleepTime.minute == goalSleepTime.minute &&
           currentWakeTime.hour == goalWakeTime.hour && 
           currentWakeTime.minute == goalWakeTime.minute;
  }

  String _getShiftTime() {
    int currentSleepMinutes = currentSleepTime.hour * 60 + currentSleepTime.minute;
    int goalSleepMinutes = goalSleepTime.hour * 60 + goalSleepTime.minute;
    int currentWakeMinutes = currentWakeTime.hour * 60 + currentWakeTime.minute;
    int goalWakeMinutes = goalWakeTime.hour * 60 + goalWakeTime.minute;
    
    int sleepDifference = currentSleepMinutes - goalSleepMinutes;
    int wakeDifference = currentWakeMinutes - goalWakeMinutes;
    
    if (sleepDifference < 0) {
      sleepDifference += 24 * 60;
    }
    if (wakeDifference < 0) {
      wakeDifference += 24 * 60;
    }
    
    int totalHours = (sleepDifference + wakeDifference) ~/ 60;
    int totalMinutes = (sleepDifference + wakeDifference) % 60;
    
    if (totalHours > 0 && totalMinutes > 0) {
      return '$totalHours hr $totalMinutes min earlier';
    } else if (totalHours > 0) {
      return '$totalHours hr earlier';
    } else {
      return '$totalMinutes min earlier';
    }
  }

  String _getShiftSize() {
    int currentSleepMinutes = currentSleepTime.hour * 60 + currentSleepTime.minute;
    int goalSleepMinutes = goalSleepTime.hour * 60 + goalSleepTime.minute;
    int currentWakeMinutes = currentWakeTime.hour * 60 + currentWakeTime.minute;
    int goalWakeMinutes = goalWakeTime.hour * 60 + goalWakeTime.minute;
    
    int sleepDifference = currentSleepMinutes - goalSleepMinutes;
    int wakeDifference = currentWakeMinutes - goalWakeMinutes;
    
    if (sleepDifference < 0) {
      sleepDifference += 24 * 60;
    }
    if (wakeDifference < 0) {
      wakeDifference += 24 * 60;
    }
    
    int totalDifference = sleepDifference + wakeDifference;
    
    // Smart shift calculation based on total difference
    if (totalDifference <= 60) {
      return '15 minutes per night';
    } else if (totalDifference <= 180) {
      return '20 minutes per night';
    } else {
      return '30 minutes per night';
    }
  }

  bool _getUse30MinuteShifts() {
    int currentSleepMinutes = currentSleepTime.hour * 60 + currentSleepTime.minute;
    int goalSleepMinutes = goalSleepTime.hour * 60 + goalSleepTime.minute;
    int currentWakeMinutes = currentWakeTime.hour * 60 + currentWakeTime.minute;
    int goalWakeMinutes = goalWakeTime.hour * 60 + goalWakeTime.minute;
    
    int sleepDifference = currentSleepMinutes - goalSleepMinutes;
    int wakeDifference = currentWakeMinutes - goalWakeMinutes;
    
    if (sleepDifference < 0) {
      sleepDifference += 24 * 60;
    }
    if (wakeDifference < 0) {
      wakeDifference += 24 * 60;
    }
    
    int totalDifference = sleepDifference + wakeDifference;
    
    // Use 30-minute shifts for larger differences, 15-minute for smaller ones
    return totalDifference > 120;
  }

  String _getDaysNeeded() {
    int currentSleepMinutes = currentSleepTime.hour * 60 + currentSleepTime.minute;
    int goalSleepMinutes = goalSleepTime.hour * 60 + goalSleepTime.minute;
    int currentWakeMinutes = currentWakeTime.hour * 60 + currentWakeTime.minute;
    int goalWakeMinutes = goalWakeTime.hour * 60 + goalWakeTime.minute;
    
    int sleepDifference = currentSleepMinutes - goalSleepMinutes;
    int wakeDifference = currentWakeMinutes - goalWakeMinutes;
    
    if (sleepDifference < 0) {
      sleepDifference += 24 * 60;
    }
    if (wakeDifference < 0) {
      wakeDifference += 24 * 60;
    }
    
    int totalDifference = sleepDifference + wakeDifference;
    
    // Smart shift size calculation
    int shiftSize;
    if (totalDifference <= 60) {
      shiftSize = 15;
    } else if (totalDifference <= 180) {
      shiftSize = 20;
    } else {
      shiftSize = 30;
    }
    
    int shiftsNeeded = (totalDifference / shiftSize).ceil();
    int daysPerShift = totalDifference <= 120 ? 1 : 2;
    int daysNeeded = shiftsNeeded * daysPerShift;
    
    return daysNeeded.toString();
  }

  String _getEndDate() {
    int days = int.tryParse(_getDaysNeeded()) ?? 0;
    DateTime endDate = DateTime.now().add(Duration(days: days));
    
    // Format as "Jan 15, 2024"
    List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    String month = months[endDate.month - 1];
    String day = endDate.day.toString();
    String year = endDate.year.toString();
    
    return '$month $day, $year';
  }

  TimeOfDay _getTodayTarget() {
    // Calculate today's target based on current progress
    int currentMinutes = currentSleepTime.hour * 60 + currentSleepTime.minute;
    int goalMinutes = goalSleepTime.hour * 60 + goalSleepTime.minute;
    
    int difference = currentMinutes - goalMinutes;
    if (difference < 0) {
      difference += 24 * 60;
    }
    
    // Smart shift size calculation
    int shiftSize;
    if (difference <= 60) {
      shiftSize = 15;
    } else if (difference <= 180) {
      shiftSize = 20;
    } else {
      shiftSize = 30;
    }
    
    // For now, return the first step (Day 1 target)
    // In a real app, you'd track which day the user is on
    int firstStepShift = shiftSize;
    int newMinutes = currentMinutes - firstStepShift;
    
    if (newMinutes < 0) {
      newMinutes += 24 * 60;
    }
    
    int hours = newMinutes ~/ 60;
    int minutes = newMinutes % 60;
    
    return TimeOfDay(hour: hours, minute: minutes);
  }

  Widget _buildCalculationRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.circle,
              color: color,
              size: 8,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // Calculate current sleep duration in hours
  double _getCurrentSleepDuration() {
    int sleepMinutes = currentSleepTime.hour * 60 + currentSleepTime.minute;
    int wakeMinutes = currentWakeTime.hour * 60 + currentWakeTime.minute;
    
    int duration = wakeMinutes - sleepMinutes;
    if (duration < 0) {
      duration += 24 * 60; // Add 24 hours if wake time is earlier
    }
    
    return duration / 60.0; // Convert to hours
  }

  // Calculate goal sleep duration in hours
  double _getGoalSleepDuration() {
    int sleepMinutes = goalSleepTime.hour * 60 + goalSleepTime.minute;
    int wakeMinutes = goalWakeTime.hour * 60 + goalWakeTime.minute;
    
    int duration = wakeMinutes - sleepMinutes;
    if (duration < 0) {
      duration += 24 * 60; // Add 24 hours if wake time is earlier
    }
    
    return duration / 60.0; // Convert to hours
  }

  // Get current sleep quality icon
  IconData _getCurrentSleepQualityIcon() {
    double duration = _getCurrentSleepDuration();
    if (duration >= 7 && duration <= 9) {
      return Icons.sentiment_satisfied_alt;
    } else if (duration >= 6 && duration < 7) {
      return Icons.sentiment_neutral;
    } else {
      return Icons.sentiment_dissatisfied;
    }
  }

  // Get current sleep quality color
  Color _getCurrentSleepQualityColor() {
    double duration = _getCurrentSleepDuration();
    if (duration >= 7 && duration <= 9) {
      return Colors.green;
    } else if (duration >= 6 && duration < 7) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // Get current sleep note
  String _getCurrentSleepNote() {
    double duration = _getCurrentSleepDuration();
    if (duration >= 7 && duration <= 9) {
      return 'You get ${duration.toStringAsFixed(1)} hours of sleep. That\'s great! 🌟';
    } else if (duration >= 6 && duration < 7) {
      return 'You get ${duration.toStringAsFixed(1)} hours of sleep. That\'s okay, but we can do better! 💪';
    } else if (duration < 6) {
      return 'You get ${duration.toStringAsFixed(1)} hours of sleep. That\'s quite low - let\'s improve this! ⚡';
    } else {
      return 'You get ${duration.toStringAsFixed(1)} hours of sleep. That\'s a bit too much - let\'s optimize! 😴';
    }
  }

  // Get goal sleep note
  String _getGoalSleepNote() {
    double currentDuration = _getCurrentSleepDuration();
    double goalDuration = _getGoalSleepDuration();
    double improvement = goalDuration - currentDuration;
    
    if (improvement > 0) {
      return 'That\'s a ${improvement.toStringAsFixed(1)} hour improvement! Nice! That gives you ${goalDuration.toStringAsFixed(1)} hours total! 🚀';
    } else if (improvement < 0) {
      return 'You\'re reducing by ${(-improvement).toStringAsFixed(1)} hours to ${goalDuration.toStringAsFixed(1)} hours total. Quality over quantity! 💎';
    } else {
      return 'Same duration (${goalDuration.toStringAsFixed(1)} hours) but better timing! ⏰';
    }
  }
}

// AI Service Classes
class AIService {
  static Future<String> generateResponse(String prompt, {String? context, String? systemPrompt}) async {
    try {
      final settings = AIConfig.getCurrentProviderSettings();
      
      // Build the full prompt with system message and context
      String fullPrompt = '';
      if (systemPrompt != null) {
        fullPrompt += '$systemPrompt\n\n';
      }
      if (context != null) {
        fullPrompt += 'Context: $context\n\n';
      }
      fullPrompt += 'User: $prompt\n\nAssistant: Let me help you with that!';
      
      print('Sending request to Gemini API...');
      print('Full prompt length: ${fullPrompt.length} characters');
      
      final response = await http.post(
        Uri.parse('${settings['baseUrl']}?key=${settings['apiKey']}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': fullPrompt,
                },
              ],
            },
          ],
          'generationConfig': {
            'temperature': AIConfig.temperature,
            'maxOutputTokens': AIConfig.maxTokensPerRequest,
            'topP': 0.8,
            'topK': 40,
          },
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['candidates'] != null && 
            data['candidates'].isNotEmpty && 
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          
          final responseText = data['candidates'][0]['content']['parts'][0]['text'];
          print('AI Response: $responseText');
          return responseText;
        } else {
          print('AI Response Error: Invalid response structure');
          print('Response data: $data');
          return AIConfig.getRandomFallback(AIConfig.fallbackSleepAdvice);
        }
      } else {
        print('AI API Error: Status code ${response.statusCode}');
        print('Error response: ${response.body}');
        return AIConfig.getRandomFallback(AIConfig.fallbackSleepAdvice);
      }
    } catch (e) {
      print('AI API Error: $e');
      return AIConfig.getRandomFallback(AIConfig.fallbackSleepAdvice);
    }
  }

  static Future<String> getSleepAdvice(TimeOfDay currentTime, TimeOfDay goalTime, int daysCompleted) async {
    String context = AIConfig.buildSleepScheduleContext(currentTime, goalTime, daysCompleted);
    String prompt = "Give me personalized advice to help me reach my sleep goal. What should I focus on next?";
    
    return await generateResponse(prompt, context: context, systemPrompt: AIConfig.personalizedAdvicePrompt);
  }

  static Future<String> getWeeklyMotivation(List<SleepProgress> weekProgress) async {
    return "Hey! How's your week going? 💫";
  }

  static Future<String> getPersonalizedTip(String userQuestion, {
    required TimeOfDay currentSleepTime,
    required TimeOfDay goalSleepTime,
    int? daysCompleted,
    bool? use30MinuteShifts,
  }) async {
    String context = AIConfig.buildSleepScheduleContext(currentSleepTime, goalSleepTime, daysCompleted ?? 0);
    
    // Add additional context if available
    if (use30MinuteShifts != null) {
      context += '\n- Shift type: ${use30MinuteShifts ? "30-minute" : "15-minute"} shifts';
    }
    
    return await generateResponse(userQuestion, context: context, systemPrompt: AIConfig.personalizedAdvicePrompt);
  }
}

class AIChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  AIChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}

class AIChatScreen extends StatefulWidget {
  final TimeOfDay currentSleepTime;
  final TimeOfDay goalSleepTime;

  const AIChatScreen({
    Key? key,
    required this.currentSleepTime,
    required this.goalSleepTime,
  }) : super(key: key);

  @override
  _AIChatScreenState createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final List<AIChatMessage> _messages = [];
  bool _isLoading = false;
  late AnimationController _loadingAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadingAnimation = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _loadingAnimation.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    String welcomeMessage = "Hey! I'm Sleep Fixer AI, your sleep science buddy! 💤 ";
    
    // Add personalized info based on their plan
    int currentMinutes = widget.currentSleepTime.hour * 60 + widget.currentSleepTime.minute;
    int goalMinutes = widget.goalSleepTime.hour * 60 + widget.goalSleepTime.minute;
    int difference = currentMinutes - goalMinutes;
    if (difference < 0) difference += 24 * 60;
    
    if (difference > 0) {
      welcomeMessage += "I see you're shifting from ${widget.currentSleepTime.hour.toString().padLeft(2, '0')}:${widget.currentSleepTime.minute.toString().padLeft(2, '0')} to ${widget.goalSleepTime.hour.toString().padLeft(2, '0')}:${widget.goalSleepTime.minute.toString().padLeft(2, '0')}. ";
    }
    
    welcomeMessage += "Ask me anything about sleep! Want more detail? Just say 'tell me more' ✨";
    
    _messages.add(AIChatMessage(
      content: welcomeMessage,
      isUser: false,
      timestamp: DateTime.now(),
    ));
    
    // Scroll to bottom after adding welcome message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  int _getDaysCompleted() {
    // For now, return 0 since we don't have actual progress tracking yet
    // In a real app, this would check actual completed days from storage
    return 0;
  }

  int _calculateTotalDaysNeeded() {
    int currentMinutes = widget.currentSleepTime.hour * 60 + widget.currentSleepTime.minute;
    int goalMinutes = widget.goalSleepTime.hour * 60 + widget.goalSleepTime.minute;
    int difference = currentMinutes - goalMinutes;
    if (difference < 0) difference += 24 * 60;
    
    // Smart shift size calculation
    int shiftSize;
    if (difference <= 60) {
      shiftSize = 15;
    } else if (difference <= 180) {
      shiftSize = 20;
    } else {
      shiftSize = 30;
    }
    
    int shiftsNeeded = (difference / shiftSize).ceil();
    int daysPerShift = difference <= 120 ? 1 : 2;
    int totalDays = shiftsNeeded * daysPerShift;
    
    return totalDays;
  }

  bool _getUse30MinuteShifts() {
    // You can enhance this to get actual plan data
    // For now, return true if the difference is large enough to warrant 30-min shifts
    int currentMinutes = widget.currentSleepTime.hour * 60 + widget.currentSleepTime.minute;
    int goalMinutes = widget.goalSleepTime.hour * 60 + widget.goalSleepTime.minute;
    int difference = currentMinutes - goalMinutes;
    if (difference < 0) difference += 24 * 60;
    
    return difference > 120; // Use 30-min shifts if difference > 2 hours
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    String userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(AIChatMessage(
        content: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    // Scroll to bottom after adding user message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Ensure minimum loading time for better UX
    final startTime = DateTime.now();
    
    try {
      // Get AI response with personalized context
      String aiResponse = await AIService.getPersonalizedTip(
        userMessage,
        currentSleepTime: widget.currentSleepTime,
        goalSleepTime: widget.goalSleepTime,
        daysCompleted: _getDaysCompleted(),
        use30MinuteShifts: _getUse30MinuteShifts(),
      );
      
      // Ensure minimum 1 second loading time
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inMilliseconds < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - elapsed.inMilliseconds));
      }
      
      // Add the AI response
      setState(() {
        _messages.add(AIChatMessage(
          content: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      
      // Scroll to bottom after adding AI response
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('Chat error: $e');
      
      // Ensure minimum 1 second loading time even for errors
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inMilliseconds < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - elapsed.inMilliseconds));
      }
      
      setState(() {
        _messages.add(AIChatMessage(
          content: "Sorry, I'm having trouble connecting right now. Please try again later.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      
      // Scroll to bottom after adding error message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [

            
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 150, 16, 16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return _buildLoadingMessage();
                  }
                  
                  AIChatMessage message = _messages[index];
                  return _buildMessage(message);
                },
              ),
            ),
            
            // Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ask me anything about sleep...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.indigo.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.indigo.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Colors.indigo),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(AIChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.nightlight,
                color: Colors.indigo,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Colors.indigo.withOpacity(0.3)
                    : Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: message.isUser
                      ? Colors.indigo.withOpacity(0.5)
                      : Colors.transparent,
                ),
              ),
              child: message.isUser
                  ? Text(
                      message.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    )
                  : _buildFormattedText(message.content),
            ),
          ),
          if (message.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text) {
    // More specific regex patterns to avoid conflicts
    final boldPattern = RegExp(r'\*\*([^*]+)\*\*');
    final italicPattern = RegExp(r'\*([^*]+)\*');
    
    // Debug: print the text to see what we're working with
    print('Parsing text: "$text"');
    
    // Check if text contains formatting
    if (!boldPattern.hasMatch(text) && !italicPattern.hasMatch(text)) {
      print('No formatting found, returning plain text');
      return Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      );
    }
    
    // Parse and build rich text
    List<TextSpan> spans = [];
    String remainingText = text;
    
    while (remainingText.isNotEmpty) {
      // Find the next bold pattern
      final boldMatch = boldPattern.firstMatch(remainingText);
      final italicMatch = italicPattern.firstMatch(remainingText);
      
      print('Remaining text: "$remainingText"');
      print('Bold match: ${boldMatch?.group(0)}');
      print('Italic match: ${italicMatch?.group(0)}');
      
      if (boldMatch != null && (italicMatch == null || boldMatch.start < italicMatch.start)) {
        // Add text before bold
        if (boldMatch.start > 0) {
          spans.add(TextSpan(
            text: remainingText.substring(0, boldMatch.start),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ));
        }
        
        // Add bold text
        spans.add(TextSpan(
          text: boldMatch.group(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ));
        
        remainingText = remainingText.substring(boldMatch.end);
      } else if (italicMatch != null) {
        // Add text before italic
        if (italicMatch.start > 0) {
          spans.add(TextSpan(
            text: remainingText.substring(0, italicMatch.start),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ));
        }
        
        // Add italic text
        spans.add(TextSpan(
          text: italicMatch.group(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ));
        
        remainingText = remainingText.substring(italicMatch.end);
      } else {
        // No more formatting, add remaining text
        spans.add(TextSpan(
          text: remainingText,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ));
        break;
      }
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildLoadingMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.nightlight,
              color: Colors.indigo,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.indigo.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Smooth pulsing white dot animation
                AnimatedBuilder(
                  animation: _loadingAnimation,
                  builder: (context, child) {
                    // Create a smooth sine wave effect for natural pulsing
                    double animationValue = _loadingAnimation.value;
                    double sineValue = (1 + math.sin(animationValue * 2 * math.pi)) / 2;
                    double scale = 0.7 + (0.3 * sineValue);
                    
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 1. Define a new page for collecting sleep/wake times for 'already sleep well' users
class AlreadySleepWellScreen extends StatefulWidget {
  final Function(TimeOfDay, TimeOfDay, bool)? onCompleted;
  const AlreadySleepWellScreen({Key? key, this.onCompleted}) : super(key: key);

  @override
  State<AlreadySleepWellScreen> createState() => _AlreadySleepWellScreenState();
}

class _AlreadySleepWellScreenState extends State<AlreadySleepWellScreen> {
  TimeOfDay sleepTime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay wakeTime = const TimeOfDay(hour: 7, minute: 0);
  bool sleepConstraint = false;
  bool wakeConstraint = false;
  bool showHelper = true;

  Future<void> _pickTime(bool isSleep) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isSleep ? sleepTime : wakeTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.indigo,
              onPrimary: Colors.white,
              surface: Colors.indigo[900]!,
              onSurface: Colors.white,
            ),
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Color(0xFF16213E),
              hourMinuteTextColor: Colors.white,
              hourMinuteColor: Colors.indigo,
              dialHandColor: Colors.indigo,
              dialBackgroundColor: Color(0xFF1A1A2E),
              dialTextColor: Colors.white,
              entryModeIconColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isSleep) {
          sleepTime = picked;
        } else {
          wakeTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      appBar: AppBar(
        backgroundColor: Colors.indigo[900],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Your Sleep Schedule', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHelper)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.withOpacity(0.4), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.indigo, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Tip: Use the "Fixed?" toggles if your times are set by work, school, or other obligations',
                          style: TextStyle(fontSize: 13, color: Colors.indigo, fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => showHelper = false),
                        icon: const Icon(Icons.close, color: Colors.indigo, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              Card(
                color: Colors.indigo[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bedtime, color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          const Text('Sleep & Wake Times', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimeTile('Sleep Time', sleepTime, () => _pickTime(true)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTimeTile('Wake Time', wakeTime, () => _pickTime(false)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildConstraintToggle('Fixed?', sleepConstraint, (v) => setState(() => sleepConstraint = v), 'Toggle if your sleep time is fixed'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildConstraintToggle('Fixed?', wakeConstraint, (v) => setState(() => wakeConstraint = v), 'Toggle if your wake time is fixed'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onCompleted?.call(sleepTime, wakeTime, sleepConstraint || wakeConstraint);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeTile(String label, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.indigo[700],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(time.format(context), style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Tap to change', style: TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _buildConstraintToggle(String label, bool value, ValueChanged<bool> onChanged, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            inactiveThumbColor: Colors.indigo[300],
            inactiveTrackColor: Colors.indigo[100],
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
