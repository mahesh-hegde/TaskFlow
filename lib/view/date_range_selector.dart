import 'package:flutter/material.dart';

import '../util/time_format.dart';

class DateRangeSelector extends StatefulWidget {
  final Future<void> Function(DateTimeRange?) onChange;
  const DateRangeSelector({Key? key, required this.onChange}) : super(key: key);

  @override
  _DateRangeSelectorState createState() => _DateRangeSelectorState();
}

class _DateRangeSelectorState extends State<DateRangeSelector> {
  DateTimeRange? _range;

  Future<void> _setRange(DateTimeRange? range) async {
    setState(() => _range = range);
    await widget.onChange(range);
  }

  @override
  Widget build(BuildContext context) {
    Widget text;
    if (_range == null) {
      text = const Text("Pick Date Range");
    } else {
      var rangeString =
          "${formatDate(_range!.start)} -\n${formatDate(_range!.end)}";
      text = Row(children: [
        Text(rangeString, softWrap: true),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.red),
          onPressed: () => _setRange(null),
        )
      ]);
    }
    return OutlinedButton(
        child: text,
        onPressed: () async {
          var selectedRange = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2000),
            initialDateRange: _range,
            lastDate: DateTime.now(),
          );
          _setRange(selectedRange);
        });
  }
}
