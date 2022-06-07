import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'model/types.dart';
import 'model/store.dart';

import 'text_edit_dialog.dart';

class ScheduleView extends StatefulWidget {
  const ScheduleView({Key? key}) : super(key: key);

  @override
  _ScheduleViewState createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  bool get _isRunning => _timer != null;

  Timer? _timer;
  int _ticks = 0; // 10-second ticks that passed in current component
  int _pastMinutes = 0; // minutes passed in all previous components

  int get _minutes => (_ticks / 6).floor();

  int _index = 0;

  bool _allDone = false;

  bool _started = false;
  bool _waiting = false;

  late Schedule _schedule;

  void _onTick(Timer timer) {
    var comps = _schedule.components;
    _ticks++;
    if (_ticks % 6 == 0) {
      DataStore.database.execute(
        "update comp_stat set total_minutes = total_minutes + 1"
        " where comp_id = ?;",
        [comps[_index].id!],
      );
    }
    var assignedMinutes = comps[_index].duration.inMinutes;
    if (_minutes >= assignedMinutes) {
      // wait for confirmation
      _waiting = true;
      if (Platform.isAndroid || Platform.isIOS) {
	  AwesomeNotifications().createNotification(
          content: NotificationContent(
              id: 10,
              channelKey: 'basic_channel',
			  displayOnForeground: true,
              title: 'Time over'));
	  }
      _timer?.cancel();
      _timer = null;
    }
    if (mounted) setState(() {});
  }

  Timer _startTimer() => Timer.periodic(const Duration(seconds: 1), _onTick);

  void _toggleRunning() {
    _started = true;
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _timer = null);
    } else {
      _timer = _startTimer();
      setState(() {});
    }
  }

  void _resetTicks() {
    // cancel and restart the timer in order to skip any remaining seconds from previous task
    _timer?.cancel();
    _timer = _startTimer();

    _pastMinutes += _minutes;
    _ticks = 0;
  }

  void _markAllDone() {
    _timer?.cancel();
    _timer = null;
    _allDone = true;
  }

  void _gotoNext() {
    setState(() {
	  if (_index != _schedule.components.length - 1) {
      	_resetTicks();
	  } else {
		_pastMinutes += _minutes;
	  }
      _waiting = false;
      if (_index == _schedule.components.length - 1) {
        _markAllDone();
      }
      _index = min(_index + 1, _schedule.components.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    _schedule = ModalRoute.of(context)!.settings.arguments as Schedule;
    var comps = _schedule.components;
    var assignedMinutes =
        comps.isNotEmpty ? comps[_index].duration.inMinutes : 0;
    var fab = FloatingActionButton(
      child: Icon(_allDone
          ? Icons.done_all_sharp
          : (_isRunning ? Icons.pause : Icons.play_arrow)),
      backgroundColor:
          (_allDone || comps.isEmpty) ? Colors.grey : Colors.teal[600],
      onPressed:
          (_schedule.components.isEmpty || _allDone) ? null : _toggleRunning,
    );
    var noComponentsMessage = Center(
        child: Column(children: const [
      Text("No components found."
          "Add a few components through Edit button in Previous screen.")
    ]));

    // Set message text that appears above stepper UI
    var _messageText = "Schedule not running";
    var _messageColor = Colors.purple;
    if (_started) {
      _messageText = _allDone ? "Done" : (_isRunning ? "Running" : "Paused");

      var _spentMinutes = _pastMinutes + _minutes;
      if (_spentMinutes > 1 && _isRunning) {
        _messageText += " ($_spentMinutes minutes).";
      }
      _messageColor =
          _allDone ? Colors.green : (_isRunning ? Colors.blue : Colors.brown);
    }

    var message = Row(children: [
      Expanded(
          child: Card(
              child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(_messageText)),
              color: _messageColor[800]))
    ]);

    var stepper = comps.isEmpty
        ? noComponentsMessage
        : Stepper(
            currentStep: _index,
			controlsBuilder: (context, _) {
              return const Divider();
            },
            steps: [
              for (var comp in comps)
                // title: name, content: description, progress, buttons
                Step(
					state: (_index > comp.position || _allDone) ? StepState.complete : StepState.indexed,
                    title: ComponentTitle(comp),
                    content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (comp.info.isNotEmpty)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(comp.info,
                                    style: const TextStyle(fontSize: 13.0))),
                          Row(children: [
                            Expanded(
                                child: LinearProgressIndicator(
                              value: (_ticks) /
                                  (comps[_index].duration.inMinutes * 6),
                            )),
                            Text('       $_minutes / $assignedMinutes minutes',
                                style: const TextStyle(color: Colors.grey)),
                          ]),
                          if (_waiting)
                            const Text("Time Over!!",
                                style: TextStyle(color: Colors.red)),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                    icon: _allDone
                                        ? const Icon(Icons.done_all,
                                            color: Colors.grey)
                                        : Icon(
                                            _waiting
                                                ? Icons.done_all
                                                : Icons.done,
                                            color: Colors.green[500]),
                                    tooltip: "Early Finish",
                                    onPressed: _allDone
                                        ? null
                                        : () {
                                            var comp = comps[_index];
                                            DataStore.database.execute(
                                              "update comp_stat set finish_count = finish_count+1"
                                              " where comp_id = ?;",
                                              [comp.id!],
                                            );
                                            // save finished to DB
                                            _gotoNext();
                                          }),
                                Tooltip(
                                    message: "Add 5 Minutes",
                                    child: TextButton(
                                      child: const Text("+5"),
                                      onPressed: () => setState(() {
                                        comp.duration +=
                                            const Duration(minutes: 5);
                                        _timer ??= _startTimer();
                                      }),
                                    )),
                                IconButton(
                                  icon: const Icon(Icons.next_plan_outlined,
                                      color: Colors.purple),
                                  tooltip: "Skip",
                                  onPressed: () => setState(() {
                                    var comp = comps[_index];
                                    // save skipped to DB
                                    DataStore.database.execute(
                                      "update comp_stat set skip_count = skip_count+1"
                                      " where comp_id = ?;",
                                      [comp.id!],
                                    );
                                    _gotoNext();
                                  }),
                                ),
                              ])
                        ])),
            ],
          );
    return Scaffold(
      appBar: AppBar(
        title: Text(_schedule.name),
      ),
      body: Column(children: [
        message,
        // wrap in Expanded to avoid overflow
        Expanded(child: SingleChildScrollView(child: stepper)),
      ]),
      floatingActionButton: fab,
    );
  }
}

class ComponentTitle extends StatefulWidget {
  ComponentTitle(this.comp, {Key? key}) : super(key: key);

  ScheduleComponent comp;

  @override
  _ComponentTitleState createState() => _ComponentTitleState();
}

class _ComponentTitleState extends State<ComponentTitle> {
  late ScheduleComponent comp;

  @override
  void initState() {
    super.initState();
    comp = widget.comp;
  }

  Future<ComponentStat> _getStatForComponent() async {
    var dbRes = await DataStore.database.query(
      'comp_stat',
      where: 'comp_id = ?',
      whereArgs: [comp.id!],
    );
    return ComponentStat.fromMap(dbRes[0]);
  }

  void _showJournalEditor() async {
    var record = comp.tRecord!;
    record.entry = await showDialog(
      context: context,
      builder: (context) => TextEditDialog(
        initialText: record.entry,
        title: "Journal Entry for ${comp.name}",
        textLabel: "Journal Entry",
      ),
    );
TodoList   // delete & return if entry was cleared.
JournalRecordBase   if (record.entry.isEmpty) {
      comp.tRecord = null;
      await DataStore.database.delete(
        'journal_entry',
        where: 'id = ?',
        whereArgs: [record.id],
      );
    }
    setState(() {});
TodoListBase   await DataStore.database.update('journal_entry', {'entry': record.entry},
        where: 'id = ?', whereArgs: [record.id]);
  }

  void _createJournalEntry() async {
    comp.tRecord = JournalRecord(entry: '', componentId: comp.id!);
    var record = comp.tRecord!;
    record.id =
        await DataStore.database.insert('journal_entry', record.toMap());
  }

  void _showStickyNoteEditor() async {
    comp.stickyNote = await showDialog(
      context: context,
      builder: (context) => TextEditDialog(
        initialText: comp.stickyNote,
        textLabel: "Sticky Note",
        title: "Sticky Note for ${comp.name}",
      ),
    );
    await DataStore.database.update(
        'sched_comp', {'sticky_note': comp.stickyNote},
        where: 'id = ?', whereArgs: [comp.id!]);
    setState(() {});
  }

  Widget _buttonWithText(IconData icon, Color color, String text) {
    return Row(children: [
      Padding(
        padding: const EdgeInsets.only(
            left: 4.0, right: 12.0, top: 10.0, bottom: 10.0),
        child: Icon(icon, color: color),
      ),
      Text(text),
    ]);
  }

  void _showTaskList(int taskListId) async {
    var dbRes = await DataStore.database.query(
      'todo_list',
      where: 'id = ?',
      whereArgs: [taskListId],
    );
    var todoList = TodoList.fromMap(dbRes[0]);
    todoList.tasks = await DataStore.findTasksByTodoListId(taskListId);
    Navigator.pushNamed(context, '/todoListDisplay', arguments: todoList);
  }

  @override
  Widget build(BuildContext context) {
    var titleText = Text(
      comp.name,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
    const brighter = 200;
    return Row(children: [
      Expanded(child: titleText),
      if (comp.taskListId != null)
        IconButton(
          icon: Icon(Icons.checklist_outlined, color: Colors.lime[brighter]),
          onPressed: () => _showTaskList(comp.taskListId!),
        ),
      if (comp.tRecord != null)
        IconButton(
          icon: Icon(Icons.book_outlined, color: Colors.blue[brighter]),
          tooltip: "Journal Entry",
          onPressed: () async {
            _showJournalEditor();
          },
        ),
      if (comp.stickyNote.isNotEmpty)
        IconButton(
            icon: Icon(Icons.sticky_note_2_outlined,
                color: Colors.deepOrange[brighter]),
            tooltip: "Sticky Note",
            onPressed: _showStickyNoteEditor),
      PopupMenuButton<void Function()>(
        onSelected: ((optionCallback) => optionCallback()),
        itemBuilder: (context) => <PopupMenuEntry<void Function()>>[
          if (comp.tRecord == null)
            PopupMenuItem(
              child: _buttonWithText(
                  Icons.book_outlined, Colors.blue, "Add Journal Entry"),
              value: () {
                _createJournalEntry();
                _showJournalEditor();
              },
            ),
          if (comp.stickyNote.isEmpty)
            PopupMenuItem(
              child: _buttonWithText(
                  Icons.sticky_note_2, Colors.deepOrange, "Add sticky note"),
              value: () {
                _showStickyNoteEditor();
              },
            ),
          PopupMenuItem(
            child: PopupMenuButton<int?>(
              tooltip: "", // "Link or unlink a TODO list to this component",
              onSelected: (id) => setState(() {
                // if we set value to null
                // then onSelected will not be called
                // so use -1 as a proxy value
                comp.taskListId = id == -1 ? null : id;
                DataStore.database.update(
                  'sched_comp',
                  {'task_list_id': comp.taskListId},
                  where: 'id = ?',
                  whereArgs: [comp.id!],
                );
                Navigator.of(context).pop();
              }),
              child: _buttonWithText(
                  Icons.checklist, Colors.lime, "Link TODO-List"),
              itemBuilder: (context) => [
                for (var i in DataStore.todoLists)
                  CheckedPopupMenuItem(
                    checked: comp.taskListId == i.id,
                    child: Text(i.name),
                    value: i.id,
                  ),
                const PopupMenuDivider(),
                CheckedPopupMenuItem(
                  checked: comp.taskListId == null,
                  child: const Text("None of these"),
                  value: -1,
                ),
              ],
            ),
          ),
          PopupMenuItem(
              child: _buttonWithText(
                  Icons.insights_outlined, Colors.teal, "Statistics"),
              value: () async {
                var stat = await _getStatForComponent();
                showDialog(
                    context: context,
                    builder: (context) => StatsDialog(
                          stat: stat,
                        ));
              })
        ],
      ),
    ]);
  }
}

class StatsDialog extends Dialog {
  const StatsDialog({Key? key, required this.stat}) : super(key: key);

  final ComponentStat stat;

  Widget _paddedText(String text) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Text(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text("Compnent Stats"),
        content: SingleChildScrollView(
            child: Table(
          columnWidths: const {
            1: FlexColumnWidth(),
          },
          border: TableBorder.all(),
          children: <TableRow>[
            TableRow(children: [
              _paddedText("Total Minutes"),
              _paddedText("${stat.totalMinutes}"),
            ]),
            TableRow(children: [
              _paddedText("Times Finished"),
              _paddedText("${stat.finishCount}"),
            ]),
            TableRow(children: [
              _paddedText("Times Skipped"),
              _paddedText("${stat.skipCount}"),
            ]),
          ],
        )),
        actions: [
          TextButton(
              child: const Text("CLEAR", style: TextStyle(color: Colors.red)),
              onPressed: () {
                DataStore.clearStats(stat.componentId);
                Navigator.of(context).pop();
              }),
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ]);
  }
}
