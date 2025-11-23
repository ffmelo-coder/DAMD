import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/task.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const String channelId = 'task_reminders';
  static const String channelName = 'Lembretes de Tarefas';
  static const String channelDescription =
      'Notificações para lembretes de tarefas';
  bool _isSupported = true;

  Future<void> initialize() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        _isSupported = false;
        return;
      }

      tz.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      await _createNotificationChannel();
    } catch (e) {
      _isSupported = false;
    }
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
    );

    const AndroidNotificationChannel geofenceChannel =
        AndroidNotificationChannel(
          'geofence_alerts',
          'Alertas de Localização',
          description: 'Notificações quando você entra ou sai de áreas',
          importance: Importance.high,
        );

    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImplementation?.createNotificationChannel(channel);
    await androidImplementation?.createNotificationChannel(geofenceChannel);
  }

  void _onNotificationResponse(NotificationResponse response) {}

  Future<void> scheduleTaskReminder(Task task) async {
    if (!_isSupported || task.reminderTime == null) return;

    try {
      final scheduledDate = tz.TZDateTime.from(task.reminderTime!, tz.local);

      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        return;
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        task.id.hashCode,
        'Lembrete: ${task.title}',
        task.description.isNotEmpty
            ? task.description
            : 'Você tem uma tarefa pendente',
        scheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id,
      );
    } catch (e) {}
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (!_isSupported) return;

    try {
      await _flutterLocalNotificationsPlugin.cancel(taskId.hashCode);
    } catch (e) {}
  }

  Future<void> scheduleOverdueAlert(Task task) async {
    if (!_isSupported || !task.isOverdue || task.completed) return;

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFFFF5252),
            ledColor: Color(0xFFFF5252),
            ledOnMs: 1000,
            ledOffMs: 500,
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        task.id.hashCode + 10000,
        '⚠️ Tarefa Vencida',
        '${task.title} - Venceu em ${_formatDate(task.dueDate!)}',
        platformChannelSpecifics,
        payload: task.id,
      );
    } catch (e) {}
  }

  Future<void> scheduleDueTodayAlert(List<Task> tasks) async {
    if (!_isSupported || tasks.isEmpty) return;

    try {
      final taskCount = tasks.length;
      final taskNames = tasks.take(3).map((task) => task.title).join(', ');
      final message = taskCount == 1
          ? taskNames
          : taskCount <= 3
          ? '$taskNames'
          : '$taskNames e mais ${taskCount - 3}';

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFFFF9800),
            ledColor: Color(0xFFFF9800),
            ledOnMs: 1000,
            ledOffMs: 500,
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        20000,
        '🔥 $taskCount tarefa${taskCount == 1 ? '' : 's'} vence${taskCount == 1 ? '' : 'm'} hoje!',
        message,
        platformChannelSpecifics,
      );
    } catch (e) {}
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<bool> requestPermissions() async {
    if (!_isSupported) return false;

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      return await androidImplementation?.requestNotificationsPermission() ??
          false;
    }

    if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iOSImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();

      return await iOSImplementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  Future<void> cancelAllNotifications() async {
    if (!_isSupported) return;
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> showGeofenceNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isSupported) return;

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'geofence_alerts',
            'Alertas de Localização',
            channelDescription:
                'Notificações quando você entra ou sai de áreas',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFF9C27B0),
            playSound: true,
            enableVibration: true,
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {}
  }
}
