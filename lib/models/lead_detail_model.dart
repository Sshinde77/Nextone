class LeadDetailModel {
  final String id;
  final String name;
  final String phone;
  final String alternatePhoneNumber;
  final String email;
  final String source;
  final String status;
  final String budget;
  final String locationPreference;
  final List<String> configurations;
  final String callbackTime;
  final String nextFollowupTime;
  final String projectName;
  final AssignedTo? assignedTo;

  LeadDetailModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.alternatePhoneNumber,
    required this.email,
    required this.source,
    required this.status,
    required this.budget,
    required this.locationPreference,
    required this.configurations,
    required this.callbackTime,
    required this.nextFollowupTime,
    required this.projectName,
    this.assignedTo,
  });

  factory LeadDetailModel.fromJson(Map<String, dynamic> json) {
    List<String> readList(dynamic value) {
      if (value is List) {
        return value
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      if (value is String && value.trim().isNotEmpty) {
        return value
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      return const <String>[];
    }

    return LeadDetailModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      alternatePhoneNumber: json['alternate_phone_number']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      budget: json['budget']?.toString() ?? '',
      locationPreference: json['location_preference']?.toString() ?? '',
      configurations: readList(
        json['configurations'] ?? json['configuration'],
      ),
      callbackTime: json['callback_time']?.toString() ?? '',
      nextFollowupTime:
          (json['next_followup_time'] ?? json['next_follow_up_time'])
                  ?.toString() ??
              '',
      projectName: (json['project_name'] ??
                  (json['project'] is Map<String, dynamic>
                      ? (json['project'] as Map<String, dynamic>)['name']
                      : null))
              ?.toString() ??
          '',
      assignedTo: json['assigned_to'] != null
          ? AssignedTo.fromJson(json['assigned_to'])
          : null,
    );
  }

  String get configurationText => configurations.join(', ');
}

class AssignedTo {
  final String id;
  final String fullName;
  final String phone;

  AssignedTo({
    required this.id,
    required this.fullName,
    required this.phone,
  });

  factory AssignedTo.fromJson(Map<String, dynamic> json) {
    return AssignedTo(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}
