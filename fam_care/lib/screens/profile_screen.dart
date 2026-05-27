import 'package:fam_care/screens/patient_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/cart_notifier.dart';
import '../widgets/fc_icons.dart';
import '../widgets/fc_badge.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedName =
        ref.watch(cartProvider.select((c) => c.selectedPatientName));
    final name = selectedName ?? 'Patient';
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Avatar card ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primary,
                  child: Text(initials,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111))),
                    const SizedBox(height: 4),
                    const FcBadge(label: 'Patient', variant: BadgeVariant.blue),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Menu sections ────────────────────────────────────────────
          const _Section(title: 'Account', items: [
            _MenuItem(icon: TIcons.user, label: 'Personal Info'),
            _MenuItem(icon: TIcons.bell, label: 'Notifications'),
            _MenuItem(icon: TIcons.mapPin, label: 'Address'),
          ]),
          const SizedBox(height: 16),
          const _Section(title: 'Bookings', items: [
            _MenuItem(
                icon: TIcons.clipboardList, label: 'Booking History'),
            _MenuItem(
                icon: TIcons.calendar, label: 'Upcoming Bookings'),
            _MenuItem(
                icon: TIcons.creditCard, label: 'Payment Methods'),
          ]),
          const SizedBox(height: 16),

          // ── Logout ───────────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              ref.read(cartProvider.notifier).clearAll();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => const PatientSelectScreen()),
                (r) => false,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.redBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.danger.withValues(alpha: 0.2), width: 0.5),
              ),
              child: const Row(
                children: [
                  Icon(TIcons.logout, size: 18, color: AppTheme.danger),
                  SizedBox(width: 12),
                  Text('Log Out',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.danger)),
                  Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: AppTheme.danger),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryText)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Column(
            children: List.generate(
              items.length,
              (i) => Column(
                children: [
                  items[i],
                  if (i < items.length - 1)
                    const Divider(height: 0, indent: 46),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: const Color(0xFF444444)),
      title: Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 12, color: AppTheme.secondaryText),
      onTap: () {},
    );
  }
}
