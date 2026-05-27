import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/service_model.dart';
import '../providers/cart_notifier.dart';
import '../providers/services_provider.dart';
import '../widgets/fc_icons.dart';
import '../widgets/fc_badge.dart';
import '../widgets/fc_card.dart';
import 'services_screen.dart';
import 'cart_screen.dart';
import 'slot_picker_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final servicesAsync = ref.watch(servicesProvider);
    final services = servicesAsync.asData?.value;
    final patientName = cart.selectedPatientName ?? 'Patient';
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ───────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hello, ${patientName.split(' ').first} 👋',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w700,
                                    color: Color(0xFF111111))),
                            const SizedBox(height: 2),
                            Text(today,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.secondaryText)),
                          ],
                        ),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: AppTheme.pageBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppTheme.border, width: 0.5),
                              ),
                              child: const Icon(TIcons.bell, size: 20,
                                  color: Color(0xFF333333)),
                            ),
                            Positioned(
                              top: -2, right: -2,
                              child: Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.danger,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Cart summary banner ───────────────────────────────
                if (cart.hasItems) ...[
                  _CartBanner(cart: cart, onViewCart: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                  }),
                  const SizedBox(height: 16),
                ],

                // ── Quick Actions ─────────────────────────────────────
                const Text('Quick Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: Color(0xFF111111))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _QuickAction(
                      icon: TIcons.stethoscope,
                      label: 'Book Service',
                      color: AppTheme.primary,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesScreen()));
                      },
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickAction(
                      icon: TIcons.calendar,
                      label: 'My Bookings',
                      color: AppTheme.success,
                      onTap: () {},
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickAction(
                      icon: TIcons.heartbeat,
                      label: 'Health Track',
                      color: AppTheme.danger,
                      onTap: () {},
                    )),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Available Services ────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available Services',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111))),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesScreen()));
                      },
                      child: const Text('See all',
                          style: TextStyle(fontSize: 13,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (servicesAsync.isLoading)
                  ...List.generate(3, (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _ServiceSkeleton(),
                  ))
                else if (services != null)
                  ...services.take(3).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ServiceTile(service: s),
                  )),

                const SizedBox(height: 20),

                // ── Status Summary ────────────────────────────────────
                const Text('Today\'s Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: Color(0xFF111111))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _StatCard(
                      value: '${cart.count}',
                      label: 'In Cart',
                      color: AppTheme.blueBg,
                      textColor: AppTheme.blueText,
                      icon: TIcons.shoppingCart,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(
                      value: '₹${cart.totalPrice.toStringAsFixed(0)}',
                      label: 'Cart Total',
                      color: AppTheme.greenBg,
                      textColor: AppTheme.greenText,
                      icon: TIcons.creditCard,
                    )),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _CartBanner extends StatelessWidget {
  final CartState cart;
  final VoidCallback onViewCart;
  const _CartBanner({required this.cart, required this.onViewCart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withBlue(255)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(TIcons.shoppingCart, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${cart.count} item${cart.count > 1 ? 's' : ''} in cart',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text('₹${cart.totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.85))),
              ],
            ),
          ),
          GestureDetector(
            onTap: onViewCart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('View',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppTheme.primary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final ServiceModel service;
  const _ServiceTile({required this.service});

  static const _icons = {
    'Physiotherapy':   TIcons.activity,
    'Wound Dressing':  TIcons.bandage,
    'Blood Test':      TIcons.needle,
    'IV Therapy':      TIcons.needle,
    'Post-Surgery Care': TIcons.heartbeat,
    'Elderly Care Visit': TIcons.user,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[service.name] ?? TIcons.stethoscope;
    return FcCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SlotPickerScreen(service: service),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.blueBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${service.durationMinutes} min · ₹${service.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.secondaryText)),
              ],
            ),
          ),
          FcBadge(label: 'Available', variant: BadgeVariant.green),
        ],
      ),
    );
  }
}

class _ServiceSkeleton extends StatelessWidget {
  const _ServiceSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: const Center(child: LinearProgressIndicator()),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color textColor;
  final IconData icon;
  const _StatCard({required this.value, required this.label,
      required this.color, required this.textColor, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: textColor),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                      color: textColor)),
              Text(label,
                  style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8))),
            ],
          ),
        ],
      ),
    );
  }
}
