import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking_model.dart';
import '../services/api_service.dart';

final patientsProvider = FutureProvider<List<PatientModel>>((ref) {
  return ref.watch(apiServiceProvider).getPatients();
});
