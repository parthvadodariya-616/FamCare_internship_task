import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/booking_model.dart';
import '../widgets/fc_icons.dart';
import '../widgets/fc_badge.dart';
import 'main_shell.dart';

class CheckoutResultScreen extends StatelessWidget {
  final CheckoutSuccess success;
  const CheckoutResultScreen({super.key, required this.success});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // ── Success icon ──────────────────────────────────
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.greenBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(TIcons.circleCheck,
                          size: 36, color: AppTheme.success),
                    ),
                    const SizedBox(height: 16),
                    const Text('Booking Confirmed!',
                        style: TextStyle(fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111111))),
                    const SizedBox(height: 6),
                    Text('${success.bookings.length} service${success.bookings.length > 1 ? 's' : ''} successfully booked',
                        style: const TextStyle(
                            fontSize: 14, color: AppTheme.secondaryText)),
                    const SizedBox(height: 28),

                    // ── Booking cards ─────────────────────────────────
                    ...success.bookings.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ConfirmedCard(booking: b),
                    )),
                    const SizedBox(height: 8),

                    // ── Total ─────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.greenBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Paid',
                              style: TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.greenText)),
                          Text('₹${success.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800,
                                  color: AppTheme.greenText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom actions ────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (r) => false,
                  ),
                  child: const Text('Back to Home'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmedCard extends StatelessWidget {
  final BookingConfirmed booking;
  const _ConfirmedCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(booking.serviceName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              FcBadge(label: 'Confirmed', variant: BadgeVariant.green),
            ],
          ),
          const SizedBox(height: 8),
          _Row(TIcons.calendar,
              DateFormat('EEE, MMM d, y').format(booking.bookingDate)),
          const SizedBox(height: 4),
          _Row(TIcons.clock,
              '${booking.startTime} – ${booking.endTime}'),
          const SizedBox(height: 4),
          _Row(TIcons.user, booking.caregiverName),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ID: ${booking.bookingId.substring(0, 8)}…',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.secondaryText)),
              Text('₹${booking.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppTheme.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Row(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.secondaryText),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.secondaryText)),
        ),
      ],
    );
  }
}
