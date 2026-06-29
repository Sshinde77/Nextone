import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/widgets/searchable_dropdown_field.dart';

class AssignManagerOption {
  const AssignManagerOption({
    required this.id,
    required this.name,
    this.roleLabel = '',
    this.email = '',
  });

  final String id;
  final String name;
  final String roleLabel;
  final String email;
}

class AssignManagerDialog extends StatefulWidget {
  const AssignManagerDialog({
    super.key,
    required this.memberName,
    required this.memberRole,
    required this.memberEmail,
    required this.currentManagerName,
    required this.managers,
    required this.initialManagerId,
    this.title = 'Assign Manager',
    this.actionLabel = 'Assign Manager',
  });

  final String memberName;
  final String memberRole;
  final String memberEmail;
  final String currentManagerName;
  final List<AssignManagerOption> managers;
  final String initialManagerId;
  final String title;
  final String actionLabel;

  @override
  State<AssignManagerDialog> createState() => _AssignManagerDialogState();
}

class _AssignManagerDialogState extends State<AssignManagerDialog> {
  late String _selectedManagerId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialManagerId.trim();
    final hasInitial = widget.managers.any((manager) => manager.id == initial);
    _selectedManagerId = widget.managers.isEmpty
        ? ''
        : hasInitial
            ? initial
            : widget.managers.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final maxDialogHeight = media.height * 0.9;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 512, maxHeight: maxDialogHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textSecondary,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 420;
                    final buttonHeight = isCompact ? 40.0 : 38.0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MemberSummary(
                          name: widget.memberName,
                          role: widget.memberRole,
                          email: widget.memberEmail,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.group_add_outlined,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: 'Currently under: ',
                                  children: [
                                    TextSpan(
                                      text: widget.currentManagerName,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Assign Manager *',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints:
                              BoxConstraints(minHeight: buttonHeight + 18),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: widget.managers.isEmpty
                              ? const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'No managers available',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                )
                              : SearchableDropdownField<String>(
                                  label: 'Assign Manager',
                                  sheetTitle: 'Assign Manager',
                                  showFieldLabel: false,
                                  value: _selectedManagerId,
                                  hintText: widget.actionLabel,
                                  items: widget.managers
                                      .map(
                                        (manager) => SearchableDropdownItem<String>(
                                          value: manager.id,
                                          label: manager.name,
                                          subtitle: manager.roleLabel,
                                        ),
                                      )
                                      .toList(),
                                  enabled: widget.managers.isNotEmpty,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _selectedManagerId = value);
                                  },
                                ),
                        ),
                        const SizedBox(height: 20),
                        if (isCompact)
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: buttonHeight,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: buttonHeight,
                                child: FilledButton(
                                  onPressed: widget.managers.isEmpty
                                      ? null
                                      : () => Navigator.of(context).pop(
                                            _selectedManagerId,
                                          ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    widget.actionLabel,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: buttonHeight,
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.textPrimary,
                                      side: const BorderSide(
                                        color: AppColors.border,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: buttonHeight,
                                  child: FilledButton(
                                    onPressed: widget.managers.isEmpty
                                        ? null
                                        : () => Navigator.of(context).pop(
                                              _selectedManagerId,
                                            ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      widget.actionLabel,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberSummary extends StatelessWidget {
  const _MemberSummary({
    required this.name,
    required this.role,
    required this.email,
  });

  final String name;
  final String role;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFA855F7),
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F8ED),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (email.trim().isNotEmpty)
                      Text(
                        email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
