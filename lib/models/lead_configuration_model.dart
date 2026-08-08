class LeadConfigurationModel {
  const LeadConfigurationModel({
    required this.id,
    required this.name,
    required this.isActive,
    this.sortOrder,
    this.rawData = const <String, dynamic>{},
  });

  final String id;
  final String name;
  final bool isActive;
  final int? sortOrder;
  final Map<String, dynamic> rawData;

  factory LeadConfigurationModel.fromApi(Map<String, dynamic> json) {
    return LeadConfigurationModel(
      id: _readString(
        json['id'] ??
            json['config_id'] ??
            json['configuration_id'] ??
            json['uuid'],
      ),
      name: _readString(
        json['name'] ?? json['label'] ?? json['configuration'] ?? json['value'],
      ),
      isActive:
          _readBool(json['is_active'] ?? json['isActive'] ?? json['active']),
      sortOrder:
          _readInt(json['sort_order'] ?? json['sortOrder'] ?? json['order']),
      rawData: Map<String, dynamic>.from(json),
    );
  }

  LeadConfigurationModel copyWith({
    String? id,
    String? name,
    bool? isActive,
    int? sortOrder,
    Map<String, dynamic>? rawData,
  }) {
    return LeadConfigurationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      rawData: rawData ?? this.rawData,
    );
  }
}

String _readString(dynamic value) {
  if (value is String) {
    return value.trim();
  }
  if (value is num || value is bool) {
    return value.toString().trim();
  }
  return '';
}

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

int? _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}
