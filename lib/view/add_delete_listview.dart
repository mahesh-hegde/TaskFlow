import 'package:flutter/material.dart';

// Abstracts the UI part for schedules list and todo-lists list

typedef BuilderCallback<T> = Widget Function(BuildContext context, T item);
typedef ItemAction<T> = Future<void> Function(T item);
typedef IndexAction<T> = Future<void> Function(int i);
typedef ItemBuilder<T> = T Function(String);

class AddDeleteListView<T> extends StatefulWidget {
  const AddDeleteListView(
      {Key? key,
      required this.leadingIcon,
      required this.titleBuilder,
      required this.inputHint,
      required this.onAdd,
      this.onDelete,
      this.onPressEdit,
      required this.onTap,
      required this.fromString,
      required this.backingList})
      : super(key: key);

  final String inputHint;
  final Icon leadingIcon;
  final BuilderCallback<T> titleBuilder;
  final ItemAction<T> onAdd;
  // this one shouldn't change state
  final IndexAction<T> onTap;
  final IndexAction<T>? onDelete, onPressEdit;
  final ItemBuilder<T> fromString;
  final List<T> backingList;

  @override
  _AddDeleteListViewState createState() => _AddDeleteListViewState<T>();
}

class _AddDeleteListViewState<T> extends State<AddDeleteListView<T>> {
  final _formKey = GlobalKey<FormState>();
  final _inputCtrl = TextEditingController();

  Widget _tile(int i, BuildContext context) {
    var listTile = ListTile(
      leading: widget.leadingIcon,
      title: Row(children: [
        Expanded(child: widget.titleBuilder(context, widget.backingList[i])),
        if (widget.onPressEdit != null)
          IconButton(
            iconSize: 20.0,
            splashRadius: Material.defaultSplashRadius * 0.75,
            icon: Icon(Icons.edit_outlined, color: Colors.blue[400]),
            onPressed: () async => widget.onPressEdit!(i),
          ),
        if (widget.onDelete != null)
          IconButton(
            iconSize: 20.0,
            splashRadius: Material.defaultSplashRadius * 0.75,
            icon: Icon(Icons.delete_outlined, color: Colors.red[400]),
            onPressed: () async {
              widget.onDelete!(i);
              setState(() {});
            },
          ),
      ]),
      onTap: () async => await widget.onTap(i),
    );
    return listTile;
  }

  Widget _adderForm() {
    return Form(
        key: _formKey,
        child: Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
            child: Row(children: [
              Expanded(
                  child: TextFormField(
                controller: _inputCtrl,
                decoration: InputDecoration(
                  filled: true,
                  hintText: widget.inputHint,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'List name should not be empty!';
                  }
                  return null;
                },
              )),
              IconButton(
                icon: const Icon(Icons.playlist_add),
                tooltip: "Add task",
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  var text = _inputCtrl.text;
                  var newItem = widget.fromString(text);
                  await widget.onAdd(newItem); // Until id is assigned by DB
                  setState(() {});
                  _inputCtrl.clear();
                },
              )
            ]) // end row
            ));
  }

  @override
  Widget build(BuildContext context) {
    var len = widget.backingList.length;
    return Center(
        child: ListView(
      children: [
        _adderForm(),
        for (var i = 0; i < len; i++) _tile(len - i - 1, context),
      ],
    ));
  }
}
