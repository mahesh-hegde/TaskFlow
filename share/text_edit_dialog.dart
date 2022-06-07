import 'package:flutter/material.dart';

import 'model/types.dart';

class TextEditDialog extends Dialog {
  TextEditDialog(
      {Key? key,
      required this.initialText,
      this.textLabel,
      required this.title,
      this.leading,
      this.trailing,
      this.lines = 10})
      : super(key: key) {
    // the debug mode assertion initialValue == null || controller == null
    // to prevent that, set the default text in the constructor.
    _inputCtrl.text = initialText;
  }

  final String initialText;
  final String title;
  final String? textLabel;
  Widget? leading, trailing;
  int lines;

  final _formKey = GlobalKey<FormState>();
  final _inputCtrl = TextEditingController();

  Widget _form(BuildContext context) {
    return Form(
        key: _formKey,
        child: ListView(children: [
          if (leading != null) leading!,
          TextFormField(
              controller: _inputCtrl,
              maxLines: lines,
              minLines: lines,
              decoration: InputDecoration(
                labelText: textLabel ?? "Content",
				filled: true,
              )),
          if (trailing != null) trailing!,
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: _form(context),
      actions: <Widget>[
		TextButton(
			onPressed: () => Navigator.pop(context, ""),
			child: const Text('Clear', style: TextStyle(color: Colors.deepOrange)),
		),
        TextButton(
          onPressed: () => Navigator.pop(context, initialText),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, _inputCtrl.text);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
