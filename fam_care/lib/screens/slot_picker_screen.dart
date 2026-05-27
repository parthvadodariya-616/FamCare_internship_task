import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/service_model.dart';
import '../models/slot_model.dart';
import '../models/booking_model.dart';
import '../models/caregiver_model.dart';
import '../providers/cart_notifier.dart';
import '../providers/slots_provider.dart';
import '../widgets/fc_icons.dart';
import '../widgets/fc_badge.dart';
import '../widgets/fc_loading.dart';
import '../widgets/fc_error_banner.dart';

class SlotPickerScreen extends ConsumerStatefulWidget {
  final ServiceModel service;
  const SlotPickerScreen({super.key, required this.service});
  @override
  ConsumerState<SlotPickerScreen> createState() => _SlotPickerScreenState();
}

class _SlotPickerScreenState extends ConsumerState<SlotPickerScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  late final List<DateTime> _days;

  // Selected slot index and caregiver
  int? _selectedSlotIndex;
  CaregiverModel? _selectedCaregiver;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _days = List.generate(
      14,
      (i) => DateTime(now.year, now.month, now.day)
          .add(Duration(days: i + 1)),
    );
  }

  void _addToCart(SlotAvailabilityResponse response) {
    if (_selectedSlotIndex == null || _selectedCaregiver == null) return;
    if (_selectedSlotIndex! < 0 || _selectedSlotIndex! >= response.slots.length) {
      return;
    }
    final slot = response.slots[_selectedSlotIndex!];

    final item = CartItem(
      serviceId:      widget.service.id,
      serviceName:    widget.service.name,
      caregiverId:    _selectedCaregiver!.id,
      caregiverName:  _selectedCaregiver!.name,
      bookingDate:    _selectedDate,
      startTime:      slot.startTime,
      endTime:        slot.endTime,
      price:          widget.service.price,
      durationMinutes: widget.service.durationMinutes,
    );

    final cartNotifier = ref.read(cartProvider.notifier);
    if (cartNotifier.wouldConflict(item)) {
      _showConflictSheet();
      return;
    }

    cartNotifier.addItem(item);
    _showAddedSnack();
    Navigator.of(context).pop();
  }

  void _showAddedSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(TIcons.circleCheck, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('${widget.service.name} added to cart'),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showConflictSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: AppTheme.amberBg,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(TIcons.alertCircle,
                  color: AppTheme.amberText, size: 24),
            ),
            const SizedBox(height: 14),
            const Text('Time Conflict',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'This slot overlaps with another item already in your cart. '
              'Please choose a different time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Choose Different Slot'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date strip ─────────────────────────────────────────────────────────
  Widget _buildDateStrip() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = _days[i];
          final selected = d.year == _selectedDate.year &&
              d.month == _selectedDate.month &&
              d.day == _selectedDate.day;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = d;
                _selectedSlotIndex = null;
                _selectedCaregiver = null;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.border,
                  width: selected ? 1.5 : 0.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('d').format(d),
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : const Color(0xFF111111))),
                  const SizedBox(height: 2),
                  Text(DateFormat('EEE').format(d),
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w500,
                          color: selected ? Colors.white.withOpacity(0.85)
                                         : AppTheme.secondaryText)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Slot grid ──────────────────────────────────────────────────────────
  Widget _buildSlotGrid(
    AsyncValue<SlotAvailabilityResponse> slotsAsync,
    VoidCallback onRetry,
  ) {
    if (slotsAsync.isLoading) {
      return const Padding(
      padding: EdgeInsets.all(40),
      child: FcLoading(message: 'Checking availability…'),
    );
    }
    if (slotsAsync.hasError) {
      return FcErrorBanner(
        message: slotsAsync.error.toString(),
        onRetry: onRetry,
      );
    }
    final response = slotsAsync.value;
    if (response == null || response.slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('No available slots on this date.',
              style: TextStyle(color: AppTheme.secondaryText, fontSize: 14)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.4,
        ),
        itemCount: response.slots.length,
        itemBuilder: (_, i) {
          final slot = response.slots[i];
          final selected = _selectedSlotIndex == i;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedSlotIndex = i;
              _selectedCaregiver = slot.availableCaregivers.first;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.border,
                  width: selected ? 1.5 : 0.5,
                ),
              ),
              child: Center(
                child: Text(slot.startTime,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white
                                        : const Color(0xFF333333))),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Caregiver picker ───────────────────────────────────────────────────
  Widget _buildCaregiverPicker(SlotAvailabilityResponse? response) {
    if (response == null || _selectedSlotIndex == null) {
      return const SizedBox.shrink();
    }
    if (_selectedSlotIndex! < 0 || _selectedSlotIndex! >= response.slots.length) {
      return const SizedBox.shrink();
    }
    final slot = response.slots[_selectedSlotIndex!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text('Select Caregiver',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: Color(0xFF111111))),
        ),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: slot.availableCaregivers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final cg = slot.availableCaregivers[i];
              final selected = _selectedCaregiver?.id == cg.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedCaregiver = cg),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 72,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary.withOpacity(0.08)
                                    : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.border,
                      width: selected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: selected
                            ? AppTheme.primary
                            : AppTheme.blueBg,
                        child: Text(cg.initials,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: selected ? Colors.white
                                               : AppTheme.blueText)),
                      ),
                      const SizedBox(height: 4),
                      Text(cg.name.split(' ').first,
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w500,
                              color: selected ? AppTheme.primary
                                             : const Color(0xFF333333))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final params = SlotsParams(
      serviceId: widget.service.id,
      date: _selectedDate,
    );
    final slotsAsync = ref.watch(slotsProvider(params));
    final slots = slotsAsync.asData?.value;
    final canAdd = slots != null &&
        _selectedSlotIndex != null &&
        _selectedCaregiver != null;
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        title: Text(widget.service.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(TIcons.clock, size: 14, color: AppTheme.secondaryText),
                const SizedBox(width: 4),
                Text('${widget.service.durationMinutes} min',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.secondaryText)),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service header card
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  const Icon(TIcons.calendar, size: 14, color: AppTheme.secondaryText),
                  const SizedBox(width: 6),
                  Text(DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: Color(0xFF333333))),
                  const Spacer(),
                  FcBadge(
                    label: '₹${widget.service.price.toStringAsFixed(0)}',
                    variant: BadgeVariant.blue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Date strip
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _buildDateStrip(),
            ),
            const SizedBox(height: 12),

            // Slot grid header
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text('Available Slots',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: Color(0xFF111111))),
            ),
            _buildSlotGrid(
              slotsAsync,
              () => ref.refresh(slotsProvider(params)),
            ),

            // Caregiver picker
            _buildCaregiverPicker(slots),
            const SizedBox(height: 100),
          ],
        ),
      ),

      // Bottom bar
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
        ),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: canAdd ? () => _addToCart(slots) : null,
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: AppTheme.border,
              disabledForegroundColor: AppTheme.secondaryText,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(TIcons.shoppingCart, size: 18),
                SizedBox(width: 8),
                Text('Add to Cart'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
