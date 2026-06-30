import 'package:flutter/material.dart';

class SearchableDropdownItem<T> {
  const SearchableDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.groupLabel,
  });

  final T value;
  final String label;
  final String? subtitle;
  final String? groupLabel;
}

class SearchableDropdownField<T> extends FormField<T> {
  SearchableDropdownField({
    super.key,
    required String label,
    required String hintText,
    required List<SearchableDropdownItem<T>> items,
    required T? value,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
    bool isLoading = false,
    String? errorText,
    String? helperText,
    Future<void> Function()? onRetry,
    String? Function(T?)? validator,
    String searchHintText = 'Search...',
    String noResultsText = 'No matches found',
    List<String>? groupOrder,
    bool showSearch = true,
    String? selectedLabel,
    this.showFieldLabel = true,
    String? sheetTitle,
  }) : super(
          initialValue: value,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          builder: (fieldState) {
            final selectedItem = _selectedItem<T>(items, fieldState.value);
            final displayLabel =
                selectedLabel ?? selectedItem?.label ?? hintText;
            final displaySubtitle =
                selectedItem != null ? selectedItem.subtitle : null;
            final hasSelection = selectedItem != null ||
                selectedLabel?.trim().isNotEmpty == true;
            final isInteractive = enabled && !isLoading && items.isNotEmpty;

            Future<void> openSheet() async {
              if (!isInteractive) {
                return;
              }

              final selected = await showModalBottomSheet<T>(
                context: fieldState.context,
                isScrollControlled: true,
                useRootNavigator: true,
                backgroundColor: Colors.transparent,
                builder: (context) => _SearchableDropdownSheet<T>(
                  title: sheetTitle?.trim().isNotEmpty == true
                      ? sheetTitle!.trim()
                      : label,
                  items: items,
                  searchHintText: searchHintText,
                  noResultsText: noResultsText,
                  groupOrder: groupOrder,
                  showSearch: showSearch,
                ),
              );

              if (selected == null) {
                return;
              }
              fieldState.didChange(selected);
              onChanged(selected);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showFieldLabel && label.trim().isNotEmpty) ...[
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF475467),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                InkWell(
                  onTap: openSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    isEmpty: false,
                    decoration: InputDecoration(
                      errorText: fieldState.errorText,
                      isDense: true,
                      filled: true,
                      fillColor:
                          enabled ? Colors.white : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD8E0EA)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: fieldState.hasError
                              ? const Color(0xFFD92D20)
                              : const Color(0xFFD8E0EA),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: enabled
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFD8E0EA),
                          width: 1.4,
                        ),
                      ),
                      suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasSelection
                                ? const Color(0xFF101828)
                                : const Color(0xFF98A2B3),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (displaySubtitle != null &&
                            displaySubtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            displaySubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (errorText != null && errorText.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText,
                    style: const TextStyle(
                      color: Color(0xFFD92D20),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (helperText != null && helperText.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    helperText,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (onRetry != null &&
                    errorText != null &&
                    errorText.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
                if (isLoading) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Loading...',
                    style: TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            );
          },
        );

  final bool showFieldLabel;
}

class _SearchableDropdownSheet<T> extends StatefulWidget {
  const _SearchableDropdownSheet({
    required this.title,
    required this.items,
    required this.searchHintText,
    required this.noResultsText,
    required this.groupOrder,
    required this.showSearch,
  });

  final String title;
  final List<SearchableDropdownItem<T>> items;
  final String searchHintText;
  final String noResultsText;
  final List<String>? groupOrder;
  final bool showSearch;

  @override
  State<_SearchableDropdownSheet<T>> createState() =>
      _SearchableDropdownSheetState<T>();
}

class _SearchableDropdownSheetState<T>
    extends State<_SearchableDropdownSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF101828),
                ),
              ),
              if (widget.showSearch) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: widget.searchHintText,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            widget.noResultsText,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: _buildEntries(filteredItems),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<SearchableDropdownItem<T>> get _filteredItems {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.items;
    }

    return widget.items.where((item) {
      final haystacks = <String>[
        item.label,
        item.subtitle ?? '',
        item.groupLabel ?? '',
      ];
      return haystacks.any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  List<Widget> _buildEntries(List<SearchableDropdownItem<T>> items) {
    final groupOrder = widget.groupOrder;
    if (groupOrder == null || groupOrder.isEmpty) {
      return items.map((item) => _buildItemTile(item)).toList();
    }

    final itemsByGroup = <String, List<SearchableDropdownItem<T>>>{};
    for (final item in items) {
      final group = item.groupLabel?.trim().isNotEmpty == true
          ? item.groupLabel!.trim()
          : 'Others';
      itemsByGroup.putIfAbsent(group, () => <SearchableDropdownItem<T>>[]);
      itemsByGroup[group]!.add(item);
    }

    final orderedGroups = <String>[
      ...groupOrder.where(itemsByGroup.containsKey),
      ...itemsByGroup.keys.where((group) => !groupOrder.contains(group)),
    ];

    final entries = <Widget>[];
    for (final group in orderedGroups) {
      final groupItems = itemsByGroup[group]!;
      entries.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            group,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      for (final item in groupItems) {
        entries.add(_buildItemTile(item));
      }
    }
    return entries;
  }

  Widget _buildItemTile(SearchableDropdownItem<T> item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        item.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF101828),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: item.subtitle != null && item.subtitle!.trim().isNotEmpty
          ? Text(
              item.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () => Navigator.of(context).pop(item.value),
    );
  }
}

SearchableDropdownItem<T>? _selectedItem<T>(
  List<SearchableDropdownItem<T>> items,
  T? value,
) {
  if (value == null) {
    return null;
  }
  for (final item in items) {
    if (item.value == value) {
      return item;
    }
  }
  return null;
}
