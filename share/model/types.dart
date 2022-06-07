import 'dart:core';

class TodoTask {
  TodoTask(
      {required this.name,
      required this.listId,
      this.info = "",
      this.deadline,
      required this.position,
      this.percentage});

  int listId;
  int? id, parentId;
  int position;
  // For a new task added, position is set positive, 1 + topmost task (order by position desc)
  // a finished task can be displayed later, but its real position is taken into consideration by stateful widget

  String name, info;
  bool collapsed = false;
  DateTime? finished;
  late DateTime addedOn;
  DateTime? deadline;
  double? percentage; // TODO: NOT IMPLEMENTED

  // Don't put this in constructor
  // then we have to provide a default value
  // we give [], dart analyzer pleads us to put const []
  // Occassionally it may result in a 'immutable list modified' error
  List<TodoTask> subtasks = [];

  // Lazy fetch:
  // When a task is being edited or viewed in detail
  // Or for reminder purpose: sort by notify_at

  List<TaskNotification> notifications = [];

  bool get hasSubtasks => subtasks.isNotEmpty;

  bool get isFinished => (finished != null);

  static const schema =
      "create table if not exists todo_task (id integer primary key, "
      "list_id integer references todo_list(id) on delete cascade, "
      "parent_id integer references todo_task(id) on delete cascade, "
      "added_on integer, "
      "position integer, "
      "name text not null, info text not null, collapsed integer not null, "
      "finished integer, deadline integer, percentage real);";

  // Lol no official ORM
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
        position = m['position'],
        addedOn = DateTime.fromMillisecondsSinceEpoch(m['added_on'] as int),
        collapsed = (m['collapsed'] as int != 0),
        subtasks = [] {
    id = m['id'];
    parentId = m['parent_id'];
    if (m['finished'] != null) {
      finished = DateTime.fromMillisecondsSinceEpoch(m['finished'] as int);
    }
    if (m['deadline'] != null) {
      deadline = DateTime.fromMillisecondsSinceEpoch(m['deadline'] as int);
    }
    percentage = m['percentage'];
  }

  @override
  String toString() {
    var m = toMap();
    m['subtasks'] = subtasks;
    return m.toString();
  }
}

class TodoList {
  TodoList({required this.name, required this.tasks});
  int? id;
  String name; // pRiMaRy kEy
  int total = 0, completed = 0;
  // Important: Update these after any first level task is changed
  List<TodoTask> tasks;

  static const schema = "create table if not exists "
      "todo_list (id integer primary key, name text, total integer not null, completed integer not null);";

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'total': total,
        'completed': completed,
      };
  TodoList.fromMap(Map<String, dynamic> m)
      : name = m['name'],
        tasks = [] {
    id = m['id'];
    name = m['name'];
    total = m['total'];
    completed = m['completed'];
  }
  @override
  String toString() {
    return toMap().toString();
  }
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

  int? id;
  int schedId;
  int position;
  int? taskListId;
  String stickyNote = "";
  JournalRecord? tRecord;
  Duration duration;
  String name, info;
  ComponentType componentType = ComponentType.active;

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
}

class ScheduleRepetition {
  ScheduleRepetition(
      {required this.schedId, required this.mask, required this.notifyAt});
  int schedId;
  int mask; // 7-bit pattern, 1 if selected
  DateTime notifyAt;

  static const schema = "CREATE TABLE IF NOT EXISTS sched_repeat("
		  "sched_id integer, mask integer, notify_at integer, "
		  "primary key(sched_id, mask, notify_at));";

  Map<String, dynamic> toMap() => {
	'sched_id': schedId,
	'mask': mask,
	'notify_at': notifyAt,
  };

  ScheduleRepetition.fromMap(Map<String, dynamic> m):
	  schedId = m['sched_id'], mask = m['mask'], notifyAt = m['notify_at'];
}

class Schedule {
  Schedule({
    required this.name,
    this.reqPercent,
  });

  int? id;
  String name;
  double? reqPercent;
  int? done = 0, total = 0;
  List<ScheduleRepetition> repetitions = [];
  List<ScheduleComponent> components = [];

  static const schema = "create table if not exists schedule "
      "(id integer primary key, name text, req_percent real);";

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'req_percent': reqPercent,
      };

  Schedule.fromMap(Map<String, dynamic> m)
      : name = m['name'],
        components = [] {
    id = m['id'];
    name = m['name'];
    reqPercent = m['req_percent'];
  }
}

class JournalRecord {
  JournalRecord({
    required this.entry,
    this.begin,
    this.end,
    this.componentId,
    this.taskId,
  });

  int? id;
  String entry;
  DateTime? begin, end;
  int? componentId; // if associated with a component
  int? taskId; // if associated with a task

  static const schema =
      'CREATE TABLE IF NOT EXISTS journal_entry (id INTEGER PRIMARY KEY, '
      'entry VARCHAR(2047), begin INTEGER, end INTEGER, '
      'comp_id INTEGER REFERENCES sched_comp(id), '
      'task_id INTEGER REFERENCES todo_task(id));';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'entry': entry,
        'begin': begin,
        'end': end,
        'comp_id': componentId,
        'task_id': taskId,
      };

  JournalRecord.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        entry = m['entry'],
        begin = m['begin'],
        end = m['end'],
        componentId = m['comp_id'],
        taskId = m['task_id'];
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
}

// There can be multiple notifications per task
class TaskNotification {
  TaskNotification({required this.taskId, required this.notifyAt});
  int taskId;
  DateTime notifyAt;

  static const schema = "CREATE TABLE IF NOT EXISTS notification("
      "task_id int references todo_task on delete cascade, "
      "notify_at int, "
      "primary key(task_id, notify_at));";
  Map<String, dynamic> toMap() => {
        'task_id': taskId,
        'notify_at': notifyAt,
      };

  TaskNotification.fromMap(Map<String, dynamic> m)
      : taskId = m['taskId'],
        notifyAt = m['notify_at'];
}

