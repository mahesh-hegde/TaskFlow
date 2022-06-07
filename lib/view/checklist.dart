import 'package:flutter/material.dart';

import '../model/types.dart';
import '../model/store.dart';

import 'task_editor.dart';
import 'todo_list_view.dart';

import '../util/time_format.dart';

// This class is a possibly recursive listview widget that
// 1. notifies on change of its items
// 2. can take an optional nestingLevel parameter
// 3. handles rearranging of checked items

class CheckList extends StatefulWidget {
  static void _doNothing(int i) {}

  const CheckList(
      {Key? key,
      required this.db,
      required this.tasks,
      this.nestingLevel = 0,
      this.onChange = _doNothing,
      this.onDelete = _doNothing,
      this.isOriginalList = true})
      : super(key: key);

  final DataStore db;
  final TaskList tasks;

  final bool isOriginalList;

  // These functions will be called when list is modified
  // parent widget can handle with appropriate action
  // maybe I need to rename these something other than notifier

  // Note: The parent of a list is always notified with an index
  // Whereas parent of a tile is not
  final Function(int i) onChange, onDelete;

  final int nestingLevel;

  @override
  _CheckListState createState() => _CheckListState();
}

class _CheckListState extends State<CheckList> {
  @override
  Widget build(BuildContext context) {
    var tasks = widget.tasks;
    var total = tasks.length;
    return ReorderableListView.builder(
      shrinkWrap: true, // fix nested listview not displaying
      physics: widget.nestingLevel == 0 ? const ClampingScrollPhysics() : null,
      itemCount: total,
      onReorder: (int o, int n) {
        if (o < n) {
          n -= 1;
        }
        o = total - o - 1;
        n = total - n - 1;
        var oFin = tasks[o].isFinished;
        var nFin = (n == tasks.length && tasks[n - 1].isFinished) ||
            tasks[n].isFinished;
        if (oFin != nFin) return;
        // We want setState to happen instantly
        // if we await for DB operation, UI update may lag
        var task = tasks[o];
        var oldPos = tasks[o].position;
        var newPos = tasks[n].position;
        setState(() {
          final item = tasks.tasks.removeAt(o);
          tasks.tasks.insert(n, item);
          // inefficient, TODO: optimize this
          if (oldPos > newPos) {
            for (var i in tasks.tasks) {
              if (i.position < oldPos && i.position >= newPos) i.position++;
            }
          } else {
            for (var i in tasks.tasks) {
              if (i.position <= newPos && i.position > oldPos) i.position--;
            }
          }
        });
        widget.db.moveTasks(task, oldPos, newPos);
      },
      itemBuilder: (ctx, i) => CheckListTile(
        db: widget.db,
        key: Key('${tasks[total - i - 1].id}'),
        task: tasks[total - i - 1],
        nestingLevel: widget.nestingLevel,
        onChangeNotifier: () {
          var j = total - i - 1;
          widget.onChange(j);
          setState(() => j = widget.tasks.repositionTask(j));
        },
        onDeleteNotifier: () {
          // OnDeleteNotifier should be called first
          // because the index has to point at the same element
          widget.onDelete(total - i - 1);
          setState(() {});
        },
        isOriginalList: widget.isOriginalList,
      ),
    );
  }
}

class CheckListTile extends StatefulWidget {
  const CheckListTile(
      {Key? key,
      required this.db,
      required this.task,
      required this.nestingLevel,
      required this.onChangeNotifier,
      required this.onDeleteNotifier,
      this.isOriginalList = true})
      : super(key: key);

  final TodoTask task;

  final DataStore db;

  final bool isOriginalList;

  final Function() onChangeNotifier, onDeleteNotifier;

  final int nestingLevel;

  @override
  _CheckListTileState createState() => _CheckListTileState();
}

class _CheckListTileState extends State<CheckListTile> {
  // widget state required to display context menu on double tap

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
      await widget.db.toggleCollapsed(task);
      setState(() {});
    }

    final collapseArrow = IconButton(
      icon: Icon(task.collapsed ? Icons.expand_more : Icons.expand_less),
      tooltip: task.collapsed ? "Show subtasks" : "Hide subtasks",
      onPressed: onCollapseToggle,
    );

    void updateCheckedStatus(bool? s) async {
      if (s == null) return;
      widget.db.setFinished(task, s ? DateTime.now() : null);
      setState(() {});
      widget.onChangeNotifier();
    }

    var checkbox = IconButton(
        icon: Checkbox(
            activeColor: Colors.teal[800],
            value: task.isFinished,
            onChanged: updateCheckedStatus),
        onPressed: () => updateCheckedStatus(!task.isFinished));

    // editButton

    void editCallback() async {
      await widget.db.loadNotificationsIntoTask(task);
      var oldSet = task.notifications.map((x) => x.clone()).toSet();
      var editedTask =
          await showTaskEditor(context: context, task: task, isEditing: true);
      if (editedTask == null) return;
      setState(() {});
      await widget.db.updateTask(editedTask);
      await widget.db.updateNotifications(task, oldSet, task.notifications);
    }

    // deleteButton
    void deleteCallback() async {
      // No setState because parent has to handle it
      widget.onDeleteNotifier();
    }

    // addSubtaskButton
    void addSubtaskCallback() async {
      var taskTemplate = TodoTask(name: '');
      var newTask = await showTaskEditor(context: context, task: taskTemplate);
      if (newTask == null) return;
      await widget.db.addSubtask(task, newTask);
      setState(() {});
    }

    // showTodoListCallback
    void showTodoListCallback() async {
      var todoList = widget.db.todoListsById[task.listId]!;
      await widget.db.loadTasksIntoTodoList(todoList);
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => TodoListView(widget.db, todoList)));
    }

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
      itemBuilder: (context) => !widget.isOriginalList
          ? [
              PopupMenuItem(
                child: _buttonWithText(
                    Icons.checklist_outlined, Colors.white, "View in List"),
                value: showTodoListCallback,
              )
            ]
          : [
              if (!task.isFinished) ...[
                if (widget.nestingLevel == 0)
                  PopupMenuItem(
                    child: _buttonWithText(
                        Icons.add_circle_outlined, Colors.green, "Add subtask"),
                    value: addSubtaskCallback,
                  ),
                PopupMenuItem(
                  child: _buttonWithText(
                      Icons.edit_outlined, Colors.blue, "Edit task"),
                  value: editCallback,
                )
              ],
              PopupMenuItem(
                child: _buttonWithText(
                    Icons.delete_outlined, Colors.red, "Delete task"),
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
          value: subtasks.completed / subtasks.length,
          backgroundColor: Colors.red[100],
          color: Colors.green[800],
        )),
        Text('      ${subtasks.completed} / ${subtasks.length}',
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
        visualDensity: const VisualDensity(vertical: -3.0),
        leading: leadingIconButton,
        trailing: popupMenuButton,
        //dense: true,
        horizontalTitleGap: 8.0,
        contentPadding: EdgeInsets.only(left: padding, right: 8.0));

    if (subtasks.isEmpty || task.collapsed) return mainTile;

    var subTasksList = CheckList(
        db: widget.db,
        tasks: subtasks,
        nestingLevel: widget.nestingLevel + 1,
        onChange: (i) async {
          var _oldFinishedValue = task.finished;
          await widget.db.notifyChildChanged(task, i);
          setState(() {});
          // Notify Parent only if its state needs to change
          // Else parent may mistakenly update number of finished tasks
          // In general, all changes in nested list are propagated to tile
          // but tile acts as a checking point that
          // decides whether to upwards propagate the change
          if (_oldFinishedValue != task.finished) {
            widget.onChangeNotifier();
          }
        },
        onDelete: (i) async {
          await widget.db.deleteSubtask(task, i);
          setState(() {});
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
