const weekdays = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

const months = [
  "",
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec"
];

String formatDate(DateTime? date, [String ifNull = "Unknown date"]) {
  if (date == null) return ifNull;
  var year = date.year;
  var month = months[date.month];
  var day = date.day;
  var weekday = weekdays[date.weekday];
  return "$weekday, $day $month $year";
}

String formatTime(DateTime? time, [String ifNull = "Unknown time"]) {
  if (time == null) return ifNull;
  var hour = time.hour % 12;
  if (hour == 0) hour = 12;
  var hourString = hour < 10 ? "0$hour" : "$hour";
  var minute = time.minute;
  var minuteString = minute < 10 ? "0$minute" : "$minute";
  var suffix = time.hour < 12 ? "AM" : "PM";
  return "$hourString:$minuteString $suffix";
}

DateTime getDate(DateTime time) {
  return DateTime(time.year, time.month, time.day);
}

String formatDuration(Duration duration) {
  String plural(int n) => n > 1 ? "s" : "";
  var days = duration.inDays;
  var hours = duration.inHours - days * Duration.hoursPerDay;
  var minutes = duration.inMinutes - duration.inHours * Duration.minutesPerHour;
  var str = <String>[];
  if (days != 0) str.add("$days Day" + plural(days));
  if (hours != 0) str.add("$hours Hour" + plural(hours));
  if (minutes != 0) str.add("$minutes Minute" + plural(minutes));
  return str.join(", ");
}
