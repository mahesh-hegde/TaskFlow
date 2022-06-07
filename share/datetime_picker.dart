import 'package:flutter/material.dart';

// this is the controller class which is passed as attribute to
// DateTimePicker.
// Clear
class DateTimePickerController {
  DateTimePickerController({DateTime? dateTime}) {
	var dt = dateTime;
	if (dt != null) {
		date = DateTime(dt.year, dt.month, dt.day);
		time = TimeOfDay(hour: dt.hour, minute: dt.minute);
	}
  }

  DateTime? date;
  TimeOfDay? time;
  
  DateTime? get datetime {
	if (date == null) return null;
	var _datetime = date!;
	if (time != null) {
		 _datetime = _datetime.add(
			Duration(hours: time!.hour, minutes: time!.minute)
		);
	}
	return _datetime;
  }
  
  // will be set by widget
  VoidCallback onClear = _doNothing;

  void clear() {
	onClear();
  }

  static void _doNothing() {}
}

class DateTimePicker extends StatefulWidget {
  const DateTimePicker({Key? key, required this.controller}) : super(key: key);

  final DateTimePickerController controller;

  @override
  _DateTimePickerState createState() => _DateTimePickerState();
}

class _DateTimePickerState extends State<DateTimePicker> {
  final _dateTextCtrl = TextEditingController(),
  _timeTextCtrl = TextEditingController();
  @override
  void initState() {
	super.initState();
	widget.controller.onClear = () {
		setState(() {
			var ctrl = widget.controller;
			ctrl.time = null;
			ctrl.date = null;
		});
		_dateTextCtrl.text = "Pick a date";
		_timeTextCtrl.text = "Pick a time";
	};
	var ctrl = widget.controller;
	_dateTextCtrl.text = ctrl.date?.toString() ?? "Pick a date";
	_timeTextCtrl.text = ctrl.time?.toString() ?? "Pick a time";
  }

  @override
  Widget build(BuildContext context) {
	Future<void> dateFieldOnTap() async {
          var date = await showDatePicker(
            initialDate: DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
            context: context,
          );
		  setState(() => widget.controller.date = date);
		  _dateTextCtrl.text = widget.controller.date?.toString() ?? "Pick date";
        }
    var dateField = Row(children: [
      Expanded(
          child: TextFormField(
        enabled: false,
		focusNode: FocusNode(skipTraversal: true),
		onTap: dateFieldOnTap,
        controller: _dateTextCtrl,
        decoration: const InputDecoration(label: Text('Deadline Date')),
      )),
      IconButton(
        icon: const Icon(Icons.calendar_today_outlined),
        onPressed: dateFieldOnTap,
      ),
    ]);

	Future<void> timeFieldOnTap() async {
          var time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );
          setState(
              () => widget.controller.time = time ?? widget.controller.time);
		  _timeTextCtrl.text = widget.controller.time?.toString() ?? "Pick time";
    }

    var timeField = Row(children: [
      Expanded(
          child: TextFormField(
        enabled: false,
		onTap: timeFieldOnTap,
		controller: _timeTextCtrl,
        decoration: const InputDecoration(label: Text('Deadline time')),
      )),
      IconButton(
        icon: const Icon(Icons.access_time),
        onPressed: timeFieldOnTap,
      ),
    ]);

    // Assuming parent is wrapped in a ScrollView, do not return another ListView
    return Column(
      children: [
		dateField,
		timeField,
	  ],
    );
  }
}

