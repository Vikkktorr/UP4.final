import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../models/appointment_query.dart';
import '../repositories/appointment_repository.dart';
import 'entity_list_notifier.dart';

class AppointmentListNotifier
    extends EntityListNotifier<Appointment, AppointmentQuery> {
  AppointmentListNotifier(
    AppointmentRepository repository, {
    Listenable? changes,
  }) : super(
         repository,
         (a) => a.id,
         const AppointmentQuery(),
         changes: changes,
       );
}
