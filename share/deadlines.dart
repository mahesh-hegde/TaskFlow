import 'package:flutter/material.dart';

import 'model/types.dart';
import 'model/store.dart';

import 'checklist.dart';

// list of tasks having
// deadline overdue and unfinished

// 1. deadline this day

// 2. deadline next day

// 3. deadline in current week but not next day

// 4. deadline in next 30 days

class DeadlinesInfo {
  DeadlinesInfo(this.overdue, this.today, this.tomorrow, this.week, this.month);
  List<TodoTask> overdue, today, tomorrow, week, month;
}

Future<List<TodoTask>> findTasksWithDeadlineBetween(
    DateTime lower, DateTime upper) async {
  var dbRes = await DataStore.database.query('todo_task',
      where: 'deadline >= ? and deadline < ?',
      whereArgs: [lower.millisecondsSinceEpoch, upper.millisecondsSinceEpoch],
      orderBy: 'deadline asc');
  return dbRes.map((m) => TodoTask.fromMap(m)).toList();
}

Future<List<TodoTask>> findOverdueTasks() async {
  var now = DateTime.now();
  var dbRes = await DataStore.database.query('todo_task',
      where: 'deadline < ? and finished is null',
      whereArgs: [now.millisecondsSinceEpoch],
      orderBy: 'deadline asc');
  return dbRes.map((m) => TodoTask.fromMap(m)).toList();
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

class DeadlinesList extends StatefulWidget {
  const DeadlinesList({Key? key}) : super(key: key);

  @override
  _DeadlinesListState createState() => _DeadlinesListState();
}

class _DeadlinesListState extends State<DeadlinesList> {
  bool _showDone = true;

  // since we can't make initState() async
  // we attach a callback to future
  // that set _isLoading to false
  // Until then, loading text can be displayed
  bool _isLoading = true;

  late DeadlinesInfo deadlines;

  @override
  void initState() {
    super.initState();
    loadDeadlines().then((res) {
      deadlines = res;
      _isLoading = false;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Text("Loading...");

    final headerStyle = Theme.of(context).textTheme.headline5!;
    final headerSize = headerStyle.fontSize;
    // Refresh-able view of 4 task checklists
    List<Widget> checkListOf(
        Widget name, List<TodoTask> allTasks, bool showDone) {
      var tasks =
          showDone ? allTasks : allTasks.where((t) => !t.isFinished).toList();
      return [
        if (tasks.isNotEmpty) name,
        if (tasks.isNotEmpty)
          CheckList(
            tasks: tasks,
          ),
      ];
    }

    var listsByTitle = {
      "Today": deadlines.today,
      "Tomorrow": deadlines.tomorrow,
      "This Week": deadlines.week,
      "This Month": deadlines.month
    };

    var showDoneOption = Card(
        color: Colors.purple[800],
        child: Row(children: [
          Checkbox(
            value: _showDone,
            onChanged: (s) {
              if (s == null) return;
              _showDone = s;
              setState(() {});
            },
          ),
          const Expanded(child: Text("Show finished tasks")),
        ]));

    var deadlinesListView = ListView(shrinkWrap: true, children: [
      if (deadlines.overdue.isNotEmpty)
        ...checkListOf(
            Text("Overdue",
                style: TextStyle(fontSize: headerSize, color: Colors.red)),
            deadlines.overdue,
            false),
      for (var title in listsByTitle.keys)
        if (listsByTitle[title]!.isNotEmpty)
          ...checkListOf(
              Text(title, style: headerStyle), listsByTitle[title]!, _showDone)
    ]);

    return RefreshIndicator(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [deadlinesListView, showDoneOption]),
      onRefresh: () async {
        deadlines = await loadDeadlines();
        setState(() {});
      },
    );
  }
}
