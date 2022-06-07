import 'dart:math';

import 'package:flutter/material.dart';

import 'model/types.dart';
import 'model/store.dart';

import 'task_editor.dart';

import 'time_format.dart';

// assuming tasks[j] has changed its finished status
// move it upwards or downwards in list as necessary

// j is actual index in list, i.e total - i - 1
// where i is index in ListView

// returns new index
int _repositionTask(List<TodoTask> tasks, int j) {
  if (tasks[j].isFinished) {
    // TODO: Use builtin list functions where possible
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

// This class is a possibly recursive listview widget that
// 1. notfies on change of its items
// 2. can take an optional nestingLevel parameter
// 3. handles rearranging of checked items

class CheckList extends StatefulWidget {
  static void _doNothing(int i) {}

  const CheckList(
      {Key? key,
      required this.tasks,
      this.nestingLevel = 0,
      this.onChangeNotifier = _doNothing,
      this.onDeleteNotifier = _doNothing})
      : super(key: key);

  final List<TodoTask> tasks;

  // These functions will be called when list is modified
  // parent widget can handle with appropriate action
  // maybe I need to rename these something other than notifier

  // Note: The parent of a list is always notified with an index
  // Whereas parent of a tile is not
  final Function(int i) onChangeNotifier, onDeleteNotifier;

  final int nestingLevel;

  @override
  _CheckListState createState() => _CheckListState();
}

class _CheckListState extends State<CheckList> {
  // TODO: MaxPos, FinishedCount, TotalCount
  late int _maxPos;

  @override
  void initState() {
    super.initState();
    _maxPos = -1;
    for (var t in widget.tasks) {
      _maxPos = max(_maxPos, t.position);
    }
  }

  @override
  Widget build(BuildContext context) {
    var tasks = widget.tasks;
    var total = tasks.length;
    return ListView.builder(
      shrinkWrap: true, // fix nested listview not displaying
      itemCount: total,
      itemBuilder: (ctx, i) => CheckListTile(
          key: Key(tasks[total - i - 1].id.toString()),
          task: tasks[total - i - 1],
          nestingLevel: widget.nestingLevel,
          onChangeNotifier: () {
            var j = total - i - 1;
            widget.onChangeNotifier(j);
            setState(() => j = _repositionTask(tasks, j));
          },
          onDeleteNotifier: () {
            // OnDeleteNotifier should be called first
            // because the index has to point at the same element
            widget.onDeleteNotifier(total - i - 1);
            tasks.removeAt(total - i - 1);
            setState(() {});
          }),
    );
  }
}

class CheckListTile extends StatefulWidget {
  static void _doNothing() {}

  const CheckListTile(
      {Key? key,
      required this.task,
      required this.nestingLevel,
      this.onChangeNotifier = _doNothing,
      this.onDeleteNotifier = _doNothing})
      : super(key: key);

  final TodoTask task;

  final Function() onChangeNotifier, onDeleteNotifier;

  final int nestingLevel;

  @override
  _CheckListTileState createState() => _CheckListTileState();
}

class _CheckListTileState extends State<CheckListTile> {
  // widget state required to display context menu on double tap

  // same pattern as in TodoListDisplay
  // max position in child list
  late int _maxPos;

  int _finishedCount = 0;

  @override
  void initState() {
    super.initState();
    _maxPos = -1;
    var task = widget.task;
    for (var i in widget.task.subtasks) {
      if (i.position > _maxPos) {
        _maxPos = i.position;
      }
    }
    _finishedCount = task.subtasks.where((task) => task.isFinished).length;
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final padding = (widget.nestingLevel * 36) + 8.0;

    final strikeout = TextStyle(
        decoration: TextDecoration.lineThrough,
        color: Colors.grey,
        fontSize: 16.0 - widget.nestingLevel * 2);

    final textStyle = task.isFinished
        ? strikeout
        : TextStyle(fontSize: 16.0 - widget.nestingLevel * 2);

    Future<void> onCollapseToggle() async {
      setState(() {
        task.collapsed = !task.collapsed;
      });
      await DataStore.updateTask(
          task.id!, {'collapsed': (task.collapsed) ? 1 : 0});
    }

    final collapseArrow = IconButton(
      icon: Icon(task.collapsed ? Icons.expand_more : Icons.expand_less),
      padding: const EdgeInsets.all(5.0),
      tooltip: task.collapsed ? "Show subtasks" : "Hide subtasks",
      onPressed: onCollapseToggle,
    );

    void updateCheckedStatus(bool? s) {
      if (s == null) return;
      setState(() {
        task.finished = (s ? DateTime.now() : null);
      });
      DataStore.updateTask(
          task.id!, {'finished': task.finished?.millisecondsSinceEpoch});
      widget.onChangeNotifier();
    }

    var checkbox = Checkbox(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        activeColor: Colors.teal[800],
        value: task.isFinished,
        onChanged: updateCheckedStatus);

    // editButton

    void editCallback() async {
      var editedTask =
          await showTaskEditor(context: context, task: task, isEditing: true);
      if (editedTask == null) return;
      setState(() {});
      DataStore.updateTask(editedTask.id!, editedTask.toMap());
    }

    var editButton = IconButton(
        icon: Icon(Icons.edit_outlined,
            color: task.isFinished ? Colors.grey : Colors.blue[700]),
        tooltip: "Edit task",
        // iconSize: 20.0,
        // splashRadius: Material.defaultSplashRadius * 0.75,
        disabledColor: Colors.grey,
        onPressed: null);

    // deleteButton
    void deleteCallback() async {
      // No setState because parent has to handle it
      DataStore.deleteTask(task.id!);
      widget.onDeleteNotifier();
    }

    var deleteButton = IconButton(
      icon: Icon(Icons.delete_outlined, color: Colors.red[400]),
      tooltip: "Delete task",
      iconSize: 20.0,
      splashRadius: Material.defaultSplashRadius * 0.75,
      onPressed: null,
    );

    // addSubtaskButton
    void addSubtaskCallback() async {
      var taskTemplate =
          TodoTask(name: '', listId: task.listId, position: _maxPos++);
      var newTask = await showTaskEditor(context: context, task: taskTemplate);
      if (newTask == null) return;
      newTask.parentId = task.id!;
      DataStore.saveTask(newTask);
      setState(() => task.subtasks.add(newTask));
    }

    var addSubtaskButton = IconButton(
        icon: Icon(Icons.add_circle_outline,
            color: task.isFinished ? Colors.grey : Colors.green[400]),
        tooltip: "Add subtask",
        iconSize: 20.0,
        splashRadius: Material.defaultSplashRadius * 0.75,
        // whose idea was this?
        onPressed: null);

    Widget _buttonWithText(IconData icon, Color color, String text) {
      return Row(children: [
        Padding(
          padding: const EdgeInsets.only(left: 2.0, right: 8.0),
          child: Icon(icon, color: color),
        ),
        Text(text),
      ]);
    }

    // titleWidget
    Widget titleWidget = Row(children: [
      Expanded(child: Text(task.name, style: textStyle)),
    ]);

    if (task.deadline != null) {
      titleWidget = Tooltip(
        child: titleWidget,
        message: "Due ${formatTime(task.deadline!)}, "
            "${formatDate(task.deadline!)}",
      );
    }

    var popupMenuButton = PopupMenuButton<Function()>(
      onSelected: (callback) {
        callback();
      },
      tooltip: "Options",
      itemBuilder: (context) => [
        PopupMenuItem(
          child: _buttonWithText(
              Icons.add_circle_outlined, Colors.green, "Add subtask"),
          value: addSubtaskCallback,
        ),
        PopupMenuItem(
          child: _buttonWithText(Icons.edit_outlined, Colors.blue, "Edit task"),
          value: editCallback,
        ),
        PopupMenuItem(
          child:
              _buttonWithText(Icons.delete_outlined, Colors.red, "Delete task"),
          value: deleteCallback,
        ),
      ],
    );

    // leadingIconButton
    var leadingIconButton = task.subtasks.isEmpty ? checkbox : collapseArrow;

    final subtasks = task.subtasks;

    Widget? taskProgress;

    if (subtasks.isNotEmpty) {
      taskProgress = Row(children: [
        Expanded(
            child: LinearProgressIndicator(
          value: _finishedCount / subtasks.length,
          backgroundColor: Colors.red[100],
          color: Colors.green[800],
        )),
        Text('      $_finishedCount / ${subtasks.length}',
            style: const TextStyle(fontSize: 10)),
      ]);
    }

    var mainTile = ListTile(
        minLeadingWidth: 20.0,
        title: Column(
            children: [titleWidget, if (subtasks.isNotEmpty) taskProgress!]),
        onTap: task.hasSubtasks
            ? onCollapseToggle
            : () => updateCheckedStatus(!task.isFinished),
        subtitle: Text(task.info, style: textStyle),
        leading: leadingIconButton,
		trailing: popupMenuButton,
        contentPadding: EdgeInsets.only(left: padding, right: 8.0));

    // StackOverflow copypasta with blind null checks thrown everywhere

    if (subtasks.isEmpty || task.collapsed) return mainTile;

    var subTasksList = CheckList(
        tasks: subtasks,
        nestingLevel: widget.nestingLevel + 1,
        onChangeNotifier: (i) {
          var _oldFinishedValue = task.finished;
          _finishedCount += (subtasks[i].isFinished ? 1 : -1);
          if (_finishedCount == subtasks.length) {
            task.finished = subtasks[i].finished;
          } else if (_finishedCount == subtasks.length - 1 &&
              !subtasks[i].isFinished) {
            task.finished = null;
          }
          setState(() {});
          // Notify Parent only if its state needs to change
          // Else parent may mistakenly update number of finished tasks
          // In general, all changes in nested list are propagated to tile
          // but tile acts as a checking point that
          // decides whether to upwards propagate the change
          if (_oldFinishedValue != task.finished) {
            DataStore.updateTask(
                task.id!, {'finished': task.finished?.millisecondsSinceEpoch});
            widget.onChangeNotifier();
          }
        },
        onDeleteNotifier: (i) {
          // inspect task to be deleted
          if (subtasks[i].isFinished) {
            _finishedCount--;
          }

          if (subtasks.length == 1) {
            setState(() {});
            widget.onChangeNotifier();
            return;
          }

          if (subtasks.length - 1 == _finishedCount &&
              !subtasks[i].isFinished) {
            // assign task.finished the maximum value
            task.finished = subtasks
                .map((task) => task.finished)
                .where((t) => t != null)
                .reduce((t1, t2) => t1!.isAfter(t2!) ? t1 : t2);
            DataStore.updateTask(task.id!, {'finished': task.finished});
            setState(() {});
            widget.onChangeNotifier();
          }
        });
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mainTile,
        if (subtasks.isNotEmpty && !task.collapsed) subTasksList,
      ],
    );
  }
}
