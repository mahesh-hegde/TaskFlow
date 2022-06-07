// This file implements the Store class with static methods to load db
// and do CRUD operations on various entity types

import 'dart:math';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:flutter/material.dart';

import 'package:awesome_notifications/awesome_notifications.dart';

import 'types.dart';
import '../util/time_format.dart';

// Mockable DataStore class
// store is like presenter in MVP pattern
// provides all operations application UI is allowed to do
class DataStore {
  static const List<String> schemas = [
    TodoList.schema,
    TodoTask.schema,
    Schedule.schema,
    ScheduleComponent.schema,
    ComponentStat.schema,
    JournalRecord.schema,
    JournalRecord.ftsSchema,
    TaskNotification.schema,
    ScheduleRepetition.schema,
  ];

  late Database database;

  List<TodoList> todoLists = [];

  // for lookup by ID, kept in sync
  Map<int, TodoList> todoListsById = {};

  late List<Schedule> schedules;

  // we can't make a constructor async
  // so workaround with static method
  static Future<DataStore> openDB(
      {String? directory, String filename = 'store.db'}) async {
    var store = DataStore();
    WidgetsFlutterBinding.ensureInitialized();
    String dbPath;
    if (Platform.isLinux || Platform.isWindows) {
      // getDatabasesPath was returning a relative path on desktop
      dbPath = join(directory ?? Platform.environment["HOME"] ?? "", ".appdata",
          "taskflow");
      await Directory(dbPath).create(recursive: true);
    } else {
      dbPath = await getDatabasesPath();
    }
    store.database = await openDatabase(
      join(dbPath, filename),
      version: 1,
    );
    schemas.forEach(store.database.execute);
    store.database.execute('PRAGMA FOREIGN_KEYS = on;');
    await store.loadAllTodoLists();
    await store.loadAllSchedules();
    return store;
  }

  Future<void> loadAllTodoLists() async {
    final db = database;
    final List<Map<String, dynamic>> maps = await db.query('todo_list');
    for (var m in maps) {
      var todoList = TodoList.fromMap(m);
      todoLists.add(todoList);
      todoListsById[todoList.id!] = todoList;
    }
  }

  Future<void> loadAllSchedules() async {
    final db = database;
    final List<Map<String, dynamic>> maps = await db.query('schedule');
    schedules = maps.map((m) => Schedule.fromMap(m)).toList();
  }

  // oldPos, newPos refer to position variable in DB, not list index
  Future<void> moveTasks(TodoTask task, int oldPos, int newPos) async {
    await database.transaction((txn) async {
      if (oldPos > newPos) {
        await txn.rawUpdate(
            "UPDATE todo_task SET position=position+1 WHERE list_id=? AND coalesce(parent_id, -1) = ? AND position < ? AND position >= ?",
            [task.listId, task.parentId ?? -1, oldPos, newPos]);
      } else {
        await txn.rawUpdate(
            "UPDATE todo_task SET position=position-1 WHERE list_id = ? AND coalesce(parent_id, -1) = ? AND position <= ? AND position > ?",
            [task.listId, task.parentId ?? -1, newPos, oldPos]);
      }
      await txn.rawUpdate(
          "UPDATE todo_task SET position=? WHERE id=?", [newPos, task.id]);
    });
  }

  Future<void> loadNotificationsIntoTask(TodoTask task) async {
    var res = await database
        .query('notification', where: 'task_id = ?', whereArgs: [task.id!]);
    task.notifications = res.map((m) => TaskNotification.fromMap(m)).toSet();
  }

  Future<void> deleteNotificationById(int id) async {
    database.delete('notification', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> scheduleNextNotifications([scheduleAll = false]) async {
    var dbRes = await database.rawQuery(
        'SELECT n.id, n.task_id, n.notify_at, n.is_rel, n.is_sched, t.name, t.deadline '
                'FROM notification n '
                'JOIN todo_task t ON n.task_id = t.id ' +
            (scheduleAll
                ? 'WHERE is_sched = 0 AND notify_at > ?'
                : 'WHERE is_sched = 0 AND notify_at = '
                    '(SELECT MIN(notify_at) from notification where notify_at > ?)'),
        [DateTime.now().millisecondsSinceEpoch]);
    for (var notifData in dbRes) {
      var notif = TaskNotification.fromMap(notifData);
      var deadlineInt = notifData['deadline'] as int;
      var deadline = DateTime.fromMillisecondsSinceEpoch(deadlineInt);
      String message = "Due ${formatTime(deadline)}, ${formatDate(deadline)}";
      var status = await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: notif.id!,
            title: notifData['name'] as String,
            body: message,
            channelKey: 'deadline_notifications',
            category: NotificationCategory.Reminder,
          ),
          actionButtons: [
            NotificationActionButton(
              key: "dismiss",
              label: "Dismiss",
              autoDismissible: true,
            ),
            NotificationActionButton(
              key: "snooze",
              label: "Snooze (5 Minutes)",
              autoDismissible: true,
            ),
          ],
          schedule: NotificationCalendar.fromDate(
              date: notif.notifyAt, allowWhileIdle: true));
      if (status) {
        var id = notif.id;
        notif.isScheduled = true;
        await database
            .rawUpdate('UPDATE notification SET is_sched=1 WHERE id=?', [id]);
      }
    }
  }

  Future<void> updateNotifications(TodoTask task, Set<TaskNotification> oldSet,
      Set<TaskNotification> newSet) async {
    var toIns = newSet.difference(oldSet);
    var toDel = oldSet.difference(newSet);
    await database.transaction((txn) async {
      for (var notif in toDel) {
        await txn
            .delete('notification', where: 'id = ?', whereArgs: [notif.id]);
      }
      for (var notif in toIns) {
        notif.taskId = task.id;
        notif.id = await txn.insert('notification', notif.toMap());
      }
    });
    // handle scheduling of notifications
    if (!Platform.isAndroid && !Platform.isIOS) return;
    for (var notif in toDel) {
      if (notif.isScheduled) {
        await AwesomeNotifications().cancelSchedule(notif.id!);
      }
    }
    await scheduleNextNotifications();
  }

  Future<List<ScheduleRepetition>> findRepetitionsBySchedule(
      Schedule schedule) async {
    var res = await database.query('sched_repeat',
        where: 'sched_id = ?', whereArgs: [schedule.id!]);
    return res.map((m) => ScheduleRepetition.fromMap(m)).toList();
  }

  Future<void> loadTasksIntoTodoList(TodoList todoList) async {
    // clear existing tasks
    todoList.tasks.clear();
    // get a list of all tasks in list
    // sort them by finished and position
    final db = database;
    int maxInt = (1 << 63) - 1;
    var res = await db.query('todo_task',
        where: "list_id = ?",
        whereArgs: [todoList.id!],
        orderBy: "coalesce(finished, $maxInt), position");
    // order in task list should be as follows
    // all finished tasks come first in ascending order of finished time
    // then all unfinished tasks in ascending order of position
    var tasks = res.map((m) => TodoTask.fromMap(m)).toList();

    Map<int, TodoTask> tasksById =
        Map.fromEntries(tasks.map((t) => MapEntry(t.id!, t)));
    for (var i in tasks) {
      if (i.parentId != null) {
        var parent = tasksById[i.parentId]!;
        i.parent = parent;
        parent.subtasks.add(i);
      }
    }
    for (var task in tasks) {
      if (task.parent == null) {
        todoList.tasks.add(task);
      }
    }
  }

  Future<void> saveTask(TodoTask task) async {
    assert(task.id == null);
    task.addedOn = DateTime.now();
    task.id = await database.insert('todo_task', task.toMap());
    // this case is useful for both add subtask and add task
    // oldSet will be empty, thus can be handled here
    if (task.notifications.isNotEmpty) {
      await updateNotifications(task, {}, task.notifications);
    }
  }

  Future<int> updateTask(TodoTask task, [Map<String, dynamic>? changes]) async {
    return database.update('todo_task', changes ?? task.toMap(),
        where: "id = ?", whereArgs: [task.id]);
  }

  Future<void> deleteTask(TodoTask task) async {
    database.transaction((txn) async {
      if (task.deadline != null) {
        var schedNotif = await _findScheduledNotificationsByTask(txn, task);
        for (var notif in schedNotif) {
          AwesomeNotifications().cancel(notif.id!);
        }
      }
      await txn.delete('todo_task', where: 'id = ?', whereArgs: [task.id!]);
      // reset positions
      await txn.execute(
          "UPDATE todo_task SET position=position-1 WHERE list_id = ? AND parent_id = ? AND position > ?",
          [task.listId, task.parentId, task.position]);
    });
  }

  Future<void> addTodoList(TodoList todoList) async {
    assert(todoList.id == null);
    todoList.id = await database.insert('todo_list', todoList.toMap());
    todoLists.add(todoList);
    todoListsById[todoList.id!] = todoList;
  }

  Future<void> updateTodoList(TodoList todoList,
      [Map<String, dynamic>? changes]) async {}

  Future<void> deleteTodoList(int i) async {
    var todoList = todoLists.removeAt(i);
    todoListsById.remove(todoList.id!);
    database.delete('todo_list', where: 'id = ?', whereArgs: [todoList.id!]);
  }

  Future<void> addTaskToTodoList(TodoList list, TodoTask task) async {
    task.listId = list.id!;
    task.parentId = null;
    // add comes first, because it sets the position
    list.tasks.add(task);
    saveTask(task);
    list.total++;
    list.completed += task.isFinished ? 1 : 0;
    updateTodoList(list);
  }

  Future<void> deleteTaskFromTodoList(TodoList list, int i) async {
    var task = list.tasks.removeAt(i);
    if (task.isFinished) {
      list.completed--;
    }
    list.total--;
    deleteTask(task);
  }

  Future<void> addSubtask(TodoTask task, TodoTask subtask) async {
    subtask.listId = task.listId;
    subtask.parentId = task.id;
    subtask.parent = task;
    // handle changes in finished state
    // technically unreachable condition
    // because task will be faded upon completion
    if (task.isFinished) {
      toggleFinished(task);
    }
    // add comes first because it fills in position field
    task.subtasks.add(subtask);
    saveTask(subtask);
  }

  Future<void> deleteSubtask(TodoTask task, int i) async {
    var subtask = task.subtasks.removeAt(i);
    // if task was only one unfinished
    if (task.subtasks.length == task.subtasks.completed &&
        task.subtasks.isNotEmpty) {
      setFinished(
          task,
          task.subtasks.tasks
              .map((t) => t.finished!)
              .reduce((x, y) => y.isAfter(x) ? y : x));
    }
    deleteTask(subtask);
  }

  void setFinished(TodoTask task, DateTime? value) {
    var wasFinished = task.isFinished;
    task.finished = value;
    updateTask(task, {'finished': value?.millisecondsSinceEpoch});
    if (task.parent == null && wasFinished != task.isFinished) {
      var parentList = todoListsById[task.listId]!;
      parentList.completed += task.isFinished ? 1 : -1;
      updateTodoList(parentList);
    }
    // unschedule any notifications associated with task
    if (task.deadline != null && value != null) {
      database.transaction((txn) async {
        var notifications = await _findScheduledNotificationsByTask(txn, task);
        for (var i in notifications) {
          AwesomeNotifications().cancelSchedule(i.id!);
        }
        await txn.rawUpdate(
            "UPDATE notification SET is_sched=0 WHERE task_id = ?", [task.id]);
      });
    }
    // schedule notifications if unmarked
    if (task.deadline != null && value == null) {
      scheduleNextNotifications();
    }
  }

  Future<Iterable<TaskNotification>> _findScheduledNotificationsByTask(
      DatabaseExecutor executor, TodoTask task) async {
    var maps = await executor.rawQuery(
        "SELECT * FROM notification "
        "WHERE is_sched = 1 "
        "AND task_id = ?",
        [task.id],
		);
    var res = maps.map(TaskNotification.fromMap).toList();
	return res;
  }

  Future<void> toggleFinished(TodoTask task) async {
    setFinished(task, task.isFinished ? null : DateTime.now());
  }

  Future<void> toggleCollapsed(TodoTask task) async {
    task.collapsed = !task.collapsed;
    updateTask(task, {'collapsed': task.collapsed ? 1 : 0});
  }

  Future<void> notifyChildChanged(TodoTask task, int i) async {
    var subtask = task.subtasks[i];
    task.subtasks.notifyElementChanged(i);
    if (task.subtasks.completed == task.subtasks.length) {
      setFinished(task, subtask.finished);
    }
    if (task.subtasks.completed == task.subtasks.length - 1) {
      setFinished(task, null);
    }
  }

  // on Schedule Type
  Future<void> addSchedule(Schedule schedule) async {
    schedules.add(schedule);
    schedule.id = await database.insert('schedule', schedule.toMap());
  }

  Future<void> deleteSchedule(int i) async {
    var schedule = schedules.removeAt(i);
    database.delete('schedule', where: 'id = ?', whereArgs: [schedule.id!]);
  }

  Future<void> loadComponentsIntoSchedule(Schedule schedule) async {
    // TODO: IMPLEMENT DELEGATION AT CLASS DEFN LEVEL
    var res = await database.query('sched_comp',
        where: "sched_id = ?", whereArgs: [schedule.id!], orderBy: "position");
    schedule.components = res.map((m) => ScheduleComponent.fromMap(m)).toList();
  }

  void insertNewScheduleComponent(Schedule schedule, int position) {
    var component = ScheduleComponent(
        duration: const Duration(minutes: 30),
        name: '',
        position: position,
        schedId: schedule.id!);
    schedule.components.insert(position, component);
  }

  Future<void> swapComponentsInSchedule(Schedule schedule, int i, int j) async {
    // swap position parts of both components and save to db
    var x = schedule.components[i];
    var y = schedule.components[j];
    var tp = x.position;
    x.position = y.position;
    y.position = tp;

    updateComponent(x, {'position': x.position});
    updateComponent(y, {'position': y.position});

    // swap both components in array
    schedule.components[i] = y;
    schedule.components[j] = x;
  }

  Future<void> saveComponentToSchedule(Schedule schedule, int position) async {
    var component = schedule.components[position];
    if (component.id == null) {
      await database.execute(
          "update sched_comp set position=position+1 where position >= ?",
          [position]);
      component.id = await database.insert(
          'sched_comp', schedule.components[position].toMap());
      var stat = ComponentStat(componentId: component.id!);
      await database.insert('comp_stat', stat.toMap());
    } else {
      updateComponent(component);
    }
  }

  Future<void> removeComponentFromSchedule(Schedule schedule, int i) async {
    var component = schedule.components[i];
    if (component.id != null) {
      await database
          .delete('sched_comp', where: 'id = ?', whereArgs: [component.id!]);
    }
    schedule.components.removeAt(i);
  }

  Future<int> updateComponent(ScheduleComponent component,
      [Map<String, dynamic>? changes]) async {
    var res = await database.update('sched_comp', changes ?? component.toMap(),
        where: "id = ?", whereArgs: [component.id!]);
    return res;
  }

  Future<void> clearStats(int componentId) async {
    await database.execute(
        "UPDATE comp_stat SET total_minutes = 0, "
        "finish_count = 0, skip_count = 0 where comp_id = ?",
        [componentId]);
  }

  Future<ComponentStat> findComponentStat(ScheduleComponent component) async {
    var res = await database
        .query('comp_stat', where: 'comp_id = ?', whereArgs: [component.id!]);
    return ComponentStat.fromMap(res[0]);
  }

  Future<void> incrementStatMinutes(ScheduleComponent component) async {
    return database.execute(
        'UPDATE comp_stat SET total_minutes = total_minutes+1 WHERE comp_id = ?',
        [component.id!]);
  }

  Future<void> incrementStatSkipped(ScheduleComponent component) async {
    return database.execute(
        'UPDATE comp_stat SET skip_count = skip_count+1 where comp_id = ?',
        [component.id!]);
  }

  Future<void> incrementStatFinished(ScheduleComponent component) async {
    return database.execute(
        'UPDATE comp_stat SET finish_count = finish_count + 1 where comp_id = ?',
        [component.id!]);
  }

  Future<void> saveJournalRecord(JournalRecord record) async {
    record.id = await database.insert('journal_record', record.toMap());
    await database.insert('journal_fts', record.toFtsMap());
  }

  // TODO: USE TRANSACTION PROCESSING
  Future<int> deleteJournalRecord(JournalRecord record) async {
    database.delete('journal_fts', where: 'docid = ?', whereArgs: [record.id]);
    return database
        .delete('journal_record', where: 'id = ?', whereArgs: [record.id]);
  }

  Future<void> updateJournalRecord(JournalRecord record,
      [Map<String, dynamic>? changes]) async {
    var recordChanges = changes ?? record.toMap();
    if (recordChanges['entry'] != null) {
      await database.update('journal_fts', record.toFtsMap(),
          where: 'docid = ?', whereArgs: [record.id]);
    }
    await database.update('journal_record', changes ?? record.toMap(),
        where: 'id = ?', whereArgs: [record.id!]);
  }

  Future<void> saveRepetition(ScheduleRepetition repeat) async {
    repeat.id = await database.insert('sched_repeat', repeat.toMap());
  }

  Future<void> updateRepetition(ScheduleRepetition repeat) {
    return database.update('sched_repeat', repeat.toMap(),
        where: 'id = ?', whereArgs: [repeat.id]);
  }

  Future<void> deleteRepetition(ScheduleRepetition repeat) {
    return database
        .delete('sched_repeat', where: 'id = ?', whereArgs: [repeat.id]);
  }

  Future<void> loadRepetitionsIntoSchedule(Schedule schedule) async {
    var dbRes = await database
        .query('sched_repeat', where: 'sched_id = ?', whereArgs: [schedule.id]);
    schedule.repeats = dbRes.map(ScheduleRepetition.fromMap).toList();
  }

  Future<List<JournalRecord>> journalRecordsByScheduleComponent(
      ScheduleComponent component) async {
    var res = await database.query('journal_record',
        where: 'comp_id = ?', whereArgs: [component.id!], orderBy: 'time desc');
    return res.map(JournalRecord.fromMap).toList();
  }

  Future<List<JournalRecord>> journalRecordsBySchedule(
      Schedule schedule) async {
    var res = await database.rawQuery(
        'SELECT j.id, j.entry, j.time, j.comp_id, c.name '
        'FROM journal_record j JOIN sched_comp c ON c.id = j.comp_id '
        'JOIN schedule s ON c.sched_id = s.id WHERE c.sched_id = ?'
        'ORDER BY time desc;',
        [schedule.id]);
    return res.map(JournalRecord.fromMap).toList();
  }

  Future<List<JournalRecord>> findAllJournalRecords(
      [DateTimeRange? range, String searchTerm = ""]) async {
    List<Map<String, dynamic>> res;
    if (range == null && searchTerm.isEmpty) {
      res = await database.query('journal_record', orderBy: 'time desc');
    } else {
      var start = range?.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      var end = (range?.end ?? DateTime.now()).add(const Duration(days: 1));
      res = await database.rawQuery(
          'SELECT r.id, r.entry, r.time, '
                  'r.comp_id, r.task_id '
                  'FROM journal_record r '
                  'JOIN journal_fts f ON f.docid = r.id '
                  'WHERE r.time > ? and r.time < ? ' +
              (searchTerm.isNotEmpty ? 'and f.entry MATCH ? ' : '') +
              ' ORDER BY r.time DESC;',
          [
            start.millisecondsSinceEpoch,
            end.millisecondsSinceEpoch,
            if (searchTerm.isNotEmpty) searchTerm,
          ]);
    }
    return res.map(JournalRecord.fromMap).toList();
  }

  Future<List<JournalRecord>> findJournalRecordsInDateRange(
      DateTime start, DateTime end) async {
    var pastEnd = end.add(const Duration(days: 1));
    var res = await database.query('journal_record',
        where: 'time > ? and time < ?',
        whereArgs: [
          start.millisecondsSinceEpoch,
          pastEnd.millisecondsSinceEpoch
        ],
        orderBy: 'time desc');
    return res.map(JournalRecord.fromMap).toList();
  }

  Future<List<TodoTask>> findTasksWithDeadlineBetween(
      DateTime lo, DateTime hi) async {
    var res = await database.query('todo_task',
        where: 'deadline >= ? and deadline < ?',
        whereArgs: [lo.millisecondsSinceEpoch, hi.millisecondsSinceEpoch],
        orderBy: 'deadline asc');
    return res.map(TodoTask.fromMap).toList();
  }

  Future<List<TodoTask>> findOverdueTasks() async {
    var now = DateTime.now();
    var dbRes = await database.query('todo_task',
        where: 'deadline < ? and finished is null',
        whereArgs: [now.millisecondsSinceEpoch],
        orderBy: 'deadline asc');
    return dbRes.map((m) => TodoTask.fromMap(m)).toList();
  }

  Future<List<TodoListStat>> calculateTodoListStats(TodoList todoList) async {
    Map<DateTime, TodoListStat> statsByDate = {};
    if (todoList.tasks.isEmpty) {
      await loadTasksIntoTodoList(todoList);
    }
    var tasks = todoList.tasks;
    for (var task in tasks.tasks) {
      var added = task.addedOn;
      var addedDate = DateTime(added.year, added.month, added.day);
      statsByDate[addedDate] ??= TodoListStat(addedDate);
      statsByDate[addedDate]!.tasksAdded += 1;

      var finished = task.finished;
      if (finished != null) {
        var finishedDate =
            DateTime(finished.year, finished.month, finished.day);
        statsByDate[finishedDate] ??= TodoListStat(finishedDate);
        statsByDate[finishedDate]!.tasksFinished += 1;
      }
    }
    // collect all into list and sort by date
    List<TodoListStat> statList = statsByDate.values.toList();
    statList.sort((a, b) => a.date.compareTo(b.date));
    return statList;
  }

  Future<DeadlinesInfo> loadDeadlines() async {
    var now = DateTime.now();
    var year = now.year;
    var month = now.month;
    var day = now.day;
    var today = DateTime(year, month, day);
    var tomorrow = today.add(const Duration(days: 1));
    var dayAfterTomorrow = today.add(const Duration(days: 2));
    var nextWeek = today.add(Duration(days: 8 - today.weekday));
    var nextMonth = today.add(Duration(days: 31 - day));

    late List<TodoTask> _overdue, _today, _tomorrow, _week, _month;

    _overdue = await findOverdueTasks();
    _today = await findTasksWithDeadlineBetween(now, tomorrow);
    _tomorrow = await findTasksWithDeadlineBetween(tomorrow, dayAfterTomorrow);
    _week = await findTasksWithDeadlineBetween(dayAfterTomorrow, nextWeek);
    _month = await findTasksWithDeadlineBetween(nextWeek, nextMonth);

    return DeadlinesInfo(_overdue, _today, _tomorrow, _week, _month);
  }
}
