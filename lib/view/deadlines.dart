import 'package:flutter/material.dart';

import '../model/types.dart';
import '../model/store.dart';

import 'checklist.dart';

class DeadlinesList extends StatefulWidget {
  const DeadlinesList({required this.db, Key? key}) : super(key: key);

  final DataStore db;

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
    widget.db.loadDeadlines().then((res) {
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
    List<Widget> titleAndCheckListFor(
        Widget name, List<TodoTask> allTasks, bool showDone) {
      var tasks =
          showDone ? allTasks : allTasks.where((t) => !t.isFinished).toList();
      return [
        if (tasks.isNotEmpty) name,
        if (tasks.isNotEmpty)
          CheckList(
            tasks: TaskList(tasks),
            db: widget.db,
            isOriginalList: false,
          ),
      ];
    }

    var listsByTitle = {
      "Today": deadlines.today,
      "Tomorrow": deadlines.tomorrow,
      "This Week": deadlines.week,
      "This Month": deadlines.month
    };

    void onShowDoneChanged(bool? s) {
      if (s == null) return;
      _showDone = s;
      setState(() {});
    }

    var showDoneOption = GestureDetector(
        onTap: () => onShowDoneChanged(!_showDone),
        child: Card(
            color: Colors.purple[800],
            child: Row(children: [
              Checkbox(
                value: _showDone,
                onChanged: onShowDoneChanged,
              ),
              const Expanded(child: Text("Show finished tasks")),
            ])));

    var deadlinesListView = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          if (deadlines.overdue.isNotEmpty)
            ...titleAndCheckListFor(
                Text("Overdue",
                    style: TextStyle(fontSize: headerSize, color: Colors.red)),
                deadlines.overdue,
                false),
          for (var title in listsByTitle.keys)
            if (listsByTitle[title]!.isNotEmpty)
              ...titleAndCheckListFor(Text(title, style: headerStyle),
                  listsByTitle[title]!, _showDone)
        ]);

    return RefreshIndicator(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [deadlinesListView, showDoneOption]),
      onRefresh: () async {
        deadlines = await widget.db.loadDeadlines();
        setState(() {});
      },
    );
  }
}
