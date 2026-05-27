import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_model.dart';
import '../services/api_service.dart';

final servicesProvider = FutureProvider<List<ServiceModel>>((ref) {
  return ref.watch(apiServiceProvider).getServices();
});
