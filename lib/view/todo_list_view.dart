import 'package:flutter/material.dart';

import '../model/types.dart';
import '../model/store.dart';

import 'checklist.dart';
import 'task_editor.dart';
import 'task_stats.dart';

import '../util/validators.dart';

class TodoListView extends StatefulWidget {
  const TodoListView(this.db, this.todoList, {Key? key}) : super(key: key);
  final TodoList todoList;
  final DataStore db;

  @override
  _TodoListViewState createState() => _TodoListViewState();
}

class _TodoListViewState extends State<TodoListView> {
  final _formKey = GlobalKey<FormState>();

  final _taskInputCtrl = TextEditingController();

  @override
  Widget build(BuildContext ctx) {
    final todoList = widget.todoList;
    final total = todoList.tasks.length;
    final done = todoList.tasks.completed;
    final db = widget.db;
    return Scaffold(
        appBar: AppBar(
          title: Text("${todoList.name} ($done/$total)"),
          actions: [
            IconButton(
              icon: const Icon(Icons.insights),
              onPressed: () => showDialog(
                context: context,
                builder: (context) => TaskStatsDialog(todoList: todoList),
              ),
            )
          ],
        ),
        body: SingleChildScrollView(
            child: Column(children: [
          Form(
              key: _formKey,
              child: Padding(
                  padding:
                      const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                          child: TextFormField(
                        controller: _taskInputCtrl,
                        decoration: const InputDecoration(
                          filled: true,
                          hintText: "Add a new task",
                        ),
                        validator: (value) => checkNotEmpty(value,
                            errorMessage: "Task name should not be empty!"),
                      )),
                      IconButton(
                        icon: Icon(Icons.add, color: Colors.green[400]),
                        tooltip: "Add task",
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          var text = _taskInputCtrl.text;
                          var newTask = TodoTask.ofName(text);
                          db.addTaskToTodoList(todoList, newTask);
                          setState(() {});
                          _taskInputCtrl.clear();
                        },
                      ),
                      IconButton(
                          icon: const Icon(Icons.more_horiz_outlined,
                              color: Colors.cyan),
                          tooltip: 'add more details',
                          onPressed: () async {
                            var newTask = await showTaskEditor(
                                context: context,
                                task: TodoTask.ofName(_taskInputCtrl.text));
                            if (newTask == null) return;
                            db.addTaskToTodoList(todoList, newTask);
                            setState(() {});
                          })
                    ],
                  ))),
          CheckList(
              db: db,
              tasks: todoList.tasks,
              nestingLevel: 0,
              // TODO: Synchronize to todo_list table
              onChange: (i) =>
                  setState(() => todoList.tasks.notifyElementChanged(i)),
              onDelete: (i) async {
                await db.deleteTaskFromTodoList(todoList, i);
                setState(() {});
              })
        ])));
  }

  @override
  void dispose() {
    _taskInputCtrl.dispose();
    super.dispose();
  }
}
