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
    this.pdfUrl,
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
  final String? pdfUrl;
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

    final employeeRaw = json['employee'];
    final employee =
        employeeRaw is Map ? Map<String, dynamic>.from(employeeRaw) : null;
    final generatedByRaw =
        json['generated_by_user'] ?? json['generated_by_data'];
    final generatedByUser = generatedByRaw is Map
        ? Map<String, dynamic>.from(generatedByRaw)
        : null;
    final notesValue = readString(json['notes'] ?? json['note']);

    return SalarySlip(
      id: readString(json['id'] ?? json['_id'] ?? json['salary_slip_id']),
      userId: readString(
        json['user_id'] ??
            json['employee_id'] ??
            employee?['id'] ??
            employee?['user_id'],
      ),
      month: readInt(json['month'] ?? json['salary_month']),
      year: readInt(json['year'] ?? json['salary_year']),
      monthlySalary: readDouble(json['monthly_salary'] ?? json['basic_salary']),
      workingDays: readInt(
        json['working_days'] ?? json['total_working_days'] ?? json['days'],
      ),
      presentDays: readInt(json['present_days'] ?? json['attendance_days']),
      absentDays: readInt(json['absent_days']),
      leaveDays: readInt(json['leave_days']),
      perDaySalary: readDouble(json['per_day_salary']),
      earnedSalary: readDouble(json['earned_salary']),
      deductions: readDouble(
        json['deductions'] ?? json['total_deductions'] ?? json['deduction'],
      ),
      finalSalary: readDouble(
        json['final_salary'] ?? json['net_salary'] ?? json['payable_salary'],
      ),
      generatedBy: readString(
        json['generated_by'] ??
            generatedByUser?['id'] ??
            generatedByUser?['user_id'],
      ),
      notes: notesValue.isEmpty ? null : notesValue,
      createdAt: readDate(json['created_at'] ?? json['generated_at']),
      updatedAt: readDate(json['updated_at']),
      employeeName: readString(
        json['employee_name'] ??
            json['full_name'] ??
            employee?['full_name'] ??
            employee?['name'],
      ),
      employeeRole: readString(
        json['employee_role'] ?? employee?['role'] ?? employee?['designation'],
      ),
      employeeEmail: readString(
        json['employee_email'] ?? employee?['email'] ?? employee?['work_email'],
      ),
      generatedByName: readString(
        json['generated_by_name'] ??
            generatedByUser?['full_name'] ??
            generatedByUser?['name'],
      ),
      pdfUrl: readString(json['pdf_url']).isEmpty
          ? null
          : readString(json['pdf_url']),
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

class SalarySlipUpdateResult {
  const SalarySlipUpdateResult({
    required this.message,
    required this.slip,
  });

  final String message;
  final Map<String, dynamic> slip;
}

class SalaryIncentiveCreateResult {
  const SalaryIncentiveCreateResult({
    required this.message,
    required this.incentive,
  });

  final String message;
  final Map<String, dynamic> incentive;
}

class SalaryCommission {
  const SalaryCommission({
    required this.id,
    required this.userId,
    this.leadId,
    this.projectId,
    required this.projectName,
    required this.commissionAmount,
    this.commissionPercentage,
    this.notes,
    required this.isPaid,
    required this.employeeName,
    required this.employeeRole,
    required this.leadName,
    this.createdAt,
    this.updatedAt,
    required this.rawData,
  });

  final String id;
  final String userId;
  final String? leadId;
  final String? projectId;
  final String projectName;
  final double commissionAmount;
  final double? commissionPercentage;
  final String? notes;
  final bool isPaid;
  final String employeeName;
  final String employeeRole;
  final String leadName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> rawData;

  factory SalaryCommission.fromMap(Map<String, dynamic> json) {
    String readString(dynamic value) => value?.toString().trim() ?? '';

    double? readDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString().trim());
    }

    DateTime? readDate(dynamic value) {
      final raw = readString(value);
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final userMap = json['user'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['user'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final leadMap = json['lead'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['lead'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final projectMap = json['project'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['project'] as Map<String, dynamic>)
        : <String, dynamic>{};

    final amount = readDouble(
          json['commission_amount'] ??
              json['amount'] ??
              json['commission'] ??
              json['value'],
        ) ??
        0;
    final percentage = readDouble(
      json['commission_percentage'] ?? json['percentage'] ?? json['percent'],
    );
    final notesRaw = readString(
      json['notes'] ?? json['note'] ?? json['description'],
    );
    final employeeName = readString(
      json['employee_name'] ??
          json['user_name'] ??
          json['full_name'] ??
          userMap['full_name'] ??
          userMap['name'],
    );
    final employeeRole = readString(
      json['employee_role'] ?? json['role'] ?? userMap['role'],
    );
    final leadName = readString(
      json['lead_name'] ??
          json['lead_title'] ??
          leadMap['full_name'] ??
          leadMap['name'],
    );
    final projectName = readString(
      json['project_name'] ?? projectMap['name'] ?? projectMap['project_name'],
    );
    final paidValue = json['is_paid'] ?? json['paid'] ?? json['status'];
    final isPaid = paidValue == true ||
        readString(paidValue).toLowerCase() == 'paid' ||
        readString(paidValue).toLowerCase() == 'true';

    return SalaryCommission(
      id: readString(json['id']),
      userId: readString(json['user_id'] ?? userMap['id']),
      leadId: readString(json['lead_id'] ?? leadMap['id']).isEmpty
          ? null
          : readString(json['lead_id'] ?? leadMap['id']),
      projectId: readString(
        json['project_id'] ??
            projectMap['id'] ??
            projectMap['project_id'] ??
            projectMap['uuid'],
      ).isEmpty
          ? null
          : readString(
              json['project_id'] ??
                  projectMap['id'] ??
                  projectMap['project_id'] ??
                  projectMap['uuid'],
            ),
      projectName: projectName,
      commissionAmount: amount,
      commissionPercentage: percentage,
      notes: notesRaw.isEmpty ? null : notesRaw,
      isPaid: isPaid,
      employeeName: employeeName,
      employeeRole: employeeRole,
      leadName: leadName,
      createdAt: readDate(json['created_at'] ?? json['date']),
      updatedAt: readDate(json['updated_at'] ?? json['paid_at']),
      rawData: Map<String, dynamic>.from(json),
    );
  }
}

class SalaryCommissionsResult {
  const SalaryCommissionsResult({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
    required this.totalPages,
  });

  final List<SalaryCommission> items;
  final int total;
  final int page;
  final int perPage;
  final int totalPages;
}

class SalaryCommissionMutationResult {
  const SalaryCommissionMutationResult({
    required this.message,
    required this.commission,
  });

  final String message;
  final Map<String, dynamic> commission;
}

class SalaryAdvance {
  const SalaryAdvance({
    required this.id,
    required this.userId,
    required this.advanceDate,
    required this.amount,
    this.transactionReference,
    this.paymentProofUrl,
    this.notes,
    required this.employeeName,
    required this.employeeRole,
    this.createdAt,
    this.updatedAt,
    required this.rawData,
  });

  final String id;
  final String userId;
  final DateTime? advanceDate;
  final double amount;
  final String? transactionReference;
  final String? paymentProofUrl;
  final String? notes;
  final String employeeName;
  final String employeeRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> rawData;

  factory SalaryAdvance.fromMap(Map<String, dynamic> json) {
    String readString(dynamic value) => value?.toString().trim() ?? '';

    double readDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString().trim() ?? '') ?? 0;
    }

    DateTime? readDate(dynamic value) {
      final raw = readString(value);
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final userMap = json['user'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['user'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final reference = readString(
      json['transaction_reference'] ?? json['reference'] ?? json['txn_ref'],
    );
    final proof = readString(
      json['payment_proof_url'] ?? json['proof_url'] ?? json['receipt_url'],
    );
    final notesRaw = readString(
      json['notes'] ?? json['note'] ?? json['description'],
    );

    return SalaryAdvance(
      id: readString(json['id']),
      userId: readString(json['user_id'] ?? userMap['id']),
      advanceDate: readDate(
        json['advance_date'] ?? json['date'] ?? json['created_at'],
      ),
      amount: readDouble(json['amount'] ?? json['advance_amount']),
      transactionReference: reference.isEmpty ? null : reference,
      paymentProofUrl: proof.isEmpty ? null : proof,
      notes: notesRaw.isEmpty ? null : notesRaw,
      employeeName: readString(
        json['employee_name'] ??
            json['user_name'] ??
            json['full_name'] ??
            userMap['full_name'] ??
            userMap['name'],
      ),
      employeeRole: readString(
        json['employee_role'] ?? json['role'] ?? userMap['role'],
      ),
      createdAt: readDate(json['created_at']),
      updatedAt: readDate(json['updated_at']),
      rawData: Map<String, dynamic>.from(json),
    );
  }
}

class SalaryAdvancesResult {
  const SalaryAdvancesResult({
    required this.items,
    required this.total,
  });

  final List<SalaryAdvance> items;
  final int total;
}

class SalaryAdvanceMutationResult {
  const SalaryAdvanceMutationResult({
    required this.message,
    required this.advance,
  });

  final String message;
  final Map<String, dynamic> advance;
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
    this.pdfUrl,
    this.notes,
    this.generatedAt,
  });

  final String id;
  final int month;
  final int year;
  final String monthLabel;
  final double monthlySalary;
  final int workingDays;
  final double presentDays;
  final int absentDays;
  final int leaveDays;
  final double perDaySalary;
  final double earnedSalary;
  final double deductions;
  final double finalSalary;
  final String? pdfUrl;
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
      presentDays: readDouble(json['present_days']),
      absentDays: readInt(json['absent_days']),
      leaveDays: readInt(json['leave_days']),
      perDaySalary: readDouble(json['per_day_salary']),
      earnedSalary: readDouble(json['earned_salary']),
      deductions: readDouble(json['deductions']),
      finalSalary: readDouble(json['final_salary']),
      pdfUrl: (json['pdf_url']?.toString().trim().isEmpty ?? true)
          ? null
          : json['pdf_url']!.toString().trim(),
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
