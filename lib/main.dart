import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import 'model/types.dart';
import 'model/store.dart';

import 'view/add_delete_listview.dart';
import 'view/todo_list_view.dart';
import 'view/schedule_editor.dart';
import 'view/schedule_view.dart';
import 'view/deadlines.dart';
import 'view/journal_view.dart';

import 'dart:io';
import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

void initializeNotifications(DataStore db) {
  AwesomeNotifications().initialize(
      // the default app icon
      null,
      [
        NotificationChannel(
            channelGroupKey: 'basic_channel_group',
            channelKey: 'schedule_notifications',
            importance: NotificationImportance.High,
            channelName: 'Schedule notifications',
            channelDescription: 'Notification channel for schedules',
            defaultColor: const Color(0xFF9D50DD),
            ledColor: Colors.white),
        NotificationChannel(
          channelGroupKey: 'basic_channel_group',
          channelKey: 'deadline_notifications',
          importance: NotificationImportance.High,
          channelName: 'Deadlines & Reminders',
          channelDescription: 'Deadlines / Reminders on Tasks',
        )
      ],
      debug: true);
  AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      AwesomeNotifications().requestPermissionToSendNotifications(
        permissions: [
          NotificationPermission.Sound,
          NotificationPermission.Alert,
          NotificationPermission.FullScreenIntent
        ],
      );
    }
  });
  AwesomeNotifications().displayedStream.listen((recv) async {
    if (recv.channelKey == 'deadline_notifications' && recv.id != null) {
      await db.deleteNotificationById(recv.id!);
      await db.scheduleNextNotifications();
    }
  });
  AwesomeNotifications().actionStream.listen((ReceivedAction recv) async {
    if (recv.channelKey == 'deadline_notifications') {
      if (recv.buttonKeyPressed == "snooze") {
        AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: recv.id!,
              title: recv.title,
              body: recv.body,
              channelKey: 'deadline_notifications',
              category: NotificationCategory.Reminder,
            ),
            actionButtons: [
              NotificationActionButton(
                key: "dismiss",
                label: "Dismiss",
                // autoDismissible: true,
                showInCompactView: true,
              ),
              NotificationActionButton(
                key: "snooze",
                label: "Snooze (5 Minutes)",
                // autoDismissible: true,
                showInCompactView: true,
              ),
            ],
            schedule: NotificationCalendar.fromDate(
              date: DateTime.now().add(const Duration(minutes: 5)),
              allowWhileIdle: true,
            ));
      }
    }
  });
}

Future<void> initializeDbDrivers() async {
  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory
    databaseFactory = databaseFactoryFfi;
  }
}

Future<void> main() async {
  // Sqflite.devSetDebugModeOn(true);
  initializeDbDrivers();
  var db = await DataStore.openDB(filename: 'store.db');
  if (Platform.isAndroid || Platform.isIOS) {
    initializeNotifications(db);
  }
  runApp(MyApp(db: db));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key, required this.db}) : super(key: key);
  final DataStore db;
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      theme: ThemeData(
        colorScheme: ColorScheme.highContrastDark(
            primary: Colors.teal[200]!, background: Colors.black),
      ),
      home: MyHomePage(title: "TaskFlow", db: db),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key, required this.db, required this.title})
      : super(key: key);

  final String title;
  final DataStore db;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 3,
        child: Scaffold(
            appBar: AppBar(
                title: const Text("TaskFlow"),
                actions: [
                  IconButton(
                    tooltip: "Journal",
                    icon: const Icon(Icons.book),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => JournalView(db: db))),
                  )
                ],
                bottom: const TabBar(tabs: [
                  Tab(
                      icon: Icon(
                        Icons.checklist,
                        size: 20.0,
                      ),
                      text: "TODO Lists"),
                  Tab(icon: Icon(Icons.timer, size: 20.0), text: "Schedules"),
                  Tab(icon: Icon(Icons.alarm, size: 20.0), text: "Deadlines"),
                ])),
            body: TabBarView(
              children: [
                AllTodoLists(db: db),
                AllSchedules(db: db),
                DeadlinesList(db: db),
              ],
            )));
  }
}

class AllTodoLists extends StatelessWidget {
  const AllTodoLists({Key? key, required this.db}) : super(key: key);

  final DataStore db;

  @override
  Widget build(BuildContext context) {
    return AddDeleteListView<TodoList>(
      leadingIcon: const Icon(Icons.checklist_sharp),
      titleBuilder: (context, todolist) => Text(todolist.name),
      inputHint: "Create new list",
      onAdd: db.addTodoList,
      onDelete: db.deleteTodoList,
      onTap: (i) async {
        await db.loadTasksIntoTodoList(db.todoLists[i]);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TodoListView(db, db.todoLists[i])));
      },
      fromString: TodoList.ofName,
      backingList: db.todoLists,
    );
  }
}

class AllSchedules extends StatelessWidget {
  const AllSchedules({Key? key, required this.db}) : super(key: key);

  final DataStore db;

  @override
  Widget build(BuildContext context) {
    return AddDeleteListView<Schedule>(
      leadingIcon: const Icon(Icons.list_alt_rounded),
      titleBuilder: (context, sched) => Text(sched.name),
      inputHint: "Create new schedule",
      onAdd: db.addSchedule,
      onDelete: db.deleteSchedule,
      onPressEdit: (i) async {
        await db.loadComponentsIntoSchedule(db.schedules[i]);
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ScheduleEditor(db: db, schedule: db.schedules[i]),
            ));
      },
      onTap: (i) async {
        await db.loadComponentsIntoSchedule(db.schedules[i]);
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ScheduleView(db: db, schedule: db.schedules[i]),
            ));
      },
      fromString: Schedule.ofName,
      backingList: db.schedules,
    );
  }
}
