import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../models/service_model.dart';
import '../providers/services_provider.dart';
import '../widgets/fc_icons.dart';
import '../widgets/fc_badge.dart';
import '../widgets/fc_loading.dart';
import '../widgets/fc_error_banner.dart';
import 'slot_picker_screen.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});
  static const _iconMap = {
    'Physiotherapy':    TIcons.activity,
    'Wound Dressing':   TIcons.bandage,
    'Blood Test':       TIcons.needle,
    'IV Therapy':       TIcons.needle,
    'Post-Surgery Care': TIcons.heartbeat,
    'Elderly Care Visit': TIcons.user,
  };

  static const _colorMap = {
    'Physiotherapy':    (Color(0xFFE6F1FB), Color(0xFF185FA5)),
    'Wound Dressing':   (Color(0xFFEAF3DE), Color(0xFF3B6D11)),
    'Blood Test':       (Color(0xFFFCEBEB), Color(0xFFA32D2D)),
    'IV Therapy':       (Color(0xFFFAEEDA), Color(0xFF854F0B)),
    'Post-Surgery Care': (Color(0xFFEAF3DE), Color(0xFF3B6D11)),
    'Elderly Care Visit': (Color(0xFFF1EFE8), Color(0xFF5F5E5A)),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesProvider);
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        title: const Text('Services'),
        automaticallyImplyLeading: false,
      ),
      body: servicesAsync.when(
        loading: () => const FcLoading(message: 'Loading services…'),
        error: (error, _) => FcErrorBanner(
          message: error.toString(),
          onRetry: () => ref.refresh(servicesProvider),
        ),
        data: (services) => RefreshIndicator(
          onRefresh: () => ref.refresh(servicesProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final s = services[i];
              final icon = _iconMap[s.name] ?? TIcons.stethoscope;
              final colors =
                  _colorMap[s.name] ?? (AppTheme.blueBg, AppTheme.blueText);
              return _ServiceCard(
                service: s,
                icon: icon,
                bgColor: colors.$1,
                fgColor: colors.$2,
                onBook: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SlotPickerScreen(service: s),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceModel service;
  final IconData icon;
  final Color bgColor;
  final Color fgColor;
  final VoidCallback onBook;

  const _ServiceCard({
    required this.service,
    required this.icon,
    required this.bgColor,
    required this.fgColor,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: bgColor, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 24, color: fgColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Color(0xFF111111))),
                    const SizedBox(height: 2),
                    Text(service.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.secondaryText)),
                  ],
                ),
              ),
              FcBadge(label: 'Active', variant: BadgeVariant.green),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 0),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(TIcons.clock, size: 14, color: AppTheme.secondaryText),
              const SizedBox(width: 4),
              Text('${service.durationMinutes} min',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.secondaryText)),
              const SizedBox(width: 16),
              Icon(TIcons.creditCard, size: 14, color: AppTheme.secondaryText),
              const SizedBox(width: 4),
              Text('₹${service.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.secondaryText)),
              const Spacer(),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Book Now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
