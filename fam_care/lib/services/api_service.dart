import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../models/service_model.dart';
import '../models/slot_model.dart';
import '../models/booking_model.dart';

// ── Dio provider — single shared instance ────────────────────────────────
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (kDebugMode) {
    // Avoid logging request/response bodies even in debug to reduce accidental leaks
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: false,
        responseBody: false,
        responseHeader: false,
        error: true,
        compact: true,
      ),
    );
  }

  return dio;
});

// ── Custom exception ──────────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

// ── Service class — takes Dio instance, no static methods ─────────────────
class ApiService {
  final Dio _dio;
  ApiService(this._dio);

  // ── Health check ───────────────────────────────────────────────────────
  Future<bool> healthCheck() async {
    try {
      final r = await _dio.get('/health');
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Services ───────────────────────────────────────────────────────────
  Future<List<ServiceModel>> getServices() async {
    try {
      final r = await _dio.get('/services');
      final data = r.data;
      if (data is! List) {
        throw ApiException('Invalid response format for services');
      }
      return data
          .map((j) => ServiceModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  // ── Patients ───────────────────────────────────────────────────────────
  Future<List<PatientModel>> getPatients() async {
    try {
      final r = await _dio.get('/patients');
      final data = r.data;
      if (data is! List) {
        throw ApiException('Invalid response format for patients');
      }
      return data
          .map((j) => PatientModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  // ── Available slots ────────────────────────────────────────────────────
  Future<SlotAvailabilityResponse> getAvailableSlots({
    required String serviceId,
    required DateTime date,
  }) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final r = await _dio.get(
        '/slots/available',
        queryParameters: {'service_id': serviceId, 'date': dateStr},
      );
      final data = r.data;
      if (data is! Map<String, dynamic>) {
        throw ApiException('Invalid response format for slots');
      }
      return SlotAvailabilityResponse.fromJson(data);
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  // ── Checkout ───────────────────────────────────────────────────────────
  Future<CheckoutSuccess> checkout({
    required String patientId,
    required List<CartItem> items,
  }) async {
    // Basic client-side validation before sending
    if (items.isEmpty) throw ApiException('Cart is empty');
    for (final i in items) {
      if (i.serviceId.isEmpty) {
        throw ApiException('Invalid cart item: missing service id');
      }
      if (i.caregiverId.isEmpty) {
        throw ApiException('Invalid cart item: missing caregiver id');
      }
      if (i.bookingDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
        throw ApiException('Invalid cart item: booking date in the past');
      }
    }

    final body = {
      'patient_id': patientId,
      'items': items
          .map((i) => {
                'service_id': i.serviceId,
                'caregiver_id': i.caregiverId,
                'booking_date':
                    '${i.bookingDate.year}-${i.bookingDate.month.toString().padLeft(2, '0')}-${i.bookingDate.day.toString().padLeft(2, '0')}',
                'start_time': i.startTime,
              })
          .toList(),
    };

    try {
      final r = await _dio.post('/cart/checkout', data: body);
      final data = r.data;
      if (data is! Map<String, dynamic>) {
        throw ApiException('Invalid response format for checkout');
      }
      return CheckoutSuccess.fromJson(data);
    } on DioException catch (e) {
      // 409 — conflict detected by server
      if (e.response?.statusCode == 409) {
        try {
          final detail = (e.response!.data as Map<String, dynamic>)['detail']
              as Map<String, dynamic>;
          final failure = CheckoutFailure.fromJson(detail);
          throw ApiException(failure.message, statusCode: 409);
        } catch (_) {
          throw ApiException('Checkout conflict', statusCode: 409);
        }
      }
      throw _handle(e);
    }
  }

  // ── Internal error mapper ───────────────────────────────────────────────
  ApiException _handle(DioException e) {
    if (e.response != null) {
      final status = e.response!.statusCode ?? 0;
      String msg = 'Server error ($status)';
      try {
        final data = e.response!.data;
        if (data is Map) {
          // Common fields that may contain error messages
          msg = (data['message'] ?? data['detail'] ?? data['error'])?.toString() ?? msg;
        } else if (data is String && data.isNotEmpty) {
          msg = data;
        }
      } catch (_) {}
      return ApiException(msg, statusCode: status);
    }
    return ApiException(
      e.message ?? 'Network error — check your connection',
    );
  }
}

// ── ApiService provider ──────────────────────────────────────────────────
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(dioProvider));
});
