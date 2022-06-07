// This file implements the Store class with static methods to load db
// and do CRUD operations on various entity types

import 'dart:core';
import 'dart:io';

import 'types.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:flutter/widgets.dart';

class DataStore {
  static List<String> schemas = [
    TodoList.schema,
    TodoTask.schema,
    Schedule.schema,
    ScheduleComponent.schema,
    ComponentStat.schema,
    JournalRecord.schema,
    TaskNotification.schema,
    ScheduleRepetition.schema,
  ];

  static late Database database;

  static late List<TodoList> todoLists;

  static late List<Schedule> schedules;

  static Future<void> openDB({String filename = 'store.db'}) async {
    WidgetsFlutterBinding.ensureInitialized();
    String dbPath;
    if (Platform.isLinux) {
      dbPath = join(Platform.environment["HOME"] ?? "", ".config/taskflow");
      await Directory(dbPath).create(recursive: true);
    } else {
      dbPath = await getDatabasesPath();
    }
    database = await openDatabase(
      join(dbPath, filename),
      onCreate: (db, ver) => schemas.forEach(db.execute),
      version: 1,
    );
  }

  static Future<void> loadAllTodoLists() async {
    final db = database;
    final List<Map<String, dynamic>> maps = await db.query('todo_list');
    todoLists = maps.map((m) => TodoList.fromMap(m)).toList();
  }

  static Future<void> loadAllSchedules() async {
    final db = database;
    final List<Map<String, dynamic>> maps = await db.query('schedule');
    schedules = maps.map((m) => Schedule.fromMap(m)).toList();
  }

  static Future<List<TaskNotification>> findNotificationsByTaskId(
      int taskId) async {
    var res = await database
        .query('notification', where: 'task_id = ?', whereArgs: [taskId]);
    return res.map((m) => TaskNotification.fromMap(m)).toList();
  }

  static Future<List<ScheduleRepetition>> findRepetitionsByScheduleId(
      int schedId) async {
    var res = await database
        .query('sched_repeat', where: 'sched_id = ?', whereArgs: [schedId]);
    return res.map((m) => ScheduleRepetition.fromMap(m)).toList();
  }

  static Future<List<TodoTask>> findTasksByTodoListId(int listId) async {
    // get a list of all tasks in list
    // sort them by finished and position
    final db = database;
    int maxInt = (1 << 63) - 1;
    var res = await db.query('todo_task',
        where: "list_id = ?",
        whereArgs: [listId],
        orderBy: "coalesce(finished, $maxInt), position");
    // order in task list should be as follows
    // all finished tasks come first in ascending order of finished time
    // then all unfinished tasks in ascending order of position
    var tasks = res.map((m) => TodoTask.fromMap(m)).toList();

    // create a map indexed by task ID
    Map<int, TodoTask> taskMap =
        Map.fromEntries(tasks.map((t) => MapEntry(t.id!, t)));
    for (var i in tasks) {
      if (i.parentId != null) {
        var parent = taskMap[i.parentId]!;
        parent.subtasks.add(i);
      }
    }
    tasks.retainWhere((task) => task.parentId == null);
    return tasks;
  }

  static Future<List<ScheduleComponent>> findComponentsByScheduleId(
      int schedId) async {
    // TODO: IMPLEMENT DELEGATION AT CLASS DEFN LEVEL
    var res = await database.query('sched_comp',
        where: "sched_id = ?", whereArgs: [schedId], orderBy: "position");
    var components = res.map((m) => ScheduleComponent.fromMap(m)).toList();
    return components;
  }

  // on Task
  static Future<void> saveTask(TodoTask task) async {
    assert(task.id == null);
    task.addedOn = DateTime.now();
    task.id = await database.insert('todo_task', task.toMap());
  }

  static Future<int> updateTask(int id, Map<String, dynamic> changes) async {
    var res = await database
        .update('todo_task', changes, where: "id = ?", whereArgs: [id]);
    return res;
  }

  static Future<int> deleteTask(int id) async {
    var res =
        await database.delete('todo_task', where: 'id = ?', whereArgs: [id]);
    return res;
  }

  // ON TODOLIST TYPE
  static Future<void> saveTodoList(TodoList list) async {
    assert(list.id == null);
    list.id = await database.insert('todo_list', list.toMap());
  }

  static Future<void> clearStats(int componentId) async {
    await database.execute(
        "UPDATE comp_stat SET total_minutes = 0, "
        "finish_count = 0, skip_count = 0 where comp_id = ?",
        [componentId]);
  }
}
