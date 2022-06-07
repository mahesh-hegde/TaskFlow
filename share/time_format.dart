String formatDate(DateTime date) {
  var weekdays = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  var months = [
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
  var year = date.year;
  var month = months[date.month];
  var day = date.day;
  var weekday = weekdays[date.weekday];
  return "$weekday, $day $month $year";
}

String formatTime(DateTime time) {
  var hour = time.hour % 12;
  if (hour == 0) hour = 12;
  var minute = time.minute;
  var suffix = time.hour < 12 ? "AM" : "PM";
  return "$hour:$minute $suffix";
}
