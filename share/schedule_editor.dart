import 'package:flutter/material.dart';

import 'model/types.dart';
import 'model/store.dart';

typedef AsyncConsumer<T> = Future<void> Function(T arg);

String? nonEmptyTextValidator(String? value) {
  if (value == null || value.isEmpty) {
    return 'Text should not be empty!';
  }
  return null;
}

class ScheduleEditor extends StatefulWidget {
  const ScheduleEditor({Key? key}) : super(key: key);

  @override
  _ScheduleEditorState createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<ScheduleEditor> {
  @override
  Widget build(BuildContext context) {
    var schedule = ModalRoute.of(context)!.settings.arguments as Schedule;
    var comps = schedule.components;
    return Scaffold(
		appBar: AppBar(title: Text('Editing ${schedule.name}')),
        body: ListView(shrinkWrap: true, children: [
          for (int i = 0; i < comps.length; i++)
            Column(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                tooltip: "Add Component",
                onPressed: () async {
                  // renumber later components
                  await DataStore.database.execute(
                      "update sched_comp set position=position+1 where position >= ?",
                      [i]);
                  // insert a new component in place, set its state to editing
                  // move focus onto that
                  setState(() => comps.insert(
                      i,
                      ScheduleComponent(
                          duration: const Duration(minutes: 30),
                          name: '',
                          position: i,
                          schedId: schedule.id!)));
                },
              ),
              SchedCompEditor(
                key: Key(comps[i].id.toString()),
                comp: comps[i],
                afterDelete: (deletedComponent) async {
                  // component already deleted by widget, just detach the card
                  setState(() => comps.removeAt(i));
				  ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Deleted!'), duration: Duration(seconds: 1)),
				  );
                },
				onCancel: () async {
					if (comps[i].id == null) {
						setState(() => comps.removeAt(i));
					}
				},
                afterSave: (_) async {},
                beforeEditStart: (_) async {},
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
            },
          )
        ]));
  }
}

class SchedCompEditor extends StatefulWidget {
  const SchedCompEditor(
      {Key? key,
      required this.comp,
      required this.afterDelete,
	  required this.onCancel,
      required this.afterSave,
      required this.beforeEditStart})
      : super(key: key);
  final ScheduleComponent comp;
  final AsyncConsumer<ScheduleComponent> afterDelete,
      afterSave,
      beforeEditStart;

  final Future<void> Function() onCancel;

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
  Widget build(BuildContext context) {
    return Container(
        decoration: _isEditing
            ? BoxDecoration(border: Border.all(width: 2.0, color: Colors.greenAccent), borderRadius: const BorderRadius.all(Radius.circular(4.0)))
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
                      validator: nonEmptyTextValidator,
                      decoration:
                          const InputDecoration(labelText: "Component Name"),
                    )),
                    if (!_isEditing)
                      IconButton(
                        icon:
                            Icon(Icons.delete_outlined, color: Colors.red[600]),
                        tooltip: "Delete component",
                        onPressed: () async {
                          await DataStore.database.delete('sched_comp',
                              where: 'id = ?', whereArgs: [widget.comp.id!]);
                          widget.afterDelete(widget.comp);
                        },
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
                      validator: nonEmptyTextValidator,
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
					if (_isEditing) IconButton(
							icon: Icon(Icons.cancel, color: Colors.purple[300]),
							onPressed: (){
						setState(() => _isEditing = false);
						_resetFormFields();
						widget.onCancel();
					}),
					IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      tooltip: "Move Down",
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up),
                      tooltip: "Move Up",
                      onPressed: () {},
                    ),
                    IconButton(
                        icon: Icon(
                            _isEditing ? Icons.done : Icons.edit_outlined,
                            color: Colors.green[400]),
                        tooltip: _isEditing ? "Save" : "Edit",
                        onPressed: () async {
                          var comp = widget.comp;
                          if (!_formKey.currentState!.validate()) return;
                          comp.duration =
                              Duration(minutes: int.parse(_durationCtrl.text));
                          comp.name = _nameCtrl.text;
                          comp.info = _infoCtrl.text;
                          if (comp.id == null) {
                            comp.id = await DataStore.database
                                .insert('sched_comp', comp.toMap());
							await DataStore.database.insert(
								'comp_stat',
								ComponentStat(componentId: comp.id!).toMap(),
							);
                          } else {
                            await DataStore.database.update(
                                'sched_comp', comp.toMap(),
                                where: 'id = ?', whereArgs: [comp.id]);
                          }
                          setState(() => _isEditing = !_isEditing);
                        }),
                  ]),
                ])),
          ),
        ));
  }
}
