class SalaryEmployee {
  const SalaryEmployee({
    required this.id,
    required this.fullName,
    required this.role,
    required this.email,
    required this.phoneNumber,
    this.monthlySalary,
    this.perDaySalary,
    this.effectiveFrom,
    this.salaryNotes,
    this.salarySetAt,
    required this.setByName,
    required this.salarySet,
    required this.rawData,
  });

  final String id;
  final String fullName;
  final String role;
  final String email;
  final String phoneNumber;
  final double? monthlySalary;
  final double? perDaySalary;
  final DateTime? effectiveFrom;
  final String? salaryNotes;
  final DateTime? salarySetAt;
  final String setByName;
  final bool salarySet;
  final Map<String, dynamic> rawData;

  factory SalaryEmployee.fromMap(Map<String, dynamic> json) {
    String readString(dynamic value) => value?.toString().trim() ?? '';

    double? readDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString().trim());
      return parsed;
    }

    DateTime? readDate(dynamic value) {
      if (value == null) return null;
      final raw = value.toString().trim();
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final setByName = readString(json['set_by_name']);

    return SalaryEmployee(
      id: readString(json['id']),
      fullName: readString(json['full_name']),
      role: readString(json['role']),
      email: readString(json['email']),
      phoneNumber: readString(json['phone_number']),
      monthlySalary: readDouble(json['monthly_salary']),
      perDaySalary: readDouble(json['per_day_salary']),
      effectiveFrom: readDate(json['effective_from']),
      salaryNotes: readString(json['salary_notes']).isEmpty
          ? null
          : readString(json['salary_notes']),
      salarySetAt: readDate(json['salary_set_at']),
      setByName: setByName.isEmpty ? '-' : setByName,
      salarySet: json['salary_set'] == true,
      rawData: Map<String, dynamic>.from(json),
    );
  }
}

class SalaryEmployeesResult {
  const SalaryEmployeesResult({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.employees,
  });

  final int currentPage;
  final int perPage;
  final int total;
  final int totalPages;
  final List<SalaryEmployee> employees;
}

class SalarySlip {
  const SalarySlip({
    required this.id,
    required this.userId,
    required this.month,
    required this.year,
    required this.monthlySalary,
    required this.workingDays,
    required this.presentDays,
    required this.absentDays,
    required this.leaveDays,
    required this.perDaySalary,
    required this.earnedSalary,
    required this.deductions,
    required this.finalSalary,
    required this.generatedBy,
    required this.employeeName,
    required this.employeeRole,
    required this.employeeEmail,
    required this.generatedByName,
    this.notes,
    this.createdAt,
    this.updatedAt,
    required this.rawData,
  });

  final String id;
  final String userId;
  final int month;
  final int year;
  final double monthlySalary;
  final int workingDays;
  final int presentDays;
  final int absentDays;
  final int leaveDays;
  final double perDaySalary;
  final double earnedSalary;
  final double deductions;
  final double finalSalary;
  final String generatedBy;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String employeeName;
  final String employeeRole;
  final String employeeEmail;
  final String generatedByName;
  final Map<String, dynamic> rawData;

  factory SalarySlip.fromMap(Map<String, dynamic> json) {
    String readString(dynamic value) => value?.toString().trim() ?? '';

    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double readDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? readDate(dynamic value) {
      final raw = readString(value);
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final notesValue = readString(json['notes']);

    return SalarySlip(
      id: readString(json['id']),
      userId: readString(json['user_id']),
      month: readInt(json['month']),
      year: readInt(json['year']),
      monthlySalary: readDouble(json['monthly_salary']),
      workingDays: readInt(json['working_days']),
      presentDays: readInt(json['present_days']),
      absentDays: readInt(json['absent_days']),
      leaveDays: readInt(json['leave_days']),
      perDaySalary: readDouble(json['per_day_salary']),
      earnedSalary: readDouble(json['earned_salary']),
      deductions: readDouble(json['deductions']),
      finalSalary: readDouble(json['final_salary']),
      generatedBy: readString(json['generated_by']),
      notes: notesValue.isEmpty ? null : notesValue,
      createdAt: readDate(json['created_at']),
      updatedAt: readDate(json['updated_at']),
      employeeName: readString(json['employee_name']),
      employeeRole: readString(json['employee_role']),
      employeeEmail: readString(json['employee_email']),
      generatedByName: readString(json['generated_by_name']),
      rawData: Map<String, dynamic>.from(json),
    );
  }
}

class SalarySlipsResult {
  const SalarySlipsResult({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
    required this.totalPages,
  });

  final List<SalarySlip> items;
  final int total;
  final int page;
  final int perPage;
  final int totalPages;
}

class GeneratedSalarySlipItem {
  const GeneratedSalarySlipItem({
    required this.userId,
    required this.fullName,
    required this.monthlySalary,
    required this.presentDays,
    required this.earnedSalary,
    required this.deductions,
    required this.finalSalary,
  });

  final String userId;
  final String fullName;
  final double monthlySalary;
  final int presentDays;
  final double earnedSalary;
  final double deductions;
  final double finalSalary;

  factory GeneratedSalarySlipItem.fromMap(Map<String, dynamic> json) {
    String readString(dynamic value) => value?.toString().trim() ?? '';
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double readDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return GeneratedSalarySlipItem(
      userId: readString(json['user_id']),
      fullName: readString(json['full_name']),
      monthlySalary: readDouble(json['monthly_salary']),
      presentDays: readInt(json['present_days']),
      earnedSalary: readDouble(json['earned_salary']),
      deductions: readDouble(json['deductions']),
      finalSalary: readDouble(json['final_salary']),
    );
  }
}

class SalaryGenerateAllResult {
  const SalaryGenerateAllResult({
    required this.message,
    required this.month,
    required this.year,
    required this.workingDays,
    required this.totalProcessed,
    required this.totalFailed,
    required this.slips,
  });

  final String message;
  final String month;
  final int year;
  final int workingDays;
  final int totalProcessed;
  final int totalFailed;
  final List<GeneratedSalarySlipItem> slips;
}

class SalarySetResult {
  const SalarySetResult({
    required this.message,
    required this.salary,
    required this.employee,
  });

  final String message;
  final Map<String, dynamic> salary;
  final Map<String, dynamic> employee;
}

class SalaryGenerateResult {
  const SalaryGenerateResult({
    required this.message,
    required this.slip,
    required this.employee,
    required this.breakdown,
  });

  final String message;
  final Map<String, dynamic> slip;
  final Map<String, dynamic> employee;
  final Map<String, dynamic> breakdown;
}

class SalaryIncentiveCreateResult {
  const SalaryIncentiveCreateResult({
    required this.message,
    required this.incentive,
  });

  final String message;
  final Map<String, dynamic> incentive;
}

class SalaryHistoryEntry {
  const SalaryHistoryEntry({
    required this.id,
    required this.userId,
    required this.monthlySalary,
    this.perDaySalary,
    this.effectiveFrom,
    required this.setBy,
    required this.setByName,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final double monthlySalary;
  final double? perDaySalary;
  final DateTime? effectiveFrom;
  final String setBy;
  final String setByName;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SalaryHistoryEntry.fromMap(Map<String, dynamic> json) {
    String readString(dynamic value) => value?.toString().trim() ?? '';
    double readDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? readDate(dynamic value) {
      final raw = readString(value);
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final notesRaw = readString(json['notes']);
    return SalaryHistoryEntry(
      id: readString(json['id']),
      userId: readString(json['user_id']),
      monthlySalary: readDouble(json['monthly_salary']),
      perDaySalary: json['per_day_salary'] == null
          ? null
          : readDouble(json['per_day_salary']),
      effectiveFrom: readDate(json['effective_from']),
      setBy: readString(json['set_by']),
      setByName: readString(json['set_by_name']),
      notes: notesRaw.isEmpty ? null : notesRaw,
      createdAt: readDate(json['created_at']),
      updatedAt: readDate(json['updated_at']),
    );
  }
}

class SalaryHistoryResult {
  const SalaryHistoryResult({
    required this.employee,
    required this.history,
  });

  final Map<String, dynamic> employee;
  final List<SalaryHistoryEntry> history;
}

class MySalaryCurrent {
  const MySalaryCurrent({
    required this.amount,
    this.perDaySalary,
    this.effectiveFrom,
  });

  final double amount;
  final double? perDaySalary;
  final DateTime? effectiveFrom;

  factory MySalaryCurrent.fromMap(Map<String, dynamic> json) {
    double readDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? readDate(dynamic value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return MySalaryCurrent(
      amount: readDouble(json['amount']),
      perDaySalary: json['per_day_salary'] == null
          ? null
          : readDouble(json['per_day_salary']),
      effectiveFrom: readDate(json['effective_from']),
    );
  }
}

class MySalarySlip {
  const MySalarySlip({
    required this.id,
    required this.month,
    required this.year,
    required this.monthLabel,
    required this.monthlySalary,
    required this.workingDays,
    required this.presentDays,
    required this.absentDays,
    required this.leaveDays,
    required this.perDaySalary,
    required this.earnedSalary,
    required this.deductions,
    required this.finalSalary,
    this.notes,
    this.generatedAt,
  });

  final String id;
  final int month;
  final int year;
  final String monthLabel;
  final double monthlySalary;
  final int workingDays;
  final int presentDays;
  final int absentDays;
  final int leaveDays;
  final double perDaySalary;
  final double earnedSalary;
  final double deductions;
  final double finalSalary;
  final String? notes;
  final DateTime? generatedAt;

  factory MySalarySlip.fromMap(Map<String, dynamic> json) {
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double readDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? readDate(dynamic value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final notesRaw = json['notes']?.toString().trim() ?? '';
    return MySalarySlip(
      id: json['id']?.toString().trim() ?? '',
      month: readInt(json['month']),
      year: readInt(json['year']),
      monthLabel: json['month_label']?.toString().trim() ?? '',
      monthlySalary: readDouble(json['monthly_salary']),
      workingDays: readInt(json['working_days']),
      presentDays: readInt(json['present_days']),
      absentDays: readInt(json['absent_days']),
      leaveDays: readInt(json['leave_days']),
      perDaySalary: readDouble(json['per_day_salary']),
      earnedSalary: readDouble(json['earned_salary']),
      deductions: readDouble(json['deductions']),
      finalSalary: readDouble(json['final_salary']),
      notes: notesRaw.isEmpty ? null : notesRaw,
      generatedAt: readDate(json['generated_at']),
    );
  }
}

class MySalaryResult {
  const MySalaryResult({
    required this.currentMonthlySalary,
    required this.salarySlips,
    required this.message,
  });

  final MySalaryCurrent? currentMonthlySalary;
  final List<MySalarySlip> salarySlips;
  final String message;
}
