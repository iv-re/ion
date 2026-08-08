import 'dart:async';

import 'package:ion_web/src/request.dart';
import 'package:ion_web/src/response.dart';

typedef Handler = FutureOr<Response> Function(Request req);
