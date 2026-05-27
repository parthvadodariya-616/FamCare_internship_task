import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../models/booking_model.dart';
import '../providers/patients_provider.dart';
import '../providers/cart_notifier.dart';
import '../widgets/fc_loading.dart';
import '../widgets/fc_error_banner.dart';
import 'main_shell.dart';

class PatientSelectScreen extends ConsumerWidget {
  const PatientSelectScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Select Patient'),
        automaticallyImplyLeading: false,
      ),
      body: patientsAsync.when(
        loading: () => const FcLoading(message: 'Loading patients…'),
        error: (error, _) => FcErrorBanner(
          message: error.toString(),
          onRetry: () => ref.refresh(patientsProvider),
        ),
        data: (patients) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: patients.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final p = patients[i];
            return _PatientTile(
              patient: p,
              onTap: () {
                ref.read(cartProvider.notifier).setPatient(p.id, p.name);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MainShell()),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  final PatientModel patient;
  final VoidCallback onTap;
  const _PatientTile({required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.blueBg,
                child: Text(
                  patient.initials,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppTheme.blueText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(patient.email,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.secondaryText)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppTheme.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}
