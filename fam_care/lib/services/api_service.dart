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
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseBody: true,
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

  // ── Health check ────────────────────────────────────────────────────────
  Future<bool> healthCheck() async {
    try {
      final r = await _dio.get('/health');
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Services ─────────────────────────────────────────────────────────────
  Future<List<ServiceModel>> getServices() async {
    try {
      final r = await _dio.get('/services');
      final list = r.data as List;
      return list
          .map((j) => ServiceModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  // ── Patients ──────────────────────────────────────────────────────────────
  Future<List<PatientModel>> getPatients() async {
    try {
      final r = await _dio.get('/patients');
      final list = r.data as List;
      return list
          .map((j) => PatientModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  // ── Available slots ───────────────────────────────────────────────────────
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
      return SlotAvailabilityResponse.fromJson(
          r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handle(e);
    }
  }

  // ── Checkout ──────────────────────────────────────────────────────────────
  Future<CheckoutSuccess> checkout({
    required String patientId,
    required List<CartItem> items,
  }) async {
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
      return CheckoutSuccess.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 409 — conflict detected by server
      if (e.response?.statusCode == 409) {
        final detail =
            (e.response!.data as Map<String, dynamic>)['detail']
                as Map<String, dynamic>;
        final failure = CheckoutFailure.fromJson(detail);
        throw ApiException(failure.message, statusCode: 409);
      }
      throw _handle(e);
    }
  }

  // ── Internal error mapper ─────────────────────────────────────────────────
  ApiException _handle(DioException e) {
    if (e.response != null) {
      final status = e.response!.statusCode ?? 0;
      String msg = 'Server error ($status)';
      try {
        final data = e.response!.data;
        if (data is Map) msg = data['detail']?.toString() ?? msg;
      } catch (_) {}
      return ApiException(msg, statusCode: status);
    }
    return ApiException(
      e.message ?? 'Network error — check your connection',
    );
  }
}

// ── ApiService provider ───────────────────────────────────────────────────
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(dioProvider));
});
