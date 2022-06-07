import 'package:flutter/material.dart';

import '../model/types.dart';

import '../util/time_format.dart';

class ScheduleRepeatSelector extends StatefulWidget {
  const ScheduleRepeatSelector(
      {Key? key,
      required this.value,
      required this.onChange,
      required this.onDelete})
      : super(key: key);

  final ScheduleRepetition value;
  final Future<void> Function(ScheduleRepetition) onChange, onDelete;

  @override
  _ScheduleRepeatSelectorState createState() => _ScheduleRepeatSelectorState();
}

class _ScheduleRepeatSelectorState extends State<ScheduleRepeatSelector> {
  static const weekdays = "SMTWTFS";

  @override
  Widget build(BuildContext context) {
    var weekDaysRow = Row(children: [
      for (var i = 0; i < weekdays.length; i++)
        Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (widget.value.mask & (1 << i)) != 0
                  ? Colors.blue
                  : Colors.transparent,
            ),
            child: IconButton(
                splashRadius: 20.0,
                icon: Text(weekdays[i]),
                onPressed: () {
                  setState(
                      () => widget.value.mask = widget.value.mask ^ (1 << i));
                  widget.onChange(widget.value);
                })),
    ]);
    var notifyAt = widget.value.notifyAt;
    var timeChip = GestureDetector(
        onTap: () async {
          var time = await showTimePicker(
            context: context,
            initialTime:
                TimeOfDay(hour: notifyAt.hour, minute: notifyAt.minute),
            builder: (context, child) => MediaQuery(
              child: child!,
              data:
                  MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            ),
          );
          if (time == null) return;
          setState(() => widget.value.notifyAt =
              DateTime(0, 1, 1, time.hour, time.minute));
          widget.onChange(widget.value);
        },
        child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Chip(
              backgroundColor: Colors.green[800],
              label: MouseRegion(
                  child: Text(formatTime(widget.value.notifyAt)),
                  cursor: SystemMouseCursors.click),
            )));
    var deleteButton = IconButton(
      icon: const Icon(Icons.cancel, color: Colors.red),
      onPressed: () => widget.onDelete(widget.value),
    );

    return Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: weekDaysRow),
          Row(
              children: [timeChip, deleteButton],
              mainAxisAlignment: MainAxisAlignment.spaceBetween),
          const Divider(),
        ]));
  }
}
