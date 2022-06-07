import 'package:flutter/material.dart';

import 'model/types.dart';
import 'model/store.dart';

import 'task_stats.dart';

import 'checklist.dart';
import 'task_editor.dart';
import 'add_delete_listview.dart';
import 'schedule_view.dart';
import 'schedule_editor.dart';
import 'deadlines.dart';

import 'dart:io';
import 'dart:math';
import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory
    databaseFactory = databaseFactoryFfi;
  }

  // Sqflite.devSetDebugModeOn(true);

  await DataStore.openDB();
  await DataStore.database.execute("PRAGMA FOREIGN_KEYS = ON;");
  await DataStore.loadAllTodoLists();
  await DataStore.loadAllSchedules();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'TASKFLOW',
        theme: ThemeData(
          colorScheme: ColorScheme.highContrastDark(
              primary: Colors.teal[200]!, background: Colors.black),
        ),
        initialRoute: "/",
        routes: {
          '/': (context) => const MyHomePage(title: "TaskFlow"),
          '/todolists': (context) => const AllTodoLists(),
          '/todoListDisplay': (context) => const TodoListDisplay(),
		  '/scheduleViewer': (context) => const ScheduleView(),
		  '/scheduleEditor': (context) => const ScheduleEditor(),
        });
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 3,
        child: Scaffold(
            appBar: AppBar(
                title: const Text("TaskFlow"),
                // Here we take the value from the MyHomePage object that was created by
                // the App.build method, and use it to set our appbar title.
                bottom: const TabBar(tabs: [
                  Tab(
                      icon: Icon(
                        Icons.checklist,
                        size: 20.0,
                      ),
                      text: "TODO Lists"),
                  Tab(icon: Icon(Icons.timer, size: 20.0), text: "Schedules"),
                  Tab(icon: Icon(Icons.alarm, size: 20.0), text: "Deadlines"),
                ])),
            body: TabBarView(
              children: [
                const AllTodoLists(),
                const AllSchedules(),
                DeadlinesList(),
              ],
            )));
  }
}

class AllTodoLists extends StatelessWidget {
  const AllTodoLists({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AddDeleteListView<TodoList>(
      leadingIcon: const Icon(Icons.checklist_sharp),
      titleBuilder: (context, todolist) => Text(todolist.name),
      inputHint: "Create new list",
      onAdd: (newList) async => await DataStore.saveTodoList(newList),
      onDelete: (deletedList) async => await DataStore.database
          .delete('todo_list', where: 'id = ?', whereArgs: [deletedList.id]),
	  onTap: (todolist) async {
		  todolist.tasks = await DataStore.findTasksByTodoListId(todolist.id!);
		  Navigator.pushNamed(context, '/todoListDisplay', arguments: todolist);
	  },
	  fromString: (text) => TodoList(name: text, tasks: []),
	  backingList: DataStore.todoLists,
    );
  }
}

class AllSchedules extends StatelessWidget {
	const AllSchedules({Key? key}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return AddDeleteListView<Schedule>(
			leadingIcon: const Icon(Icons.list_alt_rounded),
			titleBuilder: (context, sched) => Text(sched.name),
			inputHint: "Create new schedule",
			onAdd: (newSched) async {
				newSched.id = await DataStore.database.insert('schedule', newSched.toMap());
			},
			onDelete: (deletedSched) async {
				await DataStore.database.delete('schedule', where: 'id = ?', whereArgs: [deletedSched.id!]);
			},
			onPressEdit: (sched) async {
				sched.components = await DataStore.findComponentsByScheduleId(sched.id!);
				Navigator.pushNamed(context, '/scheduleEditor', arguments: sched);
			},
			onTap: (sched) async {
				sched.components = await DataStore.findComponentsByScheduleId(sched.id!);
				Navigator.pushNamed(context, '/scheduleViewer', arguments: sched);
			},
			fromString: (text) => Schedule(name: text),
			backingList: DataStore.schedules,
		);
	}
}

class TodoListDisplay extends StatefulWidget {
  const TodoListDisplay({Key? key}) : super(key: key);

  @override
  _TodoListDisplayState createState() => _TodoListDisplayState();
}

class _TodoListDisplayState extends State<TodoListDisplay> {
  int _done = 0;
  final _formKey = GlobalKey<FormState>();
  int _maxPos = -1;

  final _taskInputCtrl = TextEditingController();

  @override
  Widget build(BuildContext ctx) {
    final todolist = ModalRoute.of(ctx)!.settings.arguments as TodoList;
    final total = todolist.tasks.length;
    if (_maxPos == -1) {
      for (var t in todolist.tasks) {
        _maxPos = max(_maxPos, t.position);
		_done += t.isFinished ? 1 : 0;
      }
    }
    return Scaffold(
        appBar: AppBar(title: Text("${todolist.name} ($_done/$total)"),
			actions: [IconButton(icon: const Icon(Icons.insights),
					onPressed: () => showDialog(
						context: context,
						builder: (context) => TaskStatsDialog(stats: getStats(todolist)),
					),
			)],
		),
        body: ListView(children: [
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Empty task cannot be inserted';
                          }
                          return null;
                        },
                      )),
                      IconButton(
                        icon: Icon(Icons.add, color: Colors.green[400]),
                        tooltip: "Add task",
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          var text = _taskInputCtrl.text;
                          var newTask =
                              TodoTask(name: text, position: ++_maxPos, listId: todolist.id!);
                          DataStore.saveTask(newTask);
                          setState(() {
                            todolist.tasks.add(newTask);
                          });
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
                                task: TodoTask(
                                    name: _taskInputCtrl.text,
									position: ++_maxPos,
                                    listId: todolist.id!));
                            if (newTask == null) return;
                            DataStore.saveTask(newTask);
                            setState(() {
                              todolist.tasks.add(newTask);
                            });
                          })
                    ],
                  ))),
          CheckList(
            tasks: todolist.tasks,
            nestingLevel: 0,
            onChangeNotifier: (i) {
              setState(() {
                _done += (todolist.tasks[i].isFinished ? 1 : -1);
              });
            },
            onDeleteNotifier: (i) => setState(() {
				if (todolist.tasks[i].isFinished) {
					_done--;
				}
			}),
          )
        ]));
  }

  @override
  void dispose() {
    _taskInputCtrl.dispose();
    super.dispose();
  }
}
