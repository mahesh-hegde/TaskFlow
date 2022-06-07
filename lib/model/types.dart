import 'dart:core';
import 'dart:math';

import '../util/time_format.dart';

class TaskList {
  TaskList(this.tasks) {
    for (var task in tasks) {
      maxPos = max(maxPos, task.position);
      completed += task.isFinished ? 1 : 0;
    }
  }

  List<TodoTask> tasks;
  int maxPos = -1, completed = 0;

  int get length => tasks.length;

  bool get isEmpty => tasks.isEmpty;

  bool get isNotEmpty => tasks.isNotEmpty;

  TodoTask operator [](int i) {
    return tasks[i];
  }

  void operator []=(int i, TodoTask value) {
    tasks[i] = value;
  }

  void clear() {
    tasks.clear();
    completed = 0;
    maxPos = -1;
  }

  int indexOf(TodoTask value) {
    return tasks.indexOf(value);
  }

  void add(TodoTask task) {
    tasks.add(task);
    task.position = ++maxPos;
    if (task.isFinished) completed++;
  }

  void notifyElementChanged(int i) {
    var task = tasks[i];
    completed += tasks[i].isFinished ? 1 : -1;
  }

  TodoTask removeAt(int i) {
    var task = tasks[i];
    if (task.isFinished) {
      completed--;
    }
    if (task.position == maxPos) {
      // recompute maxPos
      maxPos = tasks.map((x) => x.position).fold(-1, max);
    }
    return tasks.removeAt(i);
  }

  int repositionTask(int j) {
    if (tasks[j].isFinished) {
      while (j > 0 && !tasks[j - 1].isFinished) {
        // swap tasks[j], tasks[j-1];
        final temp = tasks[j];
        tasks[j] = tasks[j - 1];
        tasks[j - 1] = temp;
        j--;
      }
    } else {
      while (j != tasks.length - 1 &&
          (tasks[j + 1].position <= tasks[j].position ||
              tasks[j + 1].isFinished)) {
        // swap tasks[j], tasks[j+1]
        final temp = tasks[j];
        tasks[j] = tasks[j + 1];
        tasks[j + 1] = temp;
        j++;
      }
    }
    return j;
  }

  @override
  String toString() => 'TaskList' + {
	'tasks': tasks,
	'completed': completed,
	'maxPos': maxPos,
  }.toString();
}

class TodoTask {
  TodoTask(
      {required this.name,
      this.info = "",
      this.collapsed = false,
      this.deadline,
      this.percentage});

  TodoTask.ofName(this.name);

  // DB Fields
  late int listId;
  int? id;
  int? parentId;
  late int position;
  String name, info = "";
  bool collapsed = false;
  DateTime? finished;
  late DateTime addedOn;
  DateTime? deadline;
  double? percentage;

  TaskList subtasks = TaskList([]);

  Set<TaskNotification> notifications = {};
  TodoTask? parent;

  bool get isFinished => (finished != null);
  bool get hasSubtasks => subtasks.isNotEmpty;

  void addSubtask(TodoTask subtask) {
    subtask.parent = this;
    subtask.parentId = id;
    subtasks.add(subtask);
  }

  void removeSubtaskAt(int i) {
    subtasks.removeAt(i);
    // if all subtasks are finished
    // set this task's position
    if (finished == null &&
        hasSubtasks &&
        subtasks.completed == subtasks.length) {
      finished = subtasks.tasks
          .map((s) => s.finished!)
          .reduce((f1, f2) => f1.isBefore(f2) ? f2 : f1);
    }
  }

  static const schema =
      "CREATE TABLE IF NOT EXISTS todo_task (id INTEGER PRIMARY KEY, "
      "list_id INTEGER REFERENCES todo_list(id) ON DELETE CASCADE, "
      "parent_id INTEGER REFERENCES todo_task(id) ON DELETE CASCADE, "
      "added_on INTEGER, "
      "position INTEGER, "
      "name TEXT NOT NULL, info TEXT NOT NULL, collapsed INTEGER NOT NULL, "
      "finished INTEGER, deadline INTEGER, percentage REAL);";

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'list_id': listId,
        'parent_id': parentId,
        'position': position,
        'name': name,
        'info': info,
        'added_on': addedOn.millisecondsSinceEpoch,
        'collapsed': collapsed ? 1 : 0,
        'finished': finished?.millisecondsSinceEpoch,
        'deadline': deadline?.millisecondsSinceEpoch,
        'percentage': percentage,
      };
  TodoTask.fromMap(Map<String, dynamic> m)
      : name = m['name'],
        info = m['info'],
        listId = m['list_id'],
        id = m['id'],
        parentId = m['parent_id'],
        position = m['position'],
        addedOn = DateTime.fromMillisecondsSinceEpoch(m['added_on'] as int),
        collapsed = (m['collapsed'] as int != 0) {
    if (m['finished'] != null) {
      finished = DateTime.fromMillisecondsSinceEpoch(m['finished'] as int);
    }
    if (m['deadline'] != null) {
      deadline = DateTime.fromMillisecondsSinceEpoch(m['deadline'] as int);
    }
  }

  @override
  String toString() => toMap().toString();
}

class TodoList {
  TodoList({required this.name, this.id, this.total = 0, this.completed = 0});

  TodoList.ofName(this.name);

  int? id;
  String name;
  int total = 0, completed = 0;
  final tasks = TaskList([]);

  static const schema = "CREATE TABLE IF NOT EXISTS "
      "todo_list (id INTEGER PRIMARY KEY, name TEXT, total INTEGER NOT NULL, completed INTEGER NOT NULL);";

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'total': total,
        'completed': completed,
      };
  TodoList.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'],
        total = m['total'],
        completed = m['completed'];
  @override
  String toString() => toMap().toString();
}

enum ComponentType { active, interval }

class ScheduleComponent {
  ScheduleComponent({
    required this.duration,
    required this.name,
    this.position = -1,
    this.info = "",
    this.componentType = ComponentType.active,
    required this.schedId,
  });

  ScheduleComponent.ofName(this.name);

  int? id;
  late int schedId;
  late int position;
  int? taskListId;
  JournalRecord? record;
  String stickyNote = "";
  Duration duration = const Duration(minutes: 30);
  String name, info = "";
  ComponentType componentType = ComponentType.active;

  // Joined attribute
  late int taskListPending;

  static const schema = "create table if not exists sched_comp "
      "(id integer primary key, position integer, "
      "sched_id integer references schedule(id) on delete cascade, "
      "task_list_id integer references todo_list(id) on delete set null, "
      "duration integer not null, "
      "name text, info text, sticky_note varchar(2047), "
      "c_type integer);";

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'position': position,
        'sched_id': schedId,
        'task_list_id': taskListId,
        'sticky_note': stickyNote,
        'duration': duration.inMilliseconds,
        'name': name,
        'info': info,
        'c_type': (componentType == ComponentType.active) ? 1 : 0,
      };

  ScheduleComponent.fromMap(Map<String, dynamic> m)
      : duration = Duration(milliseconds: (m['duration'] ?? 0) as int),
        name = m['name'],
        schedId = m['sched_id'],
        position = m['position'],
        stickyNote = m['sticky_note'] ?? "",
        taskListId = m['task_list_id'],
        info = m['info'] {
    id = m['id'];
    position = m['position'];
    componentType = (m['c_type'] as int) == 1
        ? ComponentType.active
        : ComponentType.interval;
  }
  @override
  String toString() => toMap().toString();
}

class Schedule {
  Schedule({
    required this.name,
    this.reqPercent,
  });

  Schedule.ofName(this.name);

  int? id;
  String name;
  double? reqPercent;
  List<ScheduleComponent> components = [];
  List<ScheduleRepetition> repeats = [];
  static const schema = "create table if not exists schedule "
      "(id integer primary key, name text, req_percent real);";

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'req_percent': reqPercent,
      };

  Schedule.fromMap(Map<String, dynamic> m) : name = m['name'] {
    id = m['id'];
    name = m['name'];
    reqPercent = m['req_percent'];
  }
  @override
  String toString() => toMap().toString();
}

class JournalRecord {
  JournalRecord({
    required this.entry,
    this.time,
    this.componentId,
    this.taskId,
  });

  int? id;
  String entry;
  DateTime? time;
  int? componentId; // if associated with a component
  int? taskId; // if associated with a task

  static const schema =
      'CREATE TABLE IF NOT EXISTS journal_record (id INTEGER PRIMARY KEY, '
      'entry VARCHAR(2047), time INTEGER, '
      'comp_id INTEGER REFERENCES sched_comp(id), '
      'task_id INTEGER REFERENCES todo_task(id));';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'entry': entry,
        'time': time?.millisecondsSinceEpoch,
        'comp_id': componentId,
        'task_id': taskId,
      };

  JournalRecord.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        entry = m['entry'],
        time = m['time'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['time'])
            : null,
        componentId = m['comp_id'],
        taskId = m['task_id'];

  static const ftsSchema = 'CREATE VIRTUAL TABLE IF NOT EXISTS journal_fts '
      'USING fts4 (content="journal_record", entry varchar(2047));';
  Map<String, dynamic> toFtsMap() => {
        'docid': id,
        'entry': entry,
      };
  @override
  String toString() => toMap().toString();
}

class ComponentStat {
  ComponentStat({required this.componentId});

  int componentId;
  int totalMinutes = 0;
  int tunedOut = 0;
  int finishCount = 0;
  int skipCount = 0;

  static const schema = "CREATE TABLE IF NOT EXISTS comp_stat("
      "comp_id integer primary key references sched_comp(id) on delete cascade, "
      "total_minutes int, tuned_out int, finish_count int, "
      "skip_count int);";

  Map<String, dynamic> toMap() => {
        'comp_id': componentId,
        'total_minutes': totalMinutes,
        'tuned_out': tunedOut,
        'finish_count': finishCount,
        'skip_count': skipCount,
      };

  ComponentStat.fromMap(Map<String, dynamic> m)
      : componentId = m['comp_id'],
        totalMinutes = m['total_minutes'],
        tunedOut = m['tuned_out'],
        finishCount = m['finish_count'],
        skipCount = m['skip_count'];
  @override
  String toString() => toMap().toString();
}

class TaskNotification {
  TaskNotification(
      {required this.taskId,
      required this.notifyAt,
      required this.isRelative,
      this.isScheduled = false,
      this.id});
  int? id;
  // we need to create notifications when task is not saved yet
  // eg: when creating new task
  int? taskId;
  DateTime notifyAt;
  bool isRelative;
  bool isScheduled = false;

  Duration offsetFrom(DateTime deadline) => deadline.difference(notifyAt);

  static const schema = "CREATE TABLE IF NOT EXISTS notification("
      "id INTEGER PRIMARY KEY, "
      "task_id INTEGER NOT NULL REFERENCES todo_task ON DELETE CASCADE, "
      "notify_at INTEGER NOT NULL, "
      "is_sched INTEGER NOT NULL, "
      "is_rel INTEGER NOT NULL);";

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'task_id': taskId,
        'notify_at': notifyAt.millisecondsSinceEpoch,
        'is_sched': isScheduled ? 1 : 0,
        'is_rel': isRelative ? 1 : 0,
      };

  TaskNotification.fromMap(Map<String, dynamic> m)
      : taskId = m['task_id'],
        id = m['id'],
        notifyAt = DateTime.fromMillisecondsSinceEpoch(m['notify_at']),
        isRelative = m['is_rel'] == 1,
        isScheduled = m['is_sched'] == 1;

  String repr(DateTime deadline) {
    if (isRelative) {
      return formatDuration(deadline.difference(notifyAt)) + " earlier";
    }
    return formatTime(notifyAt) + " | " + formatDate(notifyAt);
  }

  @override
  bool operator ==(Object o) {
    if (o.runtimeType != runtimeType) return false;
    var other = o as TaskNotification;
    return taskId == other.taskId && notifyAt == other.notifyAt;
  }

  @override
  int get hashCode => Object.hash(taskId, notifyAt);

  TaskNotification clone() => TaskNotification(
      id: id,
      taskId: taskId,
      notifyAt: notifyAt,
      isRelative: isRelative,
      isScheduled: isScheduled);
  @override
  String toString() => toMap().toString();
}

class ScheduleRepetition {
  ScheduleRepetition(
      {required this.schedId, required this.mask, required this.notifyAt});
  int? id;
  int schedId;
  int mask; // 7-bit pattern, 1 if selected
  DateTime notifyAt;

  static const schema = "CREATE TABLE IF NOT EXISTS sched_repeat("
      "id integer primary key, "
      "sched_id integer references schedule(id) on delete cascade, "
      "mask integer, notify_at integer);";

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'sched_id': schedId,
        'mask': mask,
        'notify_at': notifyAt.millisecondsSinceEpoch,
      };

  ScheduleRepetition.fromMap(Map<String, dynamic> m)
      : schedId = m['sched_id'],
        mask = m['mask'],
        id = m['id'],
        notifyAt = DateTime.fromMillisecondsSinceEpoch(m['notify_at'] as int);
  @override
  String toString() => toMap().toString();
}

// Transient Types, calculated by queries etc..

class DeadlinesInfo {
  DeadlinesInfo(this.overdue, this.today, this.tomorrow, this.week, this.month);
  List<TodoTask> overdue, today, tomorrow, week, month;
}

class TodoListStat {
  TodoListStat(this.date);

  DateTime date;
  int tasksAdded = 0, tasksFinished = 0;
}
