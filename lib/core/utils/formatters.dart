import 'package:intl/intl.dart';

import '../config/env.dart';

final _money = NumberFormat('#,##0.00');
final _dateTime = DateFormat('yyyy-MM-dd HH:mm');

String money(num v) => '${_money.format(v)} ${Env.currency}';
String plainMoney(num v) => _money.format(v);
String formatDateTime(DateTime d) => _dateTime.format(d);
