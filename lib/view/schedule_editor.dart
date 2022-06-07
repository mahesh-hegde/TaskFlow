import 'package:flutter/material.dart';

import '../model/types.dart';
import '../model/store.dart';

import '../util/validators.dart';

import 'schedule_repeats.dart';
import 'collapsible_card.dart';

typedef AsyncConsumer<T> = Future<void> Function(T arg);

class ScheduleEditor extends StatefulWidget {
  const ScheduleEditor({required this.db, required this.schedule, Key? key})
      : super(key: key);

  final DataStore db;
  final Schedule schedule;

  @override
  _ScheduleEditorState createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<ScheduleEditor> {
  int? _currentlyEditing;
  final _scrollCtrl = ScrollController();

  @override
  Widget build(BuildContext context) {
    var db = widget.db;
    var schedule = widget.schedule;
    var comps = schedule.components;
    var listView =
        ListView(shrinkWrap: true, controller: _scrollCtrl, children: [
      // RepetitionSelector(db: widget.db, schedule: schedule),
      for (int i = 0; i < comps.length; i++)
        Column(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.green),
            tooltip: "Add Component",
            onPressed: () async {
              db.insertNewScheduleComponent(schedule, i);
              setState(() {});
              _scrollCtrl.animateTo(
                i * 240,
                duration: const Duration(seconds: 1),
                curve: Curves.ease,
              );
            },
          ),
          SchedCompEditor(
            key: Key("${comps[i].id}"),
            comp: comps[i],
            isEditable: _currentlyEditing == null || _currentlyEditing == i,
            onDelete: (_) async {
              await db.removeComponentFromSchedule(schedule, i);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Deleted!'), duration: Duration(seconds: 1)),
              );
            },
            onCancel: () async {
              if (comps[i].id == null) {
                setState(() => comps.removeAt(i));
              }
            },
            onMoveUp: i == 0
                ? null
                : (_) async {
                    await db.swapComponentsInSchedule(schedule, i, i - 1);
                    setState(() {});
                  },
            onMoveDown: i == comps.length - 1
                ? null
                : (_) async {
                    await db.swapComponentsInSchedule(schedule, i, i + 1);
                    setState(() {});
                  },
            onSave: (_) async {
              await db.saveComponentToSchedule(schedule, i);
              setState(() => _currentlyEditing = null);
            },
            beforeEditStart: (_) async {
              setState(() => _currentlyEditing = i);
            },
          )
        ]),
      IconButton(
        icon: const Icon(Icons.add_circle, color: Colors.green),
        tooltip: "Add Component",
        onPressed: () {
          comps.add(ScheduleComponent(
              duration: const Duration(minutes: 30),
              name: '',
              position: comps.length,
              schedId: schedule.id!));
          setState(() {});
          _scrollCtrl.animateTo(comps.length * 240,
              duration: const Duration(seconds: 1), curve: Curves.ease);
        },
      )
    ]);
    return Scaffold(
        appBar: AppBar(title: Text('Editing ${schedule.name}')),
        body: listView);
  }
}

class SchedCompEditor extends StatefulWidget {
  const SchedCompEditor(
      {Key? key,
      required this.comp,
      required this.onDelete,
      required this.onCancel,
      required this.onSave,
      required this.onMoveUp,
      required this.onMoveDown,
      required this.beforeEditStart,
      required this.isEditable})
      : super(key: key);
  final ScheduleComponent comp;
  final AsyncConsumer<ScheduleComponent> onDelete, onSave, beforeEditStart;
  final AsyncConsumer<ScheduleComponent>? onMoveUp, onMoveDown;

  final Future<void> Function() onCancel;

  final bool isEditable;

  @override
  _SchedCompEditorState createState() => _SchedCompEditorState();
}

class _SchedCompEditorState extends State<SchedCompEditor> {
  bool _isEditing = false;

  final _nameCtrl = TextEditingController();
  final _infoCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  var _ctype = ComponentType.active;

  final _formKey = GlobalKey<FormState>();

  _resetFormFields() {
    var comp = widget.comp;
    _nameCtrl.text = comp.name;
    _infoCtrl.text = comp.info;
    _durationCtrl.text = comp.duration.inMinutes.toString();
  }

  @override
  void initState() {
    super.initState();
    var comp = widget.comp;
    _isEditing = comp.name.isEmpty;
    _resetFormFields();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _infoCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: _isEditing
            ? BoxDecoration(
                border: Border.all(width: 2.0, color: Colors.greenAccent),
                borderRadius: const BorderRadius.all(Radius.circular(4.0)))
            : null,
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
          child: Form(
            key: _formKey,
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                        child: TextFormField(
                      enabled: _isEditing,
                      controller: _nameCtrl,
                      validator: (input) => checkNotEmpty(input),
                      decoration:
                          const InputDecoration(labelText: "Component Name"),
                    )),
                    if (!_isEditing)
                      IconButton(
                        icon:
                            Icon(Icons.delete_outlined, color: Colors.red[600]),
                        tooltip: "Delete component",
                        onPressed: () async => widget.onDelete(widget.comp),
                      )
                  ]), // end first row

                  Row(children: [
                    Expanded(
                        child: TextFormField(
                      enabled: _isEditing,
                      controller: _infoCtrl,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: "Component Info"),
                    ))
                  ]),

                  Row(children: [
                    Expanded(
                        child: TextFormField(
                      enabled: _isEditing,
                      controller: _durationCtrl,
                      keyboardType: TextInputType.number,
                      validator: (value) => checkNotEmpty(value),
                      decoration: const InputDecoration(
                          labelText: "Duration in minutes"),
                    )),
                    Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: DropdownButton<ComponentType>(
                            value: _isEditing ? _ctype : null,
                            disabledHint: Text(_ctype == ComponentType.active
                                ? "Active"
                                : "Interval"),
                            items: const <DropdownMenuItem<ComponentType>>[
                              DropdownMenuItem(
                                  value: ComponentType.active,
                                  child: Text('Active')),
                              DropdownMenuItem(
                                  value: ComponentType.interval,
                                  child: Text('Interval')),
                            ],
                            onChanged: (ComponentType? s) {
                              if (s != null) {
                                setState(() => _ctype = s);
                              }
                            }))
                  ]),

                  // Buttons: Move Up, Move Down, EditDone
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (_isEditing)
                      IconButton(
                          icon: Icon(Icons.cancel, color: Colors.purple[300]),
                          onPressed: () {
                            setState(() => _isEditing = false);
                            _resetFormFields();
                            widget.onCancel();
                          }),
                    if (widget.onMoveDown != null)
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        tooltip: "Move Down",
                        onPressed: () => widget.onMoveDown!(widget.comp),
                      ),
                    if (widget.onMoveUp != null)
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up),
                        tooltip: "Move Up",
                        onPressed: () => widget.onMoveUp!(widget.comp),
                      ),
                    IconButton(
                        icon: Icon(
                            _isEditing ? Icons.done : Icons.edit_outlined,
                            color: widget.isEditable
                                ? Colors.green[400]
                                : Colors.grey),
                        tooltip: _isEditing ? "Save" : "Edit",
                        onPressed: !widget.isEditable
                            ? null
                            : () async {
                                var comp = widget.comp;
                                if (_isEditing) {
                                  if (!_formKey.currentState!.validate())
                                    return;
                                  comp.duration = Duration(
                                      minutes: int.parse(_durationCtrl.text));
                                  comp.name = _nameCtrl.text;
                                  comp.info = _infoCtrl.text;
                                  widget.onSave(comp);
                                } else {
                                  widget.beforeEditStart(comp);
                                }
                                setState(() => _isEditing = !_isEditing);
                              }),
                  ]),
                ])),
          ),
        ));
  }
}

class RepetitionSelector extends StatefulWidget {
  const RepetitionSelector({Key? key, required this.db, required this.schedule})
      : super(key: key);

  final Schedule schedule;
  final DataStore db;

  @override
  _RepetitionSelectorState createState() => _RepetitionSelectorState();
}

class _RepetitionSelectorState extends State<RepetitionSelector> {
  @override
  Widget build(BuildContext context) {
    var title = const Text("Schedule Repetitions",
        style: TextStyle(fontWeight: FontWeight.bold));
    var content =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var rep in widget.schedule.repeats)
        ScheduleRepeatSelector(
          value: rep,
          onChange: (rep) => widget.db.updateRepetition(rep),
          onDelete: (rep) async {
            setState(() => widget.schedule.repeats.remove(rep));
            widget.db.deleteRepetition(rep);
          },
        ),
      IconButton(
        icon: Icon(Icons.add_alarm, color: Colors.blue[800]),
        onPressed: () async {
          var now = DateTime.now();
          var rep = ScheduleRepetition(
            schedId: widget.schedule.id!,
            mask: 0,
            notifyAt: DateTime(0, 1, 1, now.hour, now.minute),
          );
          await widget.db.saveRepetition(rep);
          setState(() => widget.schedule.repeats.add(rep));
        },
      )
    ]);
    return CollapsibleCard(
      title: title,
      content: content,
    );
  }
}
