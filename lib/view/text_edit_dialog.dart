import 'package:flutter/material.dart';

import '../util/validators.dart';

// This dialog returns text on valid input, initial text on cancel
// an onClear callback can be passed, to provide a clear option, and return null

class TextEditDialog extends Dialog {
  TextEditDialog(
      {Key? key,
      required this.initialText,
      this.textLabel,
      required this.title,
      this.leading,
      this.trailing,
      this.onClear,
      this.lines = 10})
      : super(key: key) {
    // the debug mode assertion initialValue == null || controller == null
    // to prevent that, set the default text in the constructor.
    _inputCtrl.text = initialText;
  }

  final String initialText;
  final String title;
  final String? textLabel;
  final Widget? leading, trailing;
  final int lines;
  // pass this callback only if a clear option is needed
  final Future<void> Function()? onClear;

  final _formKey = GlobalKey<FormState>();
  final _inputCtrl = TextEditingController();

  Widget _form(BuildContext context) {
    return Form(
        key: _formKey,
        child: SingleChildScrollView(
            child: Column(children: [
          if (leading != null) leading!,
          TextFormField(
              controller: _inputCtrl,
              maxLines: lines,
              minLines: lines,
              validator: (v) =>
                  checkNotEmpty(v, errorMessage: "Text must not be empty!"),
              decoration: InputDecoration(
                labelText: textLabel ?? "Content",
                filled: true,
              )),
          if (trailing != null) trailing!,
        ])));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: _form(context),
      actions: <Widget>[
        if (onClear != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context, null);
              onClear!();
            },
            child:
                const Text('CLEAR', style: TextStyle(color: Colors.deepOrange)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, initialText),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _inputCtrl.text);
            }
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
