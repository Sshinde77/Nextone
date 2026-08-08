import 'package:flutter/material.dart';
import 'package:nextone/constants/app_colors.dart';
import 'package:nextone/models/lead_configuration_model.dart';
import 'package:nextone/providers/auth_provider.dart';
import 'package:nextone/utils/app_error_handler.dart';

Future<void> showLeadConfigurationDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return const _LeadConfigurationDialog();
    },
  );
}

class _LeadConfigurationDialog extends StatefulWidget {
  const _LeadConfigurationDialog();

  @override
  State<_LeadConfigurationDialog> createState() =>
      _LeadConfigurationDialogState();
}

class _LeadConfigurationDialogState extends State<_LeadConfigurationDialog> {
  final TextEditingController _createController = TextEditingController();
  final AuthProvider _authProvider = AuthProvider();

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<LeadConfigurationModel> _configurations =
      const <LeadConfigurationModel>[];

  @override
  void initState() {
    super.initState();
    _loadConfigurations();
  }

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  ScaffoldMessengerState? get _messenger => ScaffoldMessenger.maybeOf(context);

  void _showSnackBar(String message) {
    _messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadConfigurations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final configurations = await _authProvider.leadConfigurations(
        token: _authProvider.currentAuthToken,
        includeInactive: true,
      );
      if (!mounted) return;
      setState(() {
        _configurations = configurations;
      });
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addConfiguration() async {
    final name = _createController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Please enter configuration name.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _authProvider.createLeadConfiguration(
        name: name,
        token: _authProvider.currentAuthToken,
      );
      _createController.clear();
      await _loadConfigurations();
      if (!mounted) return;
      _showSnackBar('Configuration created successfully.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _editConfiguration(LeadConfigurationModel option) async {
    final nameController = TextEditingController(text: option.name);
    bool isActive = option.isActive;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (editContext) {
        return StatefulBuilder(
          builder: (context, setEditState) {
            return AlertDialog(
              title: const Text('Edit Configuration'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: 'Configuration name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: isSaving
                          ? null
                          : (value) {
                              setEditState(() {
                                isActive = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(editContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            _showSnackBar('Please enter configuration name.');
                            return;
                          }

                          setEditState(() {
                            isSaving = true;
                          });

                          try {
                            await _authProvider.updateLeadConfiguration(
                              id: option.id,
                              name: name,
                              isActive: isActive,
                              token: _authProvider.currentAuthToken,
                            );
                            if (!editContext.mounted) return;
                            Navigator.of(editContext).pop();
                            if (!mounted) return;
                            await _loadConfigurations();
                            if (!mounted) return;
                            _showSnackBar(
                                'Configuration updated successfully.');
                          } catch (error) {
                            if (!mounted) return;
                            _showSnackBar(
                                AppErrorHandler.friendlyMessage(error));
                            if (editContext.mounted) {
                              setEditState(() {
                                isSaving = false;
                              });
                            }
                          }
                        },
                  child: Text(isSaving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  Future<void> _deleteConfiguration(LeadConfigurationModel option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmContext) {
        return AlertDialog(
          title: const Text('Delete Configuration'),
          content: Text(
            'Delete "${option.name}"? This will remove the configuration if the backend allows it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(confirmContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(confirmContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _authProvider.deleteLeadConfiguration(
        id: option.id,
        token: _authProvider.currentAuthToken,
      );
      await _loadConfigurations();
      if (!mounted) return;
      _showSnackBar('Configuration deleted successfully.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(AppErrorHandler.friendlyMessage(error));
    }
  }

  Widget _buildStatusChip(bool isActive) {
    final backgroundColor =
        isActive ? const Color(0xFFDFF7E8) : const Color(0xFFE5E7EB);
    final foregroundColor =
        isActive ? const Color(0xFF15803D) : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF667085),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _configurations;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: SizedBox(
            height: 660,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Manage Configurations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _createController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_isSubmitting) {
                            _addConfiguration();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'New configuration (e.g. 5BHK)',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFD8E0EA),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFD8E0EA),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _addConfiguration,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          backgroundColor: const Color(0xFF6FB7FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE6EAF0)),
                      color: const Color(0xFFFAFBFD),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildHeaderCell('Configuration', flex: 5),
                              _buildHeaderCell('Status', flex: 2),
                              _buildHeaderCell('Actions', flex: 2),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : rows.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No configurations found.',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: rows.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final option = rows[index];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 5,
                                                child: Text(
                                                  option.name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: _buildStatusChip(
                                                  option.isActive,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    IconButton(
                                                      onPressed: _isSubmitting
                                                          ? null
                                                          : () =>
                                                              _editConfiguration(
                                                                option,
                                                              ),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      splashRadius: 18,
                                                      tooltip: 'Edit',
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                        size: 18,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed: _isSubmitting
                                                          ? null
                                                          : () =>
                                                              _deleteConfiguration(
                                                                option,
                                                              ),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      splashRadius: 18,
                                                      tooltip: 'Deactivate',
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Inactive configurations stay hidden from the lead form picker, but existing leads keep their saved value.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF98A2B3),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
