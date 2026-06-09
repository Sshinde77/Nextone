import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';

class FeedbackFormData {
  final int rating;
  final String clientReaction;
  final String interestedIn;
  final String nextStep;
  final String remarks;

  const FeedbackFormData({
    required this.rating,
    required this.clientReaction,
    required this.interestedIn,
    required this.nextStep,
    required this.remarks,
  });

  factory FeedbackFormData.empty() {
    return const FeedbackFormData(
      rating: 0,
      clientReaction: '',
      interestedIn: '',
      nextStep: '',
      remarks: '',
    );
  }

  factory FeedbackFormData.fromMap(Map<String, dynamic> source) {
    return FeedbackFormData(
      rating: _readInt(source['rating']),
      clientReaction: _readString(source['client_reaction']),
      interestedIn: _readString(source['interested_in']),
      nextStep: _readString(source['next_step']),
      remarks: _readString(source['remarks']),
    );
  }

  FeedbackFormData copyWith({
    int? rating,
    String? clientReaction,
    String? interestedIn,
    String? nextStep,
    String? remarks,
  }) {
    return FeedbackFormData(
      rating: rating ?? this.rating,
      clientReaction: clientReaction ?? this.clientReaction,
      interestedIn: interestedIn ?? this.interestedIn,
      nextStep: nextStep ?? this.nextStep,
      remarks: remarks ?? this.remarks,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'rating': rating,
      'client_reaction': clientReaction.trim(),
      'interested_in': interestedIn.trim(),
      'next_step': nextStep.trim(),
      'remarks': remarks.trim(),
    };
  }

  String get apiClientReaction => _toApiValue(clientReaction);

  String get apiNextStep => _toApiValue(nextStep);

  static int _readInt(dynamic value) {
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _readString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '';
    }
    return text;
  }

  static String _toApiValue(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}

Future<FeedbackFormData?> showFeedbackFormDialog({
  required BuildContext context,
  required String title,
  required String submitLabel,
  FeedbackFormData? initialData,
}) {
  return showDialog<FeedbackFormData>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return _FeedbackFormDialog(
        title: title,
        submitLabel: submitLabel,
        initialData: initialData ?? FeedbackFormData.empty(),
      );
    },
  );
}

class _FeedbackFormDialog extends StatefulWidget {
  const _FeedbackFormDialog({
    required this.title,
    required this.submitLabel,
    required this.initialData,
  });

  final String title;
  final String submitLabel;
  final FeedbackFormData initialData;

  @override
  State<_FeedbackFormDialog> createState() => _FeedbackFormDialogState();
}

class _FeedbackFormDialogState extends State<_FeedbackFormDialog> {
  static const List<String> _reactionOptions = <String>[
    'Very Positive',
    'Positive',
    'Neutral',
    'Negative',
    'Not Interested',
  ];

  static const List<String> _nextStepOptions = <String>[
    'Negotiation',
    'Follow Up',
    'Send Proposal',
    'Booked',
    'Lost',
    'Another Revisit',
  ];

  late int _rating;
  late String _clientReaction;
  late String _nextStep;
  late final TextEditingController _interestedController;
  late final TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialData.rating.clamp(0, 5);
    _clientReaction = _normalizeSelection(
      widget.initialData.clientReaction,
      _reactionOptions,
    );
    _nextStep = _normalizeSelection(
      widget.initialData.nextStep,
      _nextStepOptions,
    );
    _interestedController =
        TextEditingController(text: widget.initialData.interestedIn);
    _remarksController =
        TextEditingController(text: widget.initialData.remarks);

    // Fresh feedback should start from valid defaults so the form can be
    // submitted without requiring the user to manually populate every field.
    if (_rating == 0) {
      _rating = 4;
    }
    if (_clientReaction.isEmpty) {
      _clientReaction = 'Positive';
    }
    if (_nextStep.isEmpty) {
      _nextStep = 'Follow Up';
    }
  }

  @override
  void dispose() {
    _interestedController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: maxHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                Expanded(
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 640;
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildStarSection(),
                                      const SizedBox(height: 12),
                                      _buildSelectionSection(
                                        title: 'Client Reaction',
                                        options: _reactionOptions,
                                        selectedValue: _clientReaction,
                                        onChanged: (value) {
                                          setState(() {
                                            _clientReaction = value;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      _buildSelectionSection(
                                        title: 'Next Step',
                                        options: _nextStepOptions,
                                        selectedValue: _nextStep,
                                        onChanged: (value) {
                                          setState(() {
                                            _nextStep = value;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildTextFieldSection(
                                        title: 'Interested In',
                                        controller: _interestedController,
                                        hintText:
                                            'What are they interested in...',
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildTextFieldSection(
                                        title: 'Remarks',
                                        controller: _remarksController,
                                        hintText: 'Additional remarks...',
                                        maxLines: 5,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStarSection(),
                              const SizedBox(height: 12),
                              _buildSelectionSection(
                                title: 'Client Reaction',
                                options: _reactionOptions,
                                selectedValue: _clientReaction,
                                onChanged: (value) {
                                  setState(() {
                                    _clientReaction = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildSelectionSection(
                                title: 'Next Step',
                                options: _nextStepOptions,
                                selectedValue: _nextStep,
                                onChanged: (value) {
                                  setState(() {
                                    _nextStep = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildTextFieldSection(
                                title: 'Interested In',
                                controller: _interestedController,
                                hintText: 'What are they interested in...',
                                maxLines: 1,
                              ),
                              const SizedBox(height: 16),
                              _buildTextFieldSection(
                                title: 'Remarks',
                                controller: _remarksController,
                                hintText: 'Additional remarks...',
                                maxLines: 5,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.star_border_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Complete the fields below before submitting.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rating',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List<Widget>.generate(5, (index) {
            final starValue = index + 1;
            final isSelected = starValue <= _rating;
            return InkResponse(
              onTap: () {
                setState(() {
                  _rating = starValue;
                });
              },
              radius: 22,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.warning.withValues(alpha: 0.12)
                      : const Color(0xFFF6F7FB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.warning.withValues(alpha: 0.35)
                        : AppColors.border,
                  ),
                ),
                child: Icon(
                  isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                  color: AppColors.warning,
                  size: 21,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSelectionSection({
    required String title,
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = option == selectedValue;
            return ChoiceChip(
              label: Text(
                option,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(option),
              selectedColor: AppColors.primary,
              backgroundColor: const Color(0xFFF6F7FB),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextFieldSection({
    required String title,
    required TextEditingController controller,
    required String hintText,
    required int maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          textInputAction:
              maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFF),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 480;
        final cancel = OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        );
        final submit = FilledButton(
          onPressed: _handleSubmit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            widget.submitLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: cancel),
              const SizedBox(width: 12),
              Expanded(child: submit),
            ],
          );
        }

        return Column(
          children: [
            SizedBox(width: double.infinity, child: submit),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: cancel),
          ],
        );
      },
    );
  }

  void _handleSubmit() {
    Navigator.of(context).pop(
      FeedbackFormData(
        rating: _rating,
        clientReaction: _clientReaction,
        interestedIn: _interestedController.text.trim(),
        nextStep: _nextStep,
        remarks: _remarksController.text.trim(),
      ),
    );
  }

  String _normalizeSelection(String value, List<String> options) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final directMatch = options.where(
      (option) => option.toLowerCase() == trimmed.toLowerCase(),
    );
    if (directMatch.isNotEmpty) {
      return directMatch.first;
    }

    final normalized = trimmed.replaceAll('_', ' ').replaceAll('-', ' ');
    for (final option in options) {
      if (option.toLowerCase() == normalized.toLowerCase()) {
        return option;
      }
    }
    return options.contains(trimmed) ? trimmed : '';
  }
}

