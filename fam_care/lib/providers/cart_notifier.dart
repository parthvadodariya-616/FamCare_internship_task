import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking_model.dart';

// ── Immutable state ───────────────────────────────────────────────────────
class CartState {
  final List<CartItem> items;
  final String? selectedPatientId;
  final String? selectedPatientName;

  const CartState({
    this.items = const [],
    this.selectedPatientId,
    this.selectedPatientName,
  });

  // Computed getters
  int get count => items.length;
  double get totalPrice => items.fold(0.0, (sum, i) => sum + i.price);
  bool get hasItems => items.isNotEmpty;
  bool get hasPatient => selectedPatientId != null;
  bool get readyToCheckout => hasItems && hasPatient;

  CartState copyWith({
    List<CartItem>? items,
    String? selectedPatientId,
    String? selectedPatientName,
    bool clearPatient = false,
  }) {
    return CartState(
      items: items ?? this.items,
      selectedPatientId:
          clearPatient ? null : selectedPatientId ?? this.selectedPatientId,
      selectedPatientName:
          clearPatient ? null : selectedPatientName ?? this.selectedPatientName,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  // ── Patient ─────────────────────────────────────────────────────────────
  void setPatient(String id, String name) {
    state = state.copyWith(
      selectedPatientId: id,
      selectedPatientName: name,
    );
  }

  void clearPatient() {
    state = state.copyWith(clearPatient: true);
  }

  // ── Cart operations ──────────────────────────────────────────────────────
  void addItem(CartItem item) {
    state = state.copyWith(items: [...state.items, item]);
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updated = [...state.items]..removeAt(index);
    state = state.copyWith(items: updated);
  }

  void clearCart() {
    state = state.copyWith(items: []);
  }

  void clearAll() {
    state = const CartState();
  }

  // ── Client-side conflict pre-check ───────────────────────────────────────
  // Guards against obvious overlaps before hitting the API.
  // The server-side SELECT FOR UPDATE is the authoritative check.
  bool wouldConflict(CartItem newItem) {
    for (final existing in state.items) {
      if (existing.bookingDate.year != newItem.bookingDate.year ||
          existing.bookingDate.month != newItem.bookingDate.month ||
          existing.bookingDate.day != newItem.bookingDate.day) {
        continue; // different date — no conflict
      }
      final eStart = _parseTime(existing.startTime);
      final eEnd   = _parseTime(existing.endTime);
      final nStart = _parseTime(newItem.startTime);
      final nEnd   = _parseTime(newItem.endTime);

      final caregiverOverlap = existing.caregiverId == newItem.caregiverId &&
          nStart < eEnd &&
          nEnd > eStart;

      final patientOverlap = nStart < eEnd && nEnd > eStart;

      if (caregiverOverlap || patientOverlap) return true;
    }
    return false;
  }

  static int _parseTime(String t) {
    final parts = t.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────
final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);
