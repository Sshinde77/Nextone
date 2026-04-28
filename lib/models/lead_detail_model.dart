class LeadDetailModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String source;
  final String status;
  final String budget;
  final String locationPreference;
  final AssignedTo? assignedTo;

  LeadDetailModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.source,
    required this.status,
    required this.budget,
    required this.locationPreference,
    this.assignedTo,
  });

  factory LeadDetailModel.fromJson(Map<String, dynamic> json) {
    return LeadDetailModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      budget: json['budget']?.toString() ?? '',
      locationPreference: json['location_preference']?.toString() ?? '',
      assignedTo: json['assigned_to'] != null
          ? AssignedTo.fromJson(json['assigned_to'])
          : null,
    );
  }
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
