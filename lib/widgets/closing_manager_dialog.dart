import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';

Future<bool?> showClosingManagerDialog({
  required BuildContext context,
  required String leadName,
  required Future<void> Function(String closingManager) onSubmit,
  String initialValue = '',
  String title = 'Edit Closing Manager',
  String submitLabel = 'Update Closing Manager',
}) {
  final controller = TextEditingController(text: initialValue);
  bool isSubmitting = false;
  String? errorText;

  return showDialog<bool>(
    context: context,
    barrierDismissible: !isSubmitting,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final trimmedValue = controller.text.trim();

          Future<void> submit() async {
            final value = controller.text.trim();
            if (value.isEmpty) {
              setState(() {
                errorText = 'Closing manager name is required.';
              });
              return;
            }

            setState(() {
              isSubmitting = true;
              errorText = null;
            });

            try {
              await onSubmit(value);
              if (!dialogContext.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop(true);
            } catch (_) {
              if (!dialogContext.mounted) {
                return;
              }
              setState(() {
                isSubmitting = false;
              });
              rethrow;
            }
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(dialogContext).pop(false),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFD2E3FF)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD7E7FF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.manage_accounts_outlined,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      text: 'Closing Manager for ',
                                      style: const TextStyle(
                                        color: Color(0xFF1F2937),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: leadName,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'This person will handle the final negotiation and closing for this lead.',
                                    style: TextStyle(
                                      color: Color(0xFF667085),
                                      fontSize: 13,
                                      height: 1.45,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CLOSING MANAGER NAME *',
                            style: TextStyle(
                              color: Color(0xFF98A2B3),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: controller,
                            enabled: !isSubmitting,
                            autofocus: true,
                            onChanged: (_) {
                              if (errorText != null) {
                                setState(() {
                                  errorText = null;
                                });
                              } else {
                                setState(() {});
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Enter closing manager name',
                              errorText: errorText,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.4,
                                ),
                              ),
                            ),
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () =>
                                      Navigator.of(dialogContext).pop(false),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(58),
                                side:
                                    const BorderSide(color: Color(0xFFD9DEE7)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Color(0xFF344054),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton(
                              onPressed: isSubmitting || trimmedValue.isEmpty
                                  ? null
                                  : submit,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(58),
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      submitLabel,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(controller.dispose);
}
