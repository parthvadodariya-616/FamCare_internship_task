// ── Cart item (local state, not yet confirmed) ────────────────────────────
class CartItem {
  final String serviceId;
  final String serviceName;
  final String caregiverId;
  final String caregiverName;
  final DateTime bookingDate;
  final String startTime;
  final String endTime;
  final double price;
  final int durationMinutes;

  CartItem({
    required this.serviceId,
    required this.serviceName,
    required this.caregiverId,
    required this.caregiverName,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.durationMinutes,
  });
}

// ── Confirmed booking returned from API ──────────────────────────────────
class BookingConfirmed {
  final String bookingId;
  final String serviceName;
  final String caregiverName;
  final DateTime bookingDate;
  final String startTime;
  final String endTime;
  final double price;

  BookingConfirmed({
    required this.bookingId,
    required this.serviceName,
    required this.caregiverName,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.price,
  });

  factory BookingConfirmed.fromJson(Map<String, dynamic> j) => BookingConfirmed(
    bookingId:    j['booking_id']?.toString() ?? '',
    serviceName:  j['service_name']?.toString() ?? '',
    caregiverName:j['caregiver_name']?.toString() ?? '',
    bookingDate:  DateTime.tryParse(j['booking_date']?.toString() ?? '') ?? DateTime.now(),
    startTime:    j['start_time']?.toString() ?? '',
    endTime:      j['end_time']?.toString() ?? '',
    price:        double.tryParse(j['price']?.toString() ?? '') ?? 0.0,
  );
}

// ── Checkout result variants ──────────────────────────────────────────────
class CheckoutSuccess {
  final List<BookingConfirmed> bookings;
  final double totalPrice;
  final String message;

  CheckoutSuccess({
    required this.bookings,
    required this.totalPrice,
    required this.message,
  });

  factory CheckoutSuccess.fromJson(Map<String, dynamic> j) => CheckoutSuccess(
    bookings:   ((j['bookings'] is List) ? (j['bookings'] as List) : [])
        .map((b) => BookingConfirmed.fromJson(b as Map<String, dynamic>))
        .toList(),
    totalPrice: double.tryParse(j['total_price']?.toString() ?? '') ?? 0.0,
    message:    j['message']?.toString() ?? 'All bookings confirmed',
  );
}

class FailedItem {
  final String serviceId;
  final String caregiverId;
  final String bookingDate;
  final String startTime;
  final String reason;

  FailedItem({
    required this.serviceId,
    required this.caregiverId,
    required this.bookingDate,
    required this.startTime,
    required this.reason,
  });

  factory FailedItem.fromJson(Map<String, dynamic> j) => FailedItem(
    serviceId:   j['service_id']?.toString() ?? '',
    caregiverId: j['caregiver_id']?.toString() ?? '',
    bookingDate: j['booking_date']?.toString() ?? '',
    startTime:   j['start_time']?.toString() ?? '',
    reason:      j['reason']?.toString() ?? '',
  );
}

class CheckoutFailure {
  final String message;
  final FailedItem failedItem;

  CheckoutFailure({required this.message, required this.failedItem});

  factory CheckoutFailure.fromJson(Map<String, dynamic> j) => CheckoutFailure(
    message:    j['message']?.toString() ?? 'Checkout failed',
    failedItem: FailedItem.fromJson(j['failed_item'] as Map<String, dynamic>? ?? {}),
  );
}

// ── Patient ───────────────────────────────────────────────────────────────
class PatientModel {
  final String id;
  final String name;
  final String email;
  final String phone;

  PatientModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory PatientModel.fromJson(Map<String, dynamic> j) => PatientModel(
    id:    j['id']?.toString() ?? '',
    name:  j['name']?.toString() ?? '',
    email: j['email']?.toString() ?? '',
    phone: j['phone']?.toString() ?? '',
  );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }
}
