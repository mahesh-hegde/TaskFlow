import 'package:flutter/material.dart';

import '../util/time_format.dart';

class DateTimeChip extends StatefulWidget {
  const DateTimeChip(
      {this.initialValue,
      required this.onChange,
      this.backgroundColor,
      this.promptText = "Pick Date & Time",
      Key? key})
      : super(key: key);
  final DateTime? initialValue;
  final void Function(DateTime?) onChange;
  final String promptText;
  final Color? backgroundColor;
  @override
  _DateTimeChipState createState() => _DateTimeChipState();
}

class _DateTimeChipState extends State<DateTimeChip> {
  DateTime? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    var text = (_value == null)
        ? widget.promptText
        : "${formatTime(_value)} | ${formatDate(_value)}";
    var chip = GestureDetector(
      child: Chip(
        backgroundColor: widget.backgroundColor,
        label: MouseRegion(cursor: SystemMouseCursors.click, child: Text(text)),
        onDeleted: _value == null
            ? null
            : () {
                setState(() => _value = null);
                widget.onChange(null);
              },
      ),
      onTap: () async {
        var now = DateTime.now();
        var date = await showDatePicker(
          context: context,
          initialDate: _value ?? now,
          firstDate: now,
          lastDate: now.add(const Duration(days: 3600)),
          confirmText: "NEXT",
        );
        if (date == null) return;
        var time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: now.hour, minute: 0),
          builder: (context, child) => MediaQuery(
            child: child!,
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          ),
        );
        if (time != null) {
          var dateTime =
              date.add(Duration(hours: time.hour, minutes: time.minute));
          setState(() => _value = dateTime);
          widget.onChange(_value);
        }
      },
    );
    return chip;
  }
}
