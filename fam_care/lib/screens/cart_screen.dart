import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/booking_model.dart';
import '../services/api_service.dart';
import '../providers/cart_notifier.dart';
import '../widgets/fc_icons.dart';
import '../widgets/fc_badge.dart';
import 'checkout_result_screen.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});
  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _checking = false;

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    if (!cart.readyToCheckout) return;
    final cartNotifier = ref.read(cartProvider.notifier);
    final api = ref.read(apiServiceProvider);

    setState(() => _checking = true);

    try {
      final result = await api.checkout(
        patientId: cart.selectedPatientId!,
        items: cart.items.toList(),
      );
      if (!mounted) return;
      cartNotifier.clearCart();
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CheckoutResultScreen(success: result),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      _showFailureSheet(e.message);
    } catch (e) {
      if (!mounted) return;
      _showFailureSheet(e.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showFailureSheet(String reason) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: AppTheme.redBg,
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(TIcons.circleX, color: AppTheme.danger, size: 26),
            ),
            const SizedBox(height: 14),
            const Text('Booking Failed',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(reason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.secondaryText)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Review Cart'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        title: Text('Cart${cart.count > 0 ? ' (${cart.count})' : ''}'),
        automaticallyImplyLeading: false,
        actions: [
          if (cart.hasItems)
            TextButton(
              onPressed: () => _showClearDialog(context),
              child: const Text('Clear', style: TextStyle(color: AppTheme.danger)),
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? _buildEmpty(context)
          : _buildCartList(context, cart),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                color: AppTheme.pageBackground,
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(TIcons.shoppingCart, size: 32,
                color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 16),
          const Text('Your cart is empty',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: Color(0xFF333333))),
          const SizedBox(height: 6),
          const Text('Add services to get started',
              style: TextStyle(fontSize: 13, color: AppTheme.secondaryText)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCartList(BuildContext context, CartState cart) {
    final cartNotifier = ref.read(cartProvider.notifier);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Patient chip
              _PatientChip(
                name: cart.selectedPatientName ?? 'Unknown',
              ),
              const SizedBox(height: 16),

              // Items
              ...List.generate(cart.items.length, (i) {
                final item = cart.items[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CartItemCard(
                    item: item,
                    onRemove: () => cartNotifier.removeItem(i),
                  ),
                );
              }),

              const SizedBox(height: 8),

              // Price summary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal',
                            style: TextStyle(fontSize: 13,
                                color: AppTheme.secondaryText)),
                        Text('₹${cart.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Divider(height: 0),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        Text('₹${cart.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800,
                                color: AppTheme.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Checkout bar
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
          ),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _checking ? null : _checkout,
              child: _checking
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(TIcons.creditCard, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Confirm Booking · ₹${cart.totalPrice.toStringAsFixed(0)}'),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Remove all items from your cart?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(context);
            },
            child: const Text('Clear',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

class _PatientChip extends StatelessWidget {
  final String name;
  const _PatientChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.blueBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(TIcons.user, size: 16, color: AppTheme.blueText),
          const SizedBox(width: 8),
          Text('Booking for: ',
              style: const TextStyle(fontSize: 13,
                  color: AppTheme.blueText)),
          Text(name,
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w700, color: AppTheme.blueText)),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;
  const _CartItemCard({required this.item, required this.onRemove});

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
                child: Text(item.serviceName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(TIcons.trash, size: 17,
                    color: AppTheme.danger),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Row(TIcons.calendar,
              DateFormat('EEE, MMM d, y').format(item.bookingDate)),
          const SizedBox(height: 4),
          _Row(TIcons.clock,
              '${item.startTime} – ${item.endTime} (${item.durationMinutes} min)'),
          const SizedBox(height: 4),
          _Row(TIcons.user, item.caregiverName),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FcBadge(label: 'Pending', variant: BadgeVariant.amber),
              Text('₹${item.price.toStringAsFixed(2)}',
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
