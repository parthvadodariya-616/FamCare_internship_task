import 'caregiver_model.dart';

class SlotModel {
  final String startTime;
  final String endTime;
  final List<CaregiverModel> availableCaregivers;

  SlotModel({
    required this.startTime,
    required this.endTime,
    required this.availableCaregivers,
  });

  factory SlotModel.fromJson(Map<String, dynamic> j) => SlotModel(
    startTime: j['start_time'] as String,
    endTime:   j['end_time']   as String,
    availableCaregivers: (j['available_caregivers'] as List)
        .map((c) => CaregiverModel.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

class SlotAvailabilityResponse {
  final String serviceId;
  final String serviceName;
  final int durationMinutes;
  final DateTime date;
  final List<SlotModel> slots;

  SlotAvailabilityResponse({
    required this.serviceId,
    required this.serviceName,
    required this.durationMinutes,
    required this.date,
    required this.slots,
  });

  factory SlotAvailabilityResponse.fromJson(Map<String, dynamic> j) =>
      SlotAvailabilityResponse(
        serviceId:       j['service_id']       as String,
        serviceName:     j['service_name']     as String,
        durationMinutes: j['duration_minutes'] as int,
        date:            DateTime.parse(j['date'] as String),
        slots: (j['slots'] as List)
            .map((s) => SlotModel.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
