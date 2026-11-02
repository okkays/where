import 'package:intl/intl.dart';

final longAgoFormatter = DateFormat('yyyy-MM-dd jm');

extension DateTimeExtension on DateTime {
  String timeAgo() {
    final date2 = DateTime.now();
    final difference = date2.difference(this);

    if ((difference.inDays / 7).floor() >= 1) {
      return longAgoFormatter.format(this);
    } else if (difference.inDays >= 2) {
      return '${difference.inDays}days';
    } else if (difference.inDays >= 1) {
      return 'Yesterday';
    } else if (difference.inHours >= 2) {
      return '${difference.inHours}hrs';
    } else if (difference.inHours >= 1) {
      return '1hr';
    } else if (difference.inMinutes >= 2) {
      return '${difference.inMinutes} mins';
    } else if (difference.inMinutes >= 1) {
      return '1min';
    } else if (difference.inSeconds >= 3) {
      return '${difference.inSeconds} secs';
    } else {
      return 'Now';
    }
  }
}
