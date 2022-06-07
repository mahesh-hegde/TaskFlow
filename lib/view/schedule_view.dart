import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import 'dart:io';

import '../model/types.dart';
import '../model/store.dart';
import '../model/timer.dart';

import 'text_edit_dialog.dart';
import 'todo_list_view.dart';

class ScheduleView extends StatefulWidget {
  const ScheduleView({required this.schedule, required this.db, Key? key})
      : super(key: key);
  final Schedule schedule;
  final DataStore db;

  @override
  _ScheduleViewState createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  late ScheduleTimer timer;

  @override
  void initState() {
    super.initState();
    timer = ScheduleTimer(
        schedule: widget.schedule,
        // tickDuration: const Duration(seconds: 1),
        afterTogglePause: (_) async {
          if (mounted) setState(() {});
        },
        nextComponentPrompt: (_) async {
          setState(() {});
          var message = 'Time over for ${timer.component.name}; ';
          if (timer.index == timer.schedule.components.length - 1) {
            message += "All components completed!";
          } else {
            var upNext = timer.schedule.components[timer.index + 1];
            message += "Up next: ${upNext.name}";
          }
          if (Platform.isAndroid || Platform.isIOS) {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    id: 10,
                    channelKey: 'schedule_notifications',
                    displayOnForeground: true,
                    body: message,
                    // notificationLayout: NotificationLayout.BigText,
                    title: 'Time over'));
          }
        },
        afterEachTick: (_) async {
          if (mounted) setState(() {});
        },
        afterEachMinute: (_) async {
          widget.db.incrementStatMinutes(timer.component);
          // if (mounted) setState(() {});
        },
        onIncrement: (_) async {
          if (mounted) setState(() {});
        },
        onCompleted: (_) async {
          if (mounted) setState(() {});
        });
  }

  @override
  Widget build(BuildContext context) {
    var _schedule = widget.schedule;
    var db = widget.db;
    var comps = _schedule.components;

    var noComponentsMessage = Center(
        child: Column(children: const [
      Text("No components found."
          "Add a few components through Edit button in Previous screen.")
    ]));

    if (_schedule.components.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_schedule.name),
        ),
        body: noComponentsMessage,
      );
    }

    Icon fabIcon;
    String messageText, fabTooltip;
    MaterialColor messageColor, fabBackgroundColor;

    switch (timer.state) {
      case ScheduleTimerState.notStarted:
        fabTooltip = "Start";
        fabIcon = const Icon(Icons.play_arrow_outlined);
        fabBackgroundColor = Colors.lime;
        messageText = "Schedule not running.";
        messageColor = Colors.purple;
        break;
      case ScheduleTimerState.running:
        fabTooltip = "Pause";
        fabIcon = const Icon(Icons.pause_outlined);
        fabBackgroundColor = Colors.teal;
        messageText = "Schedule running.";
        if (timer.minutes != 0) {
          messageText += " (${timer.pastMinutes + timer.minutes} minutes)";
        }
        messageColor = Colors.blue;
        break;
      case ScheduleTimerState.paused:
        fabTooltip = "Resume";
        fabIcon = const Icon(Icons.play_arrow_outlined);
        fabBackgroundColor = Colors.teal;
        messageText = "Schedule paused.";
        messageColor = Colors.grey;
        break;
      case ScheduleTimerState.componentTimeOver:
        fabTooltip = "Please continue or snooze from current component";
        fabIcon = const Icon(Icons.pending_outlined);
        fabBackgroundColor = Colors.lime;
        messageText = "Waiting for confirmation";
        messageColor = Colors.grey;
        break;
      case ScheduleTimerState.completed:
        fabTooltip = "Schedule completed!";
        fabIcon = const Icon(Icons.done_all_outlined);
        fabBackgroundColor = Colors.grey;
        messageText =
            "Schedule completed. (${timer.pastMinutes + timer.minutes} minutes)";
        messageColor = Colors.green;
        break;
    }

    var message = Row(children: [
      Expanded(
          child: Card(
              child: Padding(
                  padding: const EdgeInsets.all(4.0), child: Text(messageText)),
              color: messageColor[800]))
    ]);

    var fab = FloatingActionButton(
      child: fabIcon,
      backgroundColor: fabBackgroundColor,
      tooltip: fabTooltip,
      onPressed: (timer.isCompleted || timer.isComponentTimeOver)
          ? null // disable the button
          : timer.togglePause,
    );

    var stepper = Stepper(
      physics: const NeverScrollableScrollPhysics(),
      currentStep: timer.currentStep,
      controlsBuilder: (context, _) {
        return const Divider();
      },
      steps: [
        for (var comp in comps)
          // title: name, content: description, progress, buttons
          Step(
              state: (timer.index > comp.position || timer.isCompleted)
                  ? StepState.complete
                  : StepState.indexed,
              title: ComponentTitle(db: db, comp: comp),
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
                          child:
                              LinearProgressIndicator(value: timer.progress)),
                      Text(
                          '       ${timer.minutes} / ${timer.componentMinutes} minutes',
                          style: const TextStyle(color: Colors.grey)),
                    ]),
                    if (timer.isComponentTimeOver)
                      const Text("Time Over!!",
                          style: TextStyle(color: Colors.red)),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                              icon: timer.isCompleted
                                  ? const Icon(Icons.done_all,
                                      color: Colors.grey)
                                  : Icon(
                                      timer.isComponentTimeOver
                                          ? Icons.done_all
                                          : Icons.done,
                                      color: Colors.green[500]),
                              tooltip:
                                  timer.isCompleted ? "Finish" : "Early Finish",
                              onPressed: timer.isCompleted
                                  ? null
                                  : () async {
                                      await db.incrementStatFinished(
                                          timer.component);
                                      timer.next();
                                    }),
                          Tooltip(
                            message: "Add 5 Minutes",
                            child: TextButton(
                                child: const Text("+5"),
                                onPressed: () {
                                  comp.duration += const Duration(minutes: 5);
                                  if (!timer.isRunning) {
                                    timer.resume();
                                    // no need to setState explicitly here
                                  } else {
                                    setState(() {});
                                  }
                                }),
                          ),
                          IconButton(
                              icon: Icon(Icons.next_plan_outlined,
                                  color: timer.isCompleted
                                      ? Colors.grey
                                      : Colors.purple),
                              tooltip: "Skip",
                              onPressed: timer.isCompleted
                                  ? null
                                  : () async {
                                      await db.incrementStatSkipped(
                                          timer.component);
                                      timer.next();
                                    }),
                        ])
                  ])),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_schedule.name),
      ),
      body: ListView(children: [
        message,
        SingleChildScrollView(child: stepper),
      ]),
      floatingActionButton: fab,
    );
  }
}

class ComponentTitle extends StatefulWidget {
  ComponentTitle({required this.db, required this.comp, Key? key})
      : super(key: key);

  DataStore db;
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

  void _showJournalEditor() async {
    var record = comp.record!;
    var entryText = await showDialog<String>(
      context: context,
      builder: (context) => TextEditDialog(
          initialText: record.entry,
          title: "Journal Entry for ${comp.name}",
          textLabel: "Journal Entry",
          onClear: () async {
            comp.record = null;
            await widget.db.deleteJournalRecord(record);
          }),
    );
    // only case where entryText.isEmpty is
    // when cancel is pressed on creating new record
    if (entryText == null || entryText.isEmpty) return;
    record.entry = entryText;
    await widget.db.updateJournalRecord(record);
    setState(() {});
  }

  void _createJournalEntry() async {
    var record = JournalRecord(entry: '', componentId: comp.id!);
    comp.record = record;
    await widget.db.saveJournalRecord(record);
  }

  void _showStickyNoteEditor() async {
    comp.stickyNote = await showDialog<String>(
          context: context,
          builder: (context) => TextEditDialog(
            initialText: comp.stickyNote,
            textLabel: "Sticky Note",
            title: "Sticky Note for ${comp.name}",
            onClear: () async {},
          ),
        ) ??
        "";
    await widget.db.updateComponent(comp, {'sticky_note': comp.stickyNote});
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
    var todoList = widget.db.todoListsById[taskListId]!;
    // TODO: Handle error that a task list was deleted;
    widget.db.loadTasksIntoTodoList(todoList);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => TodoListView(widget.db, todoList)));
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
      if (comp.record != null)
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
          if (comp.record == null) // For DBD demo, better hide this option
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
                widget.db.updateComponent(
                  comp,
                  {'task_list_id': comp.taskListId},
                );
                Navigator.of(context).pop();
              }),
              child: _buttonWithText(
                  Icons.checklist, Colors.lime, "Link TODO-List"),
              itemBuilder: (context) => [
                for (var i in widget.db.todoLists)
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
                var stat = await widget.db.findComponentStat(comp);
                showDialog(
                    context: context,
                    builder: (context) => StatsDialog(
                          db: widget.db,
                          stat: stat,
                        ));
              })
        ],
      ),
    ]);
  }
}

class StatsDialog extends Dialog {
  const StatsDialog({required this.db, required this.stat, Key? key})
      : super(key: key);

  final DataStore db;
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
        title: const Text("Component Stats"),
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
                db.clearStats(stat.componentId);
                Navigator.of(context).pop();
              }),
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ]);
  }
}
