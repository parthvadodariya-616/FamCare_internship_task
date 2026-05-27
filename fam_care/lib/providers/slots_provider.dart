import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/slot_model.dart';
import '../services/api_service.dart';

// ── Params — must implement == and hashCode for family caching ────────────
@immutable
class SlotsParams {
  final String serviceId;
  final DateTime date;

  const SlotsParams({required this.serviceId, required this.date});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlotsParams &&
          runtimeType == other.runtimeType &&
          serviceId == other.serviceId &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day;

  @override
  int get hashCode => Object.hash(serviceId, date.year, date.month, date.day);
}

// ── Provider ──────────────────────────────────────────────────────────────
final slotsProvider =
    FutureProvider.family<SlotAvailabilityResponse, SlotsParams>(
  (ref, params) {
    return ref.watch(apiServiceProvider).getAvailableSlots(
          serviceId: params.serviceId,
          date: params.date,
        );
  },
);
