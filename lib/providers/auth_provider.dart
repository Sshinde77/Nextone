import 'package:nextone/models/auth_models.dart';
import 'package:nextone/models/salary_models.dart';
import 'package:nextone/services/auth_service.dart';

class AuthProvider {
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  String? get currentAuthToken => AuthService.currentAuthToken;
  EffectivePermissionsResult get currentPermissions =>
      AuthService.currentPermissions;

  Future<String?> login({
    required String email,
    required String phoneNumber,
    required String password,
  }) {
    return _authService.login(
      email: email,
      phoneNumber: phoneNumber,
      password: password,
    );
  }

  Future<String?> register({
    required String email,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String password,
    required String role,
    String? token,
  }) {
    return _authService.register(
      email: email,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      password: password,
      role: role,
      token: token,
    );
  }

  Future<ForgotPasswordResult> forgotPassword({required String email}) {
    return _authService.forgotPassword(email: email);
  }

  Future<String?> resetPassword({
    required String token,
    required String newPassword,
  }) {
    return _authService.resetPassword(
      token: token,
      newPassword: newPassword,
    );
  }

  Future<AuthProfileResult> profile({String? token}) {
    return _authService.profile(token: token);
  }

  Future<EffectivePermissionsResult> myPermissions(
      {String? token, bool forceRefresh = false}) {
    return _authService.myPermissions(token: token, forceRefresh: forceRefresh);
  }

  Future<AuthTokenResult> refreshToken({String? refreshToken}) {
    return _authService.refreshToken(refreshToken: refreshToken);
  }

  Future<String?> logout({String? token, String? refreshToken}) {
    return _authService.logout(token: token, refreshToken: refreshToken);
  }

  Future<List<Map<String, dynamic>>> users({String? token}) {
    return _authService.users(token: token);
  }

  Future<LeadsListResult> usersPaged({
    String? token,
    int page = 1,
    int perPage = 10,
  }) {
    return _authService.usersPaged(token: token, page: page, perPage: perPage);
  }

  Future<List<Map<String, dynamic>>> assignmentUsers({String? token}) {
    return _authService.assignmentUsers(token: token);
  }

  Future<List<Map<String, dynamic>>> eligibleManagers({
    required String forRole,
    String? token,
  }) {
    return _authService.eligibleManagers(forRole: forRole, token: token);
  }

  Future<List<Map<String, dynamic>>> usersRoles({String? token}) {
    return _authService.usersRoles(token: token);
  }

  Future<SalaryEmployeesResult> salaryEmployees({String? token}) {
    return _authService.salaryEmployees(token: token);
  }

  Future<SalaryEmployeesResult> salaryEmployeesPaged({
    String? token,
    int page = 1,
    int perPage = 10,
  }) {
    return _authService.salaryEmployees(
      token: token,
      page: page,
      perPage: perPage,
    );
  }

  Future<SalarySlipsResult> salarySlips({
    required int month,
    required int year,
    int page = 1,
    int perPage = 20,
    String? token,
  }) {
    return _authService.salarySlips(
      month: month,
      year: year,
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<SalaryGenerateAllResult> salaryGenerateAll({
    required int month,
    required int year,
    int? workingDaysOverride,
    Map<String, num>? deductionsMap,
    String? notes,
    String? token,
  }) {
    return _authService.salaryGenerateAll(
      month: month,
      year: year,
      workingDaysOverride: workingDaysOverride,
      deductionsMap: deductionsMap,
      notes: notes,
      token: token,
    );
  }

  Future<SalarySetResult> salarySet({
    required String userId,
    required double monthlySalary,
    required double perDaySalary,
    required int workingDaysInMonth,
    required String effectiveFrom,
    String? notes,
    String? token,
  }) {
    return _authService.salarySet(
      userId: userId,
      monthlySalary: monthlySalary,
      perDaySalary: perDaySalary,
      workingDaysInMonth: workingDaysInMonth,
      effectiveFrom: effectiveFrom,
      notes: notes,
      token: token,
    );
  }

  Future<SalarySetResult> salaryAppraisal({
    required String userId,
    required double newSalary,
    required String effectiveFrom,
    required String appraisalNote,
    required int workingDaysInMonth,
    String? token,
  }) {
    return _authService.salaryAppraisal(
      userId: userId,
      newSalary: newSalary,
      effectiveFrom: effectiveFrom,
      appraisalNote: appraisalNote,
      workingDaysInMonth: workingDaysInMonth,
      token: token,
    );
  }

  Future<SalaryGenerateResult> salaryGenerate({
    required String userId,
    required int month,
    required int year,
    required double deductions,
    int? workingDaysOverride,
    String? notes,
    String? token,
  }) {
    return _authService.salaryGenerate(
      userId: userId,
      month: month,
      year: year,
      deductions: deductions,
      workingDaysOverride: workingDaysOverride,
      notes: notes,
      token: token,
    );
  }

  Future<SalaryHistoryResult> salaryHistory({
    required String userId,
    String? token,
  }) {
    return _authService.salaryHistory(
      userId: userId,
      token: token,
    );
  }

  Future<List<SalaryHistoryEntry>> mySalaryHistory({String? token}) {
    return _authService.mySalaryHistory(token: token);
  }

  Future<List<Map<String, dynamic>>> salaryIncentives({
    required String userId,
    String? token,
  }) {
    return _authService.salaryIncentives(
      userId: userId,
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> myIncentives({String? token}) {
    return _authService.myIncentives(token: token);
  }

  Future<SalaryIncentiveCreateResult> salaryAddIncentive({
    required String userId,
    required int month,
    required int year,
    required double amount,
    required String reason,
    String? token,
  }) {
    return _authService.salaryAddIncentive(
      userId: userId,
      month: month,
      year: year,
      amount: amount,
      reason: reason,
      token: token,
    );
  }

  Future<MySalaryResult> mySalary({
    int? month,
    required int year,
    String? token,
  }) {
    return _authService.mySalary(
      month: month,
      year: year,
      token: token,
    );
  }

  Future<Map<String, dynamic>> usersDetail(
      {required String id, String? token}) {
    return _authService.usersDetail(id: id, token: token);
  }

  Future<Map<String, dynamic>> userPerformance({
    required String id,
    required String from,
    required String to,
    String? token,
  }) {
    return _authService.userPerformance(
      id: id,
      from: from,
      to: to,
      token: token,
    );
  }

  Future<LeadsListResult> teamHistoryLeads({
    required String userId,
    int page = 1,
    int perPage = 20,
    String? token,
  }) {
    return _authService.teamHistoryLeads(
      userId: userId,
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<LeadsListResult> teamHistoryFollowUps({
    required String userId,
    bool? isCompleted,
    String? priority,
    String? from,
    String? to,
    int page = 1,
    int perPage = 20,
    String? token,
  }) {
    return _authService.teamHistoryFollowUps(
      userId: userId,
      isCompleted: isCompleted,
      priority: priority,
      from: from,
      to: to,
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<LeadsListResult> teamHistorySiteVisits({
    required String userId,
    String? status,
    String? from,
    String? to,
    int page = 1,
    int perPage = 20,
    String? token,
  }) {
    return _authService.teamHistorySiteVisits(
      userId: userId,
      status: status,
      from: from,
      to: to,
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<void> deleteUser({required String id, String? token}) {
    return _authService.deleteUser(id: id, token: token);
  }

  Future<void> editUser({
    required String id,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    String? token,
  }) {
    return _authService.editUser(
      id: id,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      token: token,
    );
  }

  Future<void> editUserRole({
    required String id,
    required String role,
    String? token,
  }) {
    return _authService.editUserRole(id: id, role: role, token: token);
  }

  Future<void> assignUserManager({
    required String id,
    required String managerId,
    String? token,
  }) {
    return _authService.assignUserManager(
      id: id,
      managerId: managerId,
      token: token,
    );
  }

  Future<LeadsListResult> leads({
    String? token,
    String? status,
    String? source,
    String? assignedTo,
    String? from,
    String? to,
    String? search,
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.leads(
      token: token,
      status: status,
      source: source,
      assignedTo: assignedTo,
      from: from,
      to: to,
      search: search,
      page: page,
      perPage: perPage,
    );
  }

  Future<LeadsListResult> myLeads({
    String? token,
    String? status,
    String? source,
    String? from,
    String? to,
    String? search,
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.myLeads(
      token: token,
      status: status,
      source: source,
      from: from,
      to: to,
      search: search,
      page: page,
      perPage: perPage,
    );
  }

  Future<void> deleteLead({
    required String id,
    String? token,
  }) {
    return _authService.deleteLead(id: id, token: token);
  }

  Future<ExportFileResult> exportLeads({
    required String from,
    required String to,
    String? token,
  }) {
    return _authService.exportLeads(
      from: from,
      to: to,
      token: token,
    );
  }

  Future<ExportFileResult> downloadLeadBulkTemplate({String? token}) {
    return _authService.downloadLeadBulkTemplate(token: token);
  }

  Future<Map<String, dynamic>> uploadLeadBulkFile({
    required String filePath,
    String? assignedTo,
    String? token,
  }) {
    return _authService.uploadLeadBulkFile(
      filePath: filePath,
      assignedTo: assignedTo,
      token: token,
    );
  }

  Future<ExportFileResult> downloadLeadBulkResult({
    required String filename,
    String? token,
  }) {
    return _authService.downloadLeadBulkResult(
      filename: filename,
      token: token,
    );
  }

  Future<ExportFileResult> exportSiteVisits({
    required String from,
    required String to,
    String? token,
  }) {
    return _authService.exportSiteVisits(
      from: from,
      to: to,
      token: token,
    );
  }

  Future<ExportFileResult> exportSiteRevisits({
    required String from,
    required String to,
    String? token,
  }) {
    return _authService.exportSiteRevisits(
      from: from,
      to: to,
      token: token,
    );
  }

  Future<ExportFileResult> exportFollowUps({
    required String from,
    required String to,
    String? token,
  }) {
    return _authService.exportFollowUps(
      from: from,
      to: to,
      token: token,
    );
  }

  Future<ExportFileResult> exportProjects({String? token}) {
    return _authService.exportProjects(token: token);
  }

  Future<ExportFileResult> exportClosures({
    required String from,
    required String to,
    String? token,
  }) {
    return _authService.exportClosures(
      from: from,
      to: to,
      token: token,
    );
  }

  Future<ExportFileResult> exportUsers({
    required String from,
    required String to,
    String? token,
  }) {
    return _authService.exportUsers(
      from: from,
      to: to,
      token: token,
    );
  }

  Future<ExportFileResult> exportAttendance({
    required String from,
    required String to,
    String? token,
  }) {
    return _authService.exportAttendance(
      from: from,
      to: to,
      token: token,
    );
  }

  Future<ExportFileResult> exportAll({String? token}) {
    return _authService.exportAll(token: token);
  }

  Future<Map<String, dynamic>> uploadAttendancePhoto({
    required String type,
    required String photoPath,
    String? token,
  }) {
    return _authService.uploadAttendancePhoto(
      type: type,
      photoPath: photoPath,
      token: token,
    );
  }

  Future<Map<String, dynamic>> attendanceCheckIn({
    required String photoUrl,
    required double latitude,
    required double longitude,
    required String address,
    required String device,
    required String notes,
    String? token,
  }) {
    return _authService.attendanceCheckIn(
      photoUrl: photoUrl,
      latitude: latitude,
      longitude: longitude,
      address: address,
      device: device,
      notes: notes,
      token: token,
    );
  }

  Future<Map<String, dynamic>> attendanceCheckOut({
    required String photoUrl,
    required double latitude,
    required double longitude,
    required String address,
    required String device,
    required String notes,
    String? token,
  }) {
    return _authService.attendanceCheckOut(
      photoUrl: photoUrl,
      latitude: latitude,
      longitude: longitude,
      address: address,
      device: device,
      notes: notes,
      token: token,
    );
  }

  Future<Map<String, dynamic>> attendanceToday({String? token}) {
    return _authService.attendanceToday(token: token);
  }

  Future<Map<String, dynamic>> attendanceCalendar({
    required int month,
    required int year,
    String? token,
  }) {
    return _authService.attendanceCalendar(
      month: month,
      year: year,
      token: token,
    );
  }

  Future<Map<String, dynamic>> attendanceMe({
    int page = 1,
    int perPage = 30,
    String? token,
  }) {
    return _authService.attendanceMe(
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<Map<String, dynamic>> attendanceUserHistory({
    required String userId,
    String? from,
    String? to,
    String? status,
    int page = 1,
    int perPage = 30,
    String? token,
  }) {
    return _authService.attendanceUserHistory(
      userId: userId,
      from: from,
      to: to,
      status: status,
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<Map<String, dynamic>> attendanceUser({
    required String userId,
    String? from,
    String? to,
    String? status,
    int page = 1,
    int perPage = 30,
    String? token,
  }) {
    return _authService.attendanceUser(
      userId: userId,
      from: from,
      to: to,
      status: status,
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<Map<String, dynamic>> attendanceByMonth({
    required int month,
    required int year,
    int page = 1,
    int perPage = 50,
    String? token,
  }) {
    return _authService.attendanceByMonth(
      month: month,
      year: year,
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<Map<String, dynamic>> attendanceByDate({
    required String date,
    String? token,
  }) {
    return _authService.attendanceByDate(
      date: date,
      token: token,
    );
  }

  Future<Map<String, dynamic>> attendanceSummary({
    String? from,
    String? to,
    String? token,
  }) {
    return _authService.attendanceSummary(
      from: from,
      to: to,
      token: token,
    );
  }

  Future<Map<String, dynamic>> attendanceLate({String? token}) {
    return _authService.attendanceLate(token: token);
  }

  Future<Map<String, dynamic>> attendanceTeam({
    String? from,
    String? to,
    int page = 1,
    int perPage = 100,
    String? token,
  }) {
    return _authService.attendanceTeam(
      from: from,
      to: to,
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<Map<String, dynamic>> attendancePending({
    String? date,
    String? token,
  }) {
    return _authService.attendancePending(
      date: date,
      token: token,
    );
  }

  Future<Map<String, dynamic>> attendanceApprove({
    required String id,
    required String status,
    String? reason,
    String? token,
  }) {
    return _authService.attendanceApprove(
      id: id,
      status: status,
      reason: reason,
      token: token,
    );
  }

  Future<Map<String, dynamic>> holidays({
    int page = 1,
    int perPage = 10,
    String? token,
  }) {
    return _authService.holidays(
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<Map<String, dynamic>> createHoliday({
    required String date,
    required String name,
    String description = '',
    required List<String> roles,
    required List<String> userIds,
    String? token,
  }) {
    return _authService.createHoliday(
      date: date,
      name: name,
      description: description,
      roles: roles,
      userIds: userIds,
      token: token,
    );
  }

  Future<Map<String, dynamic>> updateHoliday({
    required String id,
    required String date,
    required String name,
    String description = '',
    required List<String> roles,
    required List<String> userIds,
    String? token,
  }) {
    return _authService.updateHoliday(
      id: id,
      date: date,
      name: name,
      description: description,
      roles: roles,
      userIds: userIds,
      token: token,
    );
  }

  Future<void> deleteHoliday({
    required String id,
    String? token,
  }) {
    return _authService.deleteHoliday(id: id, token: token);
  }

  Future<LeadsListResult> phoneRevealMyRequests({
    int page = 1,
    int perPage = 20,
    String? token,
  }) {
    return _authService.phoneRevealMyRequests(
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<LeadsListResult> phoneRevealPending({
    int page = 1,
    int perPage = 20,
    String? token,
  }) {
    return _authService.phoneRevealPending(
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<LeadsListResult> phoneRevealAll({
    int page = 1,
    int perPage = 20,
    String? token,
  }) {
    return _authService.phoneRevealAll(
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<Map<String, dynamic>> phoneRevealCheck({
    required String leadId,
    String? token,
  }) {
    return _authService.phoneRevealCheck(
      leadId: leadId,
      token: token,
    );
  }

  Future<Map<String, dynamic>> requestPhoneReveal({
    required String leadId,
    required String reason,
    String? token,
  }) {
    return _authService.requestPhoneReveal(
      leadId: leadId,
      reason: reason,
      token: token,
    );
  }

  Future<Map<String, dynamic>> bulkRequestPhoneReveal({
    required List<String> leadIds,
    required String reason,
    String? token,
  }) {
    return _authService.bulkRequestPhoneReveal(
      leadIds: leadIds,
      reason: reason,
      token: token,
    );
  }

  Future<Map<String, dynamic>> approvePhoneReveal({
    required String id,
    required String note,
    String? token,
  }) {
    return _authService.approvePhoneReveal(
      id: id,
      note: note,
      token: token,
    );
  }

  Future<Map<String, dynamic>> declinePhoneReveal({
    required String id,
    required String note,
    String? token,
  }) {
    return _authService.declinePhoneReveal(
      id: id,
      note: note,
      token: token,
    );
  }

  Future<LeadsListResult> followUps({
    String? token,
    String? assignedTo,
    String? dueFrom,
    String? dueTo,
    String? search,
    int? page,
    int? perPage,
  }) {
    return _authService.followUps(
      token: token,
      assignedTo: assignedTo,
      dueFrom: dueFrom,
      dueTo: dueTo,
      search: search,
      page: page,
      perPage: perPage,
    );
  }

  Future<LeadsListResult> myFollowUps({
    String? token,
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.myFollowUps(
      token: token,
      page: page,
      perPage: perPage,
    );
  }

  Future<void> deleteFollowUp({required String id, String? token}) {
    return _authService.deleteFollowUp(id: id, token: token);
  }

  Future<Map<String, dynamic>> createFollowUp({
    required String title,
    required String leadId,
    required String dueDate,
    required String priority,
    required String notes,
    String? token,
  }) {
    return _authService.createFollowUp(
      title: title,
      leadId: leadId,
      dueDate: dueDate,
      priority: priority,
      notes: notes,
      token: token,
    );
  }

  Future<Map<String, dynamic>> createLeadWithFollowUp({
    required String name,
    required String phone,
    String alternatePhoneNumber = '',
    required String email,
    required String source,
    String projectId = '',
    String projectName = '',
    required String assignedTo,
    String budget = '',
    String locationPreference = '',
    String configuration = '',
    String leadNotes = '',
    String callbackTime = '',
    String nextFollowUpTime = '',
    required String title,
    required String dueDate,
    required String priority,
    required String notes,
    String? token,
  }) {
    return _authService.createLeadWithFollowUp(
      name: name,
      phone: phone,
      alternatePhoneNumber: alternatePhoneNumber,
      email: email,
      source: source,
      projectId: projectId,
      projectName: projectName,
      assignedTo: assignedTo,
      budget: budget,
      locationPreference: locationPreference,
      configuration: configuration,
      leadNotes: leadNotes,
      callbackTime: callbackTime,
      nextFollowUpTime: nextFollowUpTime,
      title: title,
      dueDate: dueDate,
      priority: priority,
      notes: notes,
      token: token,
    );
  }

  Future<Map<String, dynamic>> editFollowUp({
    required String id,
    String? title,
    String? leadId,
    String? dueDate,
    String? priority,
    String? notes,
    String? token,
  }) {
    return _authService.editFollowUp(
      id: id,
      title: title,
      leadId: leadId,
      dueDate: dueDate,
      priority: priority,
      notes: notes,
      token: token,
    );
  }

  Future<Map<String, dynamic>> followUpDetail({
    required String id,
    String? token,
  }) {
    return _authService.followUpDetail(id: id, token: token);
  }

  Future<Map<String, dynamic>> completeFollowUpStatus({
    required String id,
    required bool isCompleted,
    String? token,
  }) {
    return _authService.completeFollowUpStatus(
      id: id,
      isCompleted: isCompleted,
      token: token,
    );
  }

  Future<LeadsListResult> siteVisits({
    String? token,
    String? status,
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.siteVisits(
      token: token,
      status: status,
      page: page,
      perPage: perPage,
    );
  }

  Future<LeadsListResult> mySiteVisits({
    String? token,
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.mySiteVisits(
      token: token,
      page: page,
      perPage: perPage,
    );
  }

  Future<Map<String, dynamic>> mySummary({String? token}) {
    return _authService.mySummary(token: token);
  }

  Future<List<Map<String, dynamic>>> myActivities({
    int limit = 8,
    String? token,
  }) {
    return _authService.myActivities(limit: limit, token: token);
  }

  Future<LeadsListResult> siteRevisits({
    String? token,
    String? status,
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.siteRevisits(
      token: token,
      status: status,
      page: page,
      perPage: perPage,
    );
  }

  Future<LeadsListResult> myRevisits({
    required String from,
    required String to,
    String? token,
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.myRevisits(
      from: from,
      to: to,
      token: token,
      page: page,
      perPage: perPage,
    );
  }

  Future<LeadsListResult> closures({
    String? token,
    String? status,
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.closures(
      token: token,
      status: status,
      page: page,
      perPage: perPage,
    );
  }

  Future<Map<String, dynamic>> siteVisitDetail({
    required String id,
    String? token,
  }) {
    return _authService.siteVisitDetail(id: id, token: token);
  }

  Future<Map<String, dynamic>> siteRevisitDetail({
    required String id,
    String? token,
  }) {
    return _authService.siteRevisitDetail(id: id, token: token);
  }

  Future<Map<String, dynamic>> createSiteVisit({
    required String leadId,
    required String projectId,
    String projectName = '',
    required String visitDate,
    required String visitTime,
    required String assignedTo,
    required String notes,
    required bool transportArranged,
    String? token,
  }) {
    return _authService.createSiteVisit(
      leadId: leadId,
      projectId: projectId,
      projectName: projectName,
      visitDate: visitDate,
      visitTime: visitTime,
      assignedTo: assignedTo,
      notes: notes,
      transportArranged: transportArranged,
      token: token,
    );
  }

  Future<Map<String, dynamic>> createSiteVisitWithLead({
    required String name,
    required String phone,
    String alternatePhoneNumber = '',
    required String email,
    required String source,
    String projectId = '',
    String projectName = '',
    required String assignedTo,
    String budget = '',
    String locationPreference = '',
    String configuration = '',
    String leadNotes = '',
    String callbackTime = '',
    String nextFollowUpTime = '',
    required String visitDate,
    required String visitTime,
    required String notes,
    required bool transportArranged,
    String? token,
  }) {
    return _authService.createSiteVisitWithLead(
      name: name,
      phone: phone,
      alternatePhoneNumber: alternatePhoneNumber,
      email: email,
      source: source,
      projectId: projectId,
      projectName: projectName,
      assignedTo: assignedTo,
      budget: budget,
      locationPreference: locationPreference,
      configuration: configuration,
      leadNotes: leadNotes,
      callbackTime: callbackTime,
      nextFollowUpTime: nextFollowUpTime,
      visitDate: visitDate,
      visitTime: visitTime,
      notes: notes,
      transportArranged: transportArranged,
      token: token,
    );
  }

  Future<Map<String, dynamic>> createSiteRevisit({
    required String originalVisitId,
    required String visitDate,
    required String visitTime,
    required String reason,
    required String notes,
    required bool transportArranged,
    String? token,
  }) {
    return _authService.createSiteRevisit(
      originalVisitId: originalVisitId,
      visitDate: visitDate,
      visitTime: visitTime,
      reason: reason,
      notes: notes,
      transportArranged: transportArranged,
      token: token,
    );
  }

  Future<Map<String, dynamic>> createClosure({
    required String leadId,
    required String projectId,
    String? siteVisitId,
    required String bookingDate,
    required String unitNumber,
    required String towerBlock,
    required int floorNumber,
    required String unitType,
    required num carpetAreaSqft,
    required num superAreaSqft,
    required num agreedPrice,
    required num bookingAmount,
    required String paymentPlan,
    required bool loanRequired,
    String? loanBank,
    required num commissionPercent,
    required bool commissionPaid,
    List<String>? closedByManagerIds,
    required String closureNotes,
    List<Map<String, dynamic>>? documents,
    String? token,
  }) {
    return _authService.createClosure(
      leadId: leadId,
      projectId: projectId,
      siteVisitId: siteVisitId,
      bookingDate: bookingDate,
      unitNumber: unitNumber,
      towerBlock: towerBlock,
      floorNumber: floorNumber,
      unitType: unitType,
      carpetAreaSqft: carpetAreaSqft,
      superAreaSqft: superAreaSqft,
      agreedPrice: agreedPrice,
      bookingAmount: bookingAmount,
      paymentPlan: paymentPlan,
      loanRequired: loanRequired,
      loanBank: loanBank,
      commissionPercent: commissionPercent,
      commissionPaid: commissionPaid,
      closedByManagerIds: closedByManagerIds,
      closureNotes: closureNotes,
      documents: documents,
      token: token,
    );
  }

  Future<Map<String, dynamic>> editClosure({
    required String id,
    required String bookingDate,
    required String unitNumber,
    required String towerBlock,
    required int floorNumber,
    required String unitType,
    required num carpetAreaSqft,
    required num superAreaSqft,
    required num agreedPrice,
    required num bookingAmount,
    required String paymentPlan,
    required bool loanRequired,
    String? loanBank,
    required num commissionPercent,
    required bool commissionPaid,
    String? commissionPaidDate,
    List<String>? closedByManagerIds,
    required String closureNotes,
    List<Map<String, dynamic>>? documents,
    String? token,
  }) {
    return _authService.editClosure(
      id: id,
      bookingDate: bookingDate,
      unitNumber: unitNumber,
      towerBlock: towerBlock,
      floorNumber: floorNumber,
      unitType: unitType,
      carpetAreaSqft: carpetAreaSqft,
      superAreaSqft: superAreaSqft,
      agreedPrice: agreedPrice,
      bookingAmount: bookingAmount,
      paymentPlan: paymentPlan,
      loanRequired: loanRequired,
      loanBank: loanBank,
      commissionPercent: commissionPercent,
      commissionPaid: commissionPaid,
      commissionPaidDate: commissionPaidDate,
      closedByManagerIds: closedByManagerIds,
      closureNotes: closureNotes,
      documents: documents,
      token: token,
    );
  }

  Future<Map<String, dynamic>> updateClosureStatus({
    required String id,
    required String status,
    String note = '',
    String? token,
  }) {
    return _authService.updateClosureStatus(
      id: id,
      status: status,
      note: note,
      token: token,
    );
  }

  Future<Map<String, dynamic>> closureLeadDetail({
    required String id,
    String? token,
  }) {
    return _authService.closureLeadDetail(
      id: id,
      token: token,
    );
  }

  Future<Map<String, dynamic>> uploadClosureDocument({
    required String closureId,
    String filePath = '',
    List<int>? fileBytes,
    String fileName = '',
    required String documentType,
    required String name,
    String? token,
  }) {
    return _authService.uploadClosureDocument(
      closureId: closureId,
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      documentType: documentType,
      name: name,
      token: token,
    );
  }

  Future<Map<String, dynamic>> updateClosureDocument({
    required String closureId,
    required String documentId,
    required String name,
    String? token,
  }) {
    return _authService.updateClosureDocument(
      closureId: closureId,
      documentId: documentId,
      name: name,
      token: token,
    );
  }

  Future<void> deleteClosureDocument({
    required String closureId,
    required String documentId,
    String? token,
  }) {
    return _authService.deleteClosureDocument(
      closureId: closureId,
      documentId: documentId,
      token: token,
    );
  }

  Future<Map<String, dynamic>> editSiteRevisit({
    required String id,
    String? visitDate,
    String? visitTime,
    String? rescheduleReason,
    String? assignedTo,
    String? reason,
    String? notes,
    bool? transportArranged,
    String? token,
  }) {
    return _authService.editSiteRevisit(
      id: id,
      visitDate: visitDate,
      visitTime: visitTime,
      rescheduleReason: rescheduleReason,
      assignedTo: assignedTo,
      reason: reason,
      notes: notes,
      transportArranged: transportArranged,
      token: token,
    );
  }

  Future<Map<String, dynamic>> updateSiteRevisitStatus({
    required String id,
    required String status,
    String note = '',
    String? closingPerson,
    String? token,
  }) {
    return _authService.updateSiteRevisitStatus(
      id: id,
      status: status,
      note: note,
      closingPerson: closingPerson,
      token: token,
    );
  }

  Future<Map<String, dynamic>> editSiteVisit({
    required String id,
    String? visitDate,
    String? visitTime,
    String? rescheduleReason,
    String? token,
  }) {
    return _authService.editSiteVisit(
      id: id,
      visitDate: visitDate,
      visitTime: visitTime,
      rescheduleReason: rescheduleReason,
      token: token,
    );
  }

  Future<Map<String, dynamic>> updateSiteVisitStatus({
    required String id,
    required String status,
    String note = '',
    String? closingPerson,
    String? token,
  }) {
    return _authService.updateSiteVisitStatus(
      id: id,
      status: status,
      note: note,
      closingPerson: closingPerson,
      token: token,
    );
  }

  Future<Map<String, dynamic>> submitSiteVisitFeedback({
    required String id,
    required int rating,
    required String clientReaction,
    required String interestedIn,
    required String nextStep,
    required String remarks,
    String? token,
  }) {
    return _authService.submitSiteVisitFeedback(
      id: id,
      rating: rating,
      clientReaction: clientReaction,
      interestedIn: interestedIn,
      nextStep: nextStep,
      remarks: remarks,
      token: token,
    );
  }

  Future<Map<String, dynamic>> submitSiteRevisitFeedback({
    required String id,
    required int rating,
    required String clientReaction,
    required String interestedIn,
    required String nextStep,
    required String remarks,
    String? token,
  }) {
    return _authService.submitSiteRevisitFeedback(
      id: id,
      rating: rating,
      clientReaction: clientReaction,
      interestedIn: interestedIn,
      nextStep: nextStep,
      remarks: remarks,
      token: token,
    );
  }

  Future<Map<String, dynamic>> leadDetail({required String id, String? token}) {
    return _authService.leadDetail(id: id, token: token);
  }

  Future<List<Map<String, dynamic>>> leadActivity({
    required String id,
    String? token,
  }) {
    return _authService.leadActivity(id: id, token: token);
  }

  Future<List<Map<String, dynamic>>> leadCallRecordings({
    required String id,
    String? token,
  }) {
    return _authService.leadCallRecordings(id: id, token: token);
  }

  Future<Map<String, dynamic>> uploadLeadCallRecording({
    required String id,
    required String filePath,
    String phoneNumber = '',
    String name = '',
    String? token,
  }) {
    return _authService.uploadLeadCallRecording(
      id: id,
      filePath: filePath,
      phoneNumber: phoneNumber,
      name: name,
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> leadPaymentProofs({
    required String id,
    String? token,
  }) {
    return _authService.leadPaymentProofs(id: id, token: token);
  }

  Future<Map<String, dynamic>> uploadLeadPaymentProof({
    required String id,
    String filePath = '',
    List<int>? fileBytes,
    String fileName = '',
    String name = '',
    String amount = '',
    String? token,
  }) {
    return _authService.uploadLeadPaymentProof(
      id: id,
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      name: name,
      amount: amount,
      token: token,
    );
  }

  Future<void> deleteLeadPaymentProof({
    required String leadId,
    required String proofId,
    String? token,
  }) {
    return _authService.deleteLeadPaymentProof(
      leadId: leadId,
      proofId: proofId,
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> leadPhotos({
    required String id,
    String? token,
  }) {
    return _authService.leadPhotos(id: id, token: token);
  }

  Future<Map<String, dynamic>> uploadLeadPhoto({
    required String id,
    String filePath = '',
    List<int>? fileBytes,
    String fileName = '',
    String name = '',
    String? token,
  }) {
    return _authService.uploadLeadPhoto(
      id: id,
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      name: name,
      token: token,
    );
  }

  Future<void> deleteLeadPhoto({
    required String leadId,
    required String photoId,
    String? token,
  }) {
    return _authService.deleteLeadPhoto(
      leadId: leadId,
      photoId: photoId,
      token: token,
    );
  }

  Future<Map<String, dynamic>> updateLeadCallRecording({
    required String leadId,
    required String recordingId,
    String name = '',
    String phoneNumber = '',
    String? token,
  }) {
    return _authService.updateLeadCallRecording(
      leadId: leadId,
      recordingId: recordingId,
      name: name,
      phoneNumber: phoneNumber,
      token: token,
    );
  }

  Future<void> deleteLeadCallRecording({
    required String leadId,
    required String recordingId,
    String? token,
  }) {
    return _authService.deleteLeadCallRecording(
      leadId: leadId,
      recordingId: recordingId,
      token: token,
    );
  }

  Future<LeadsListResult> leadReassignmentHistory({
    required String id,
    String? token,
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.leadReassignmentHistory(
      id: id,
      token: token,
      page: page,
      perPage: perPage,
    );
  }

  Future<Map<String, dynamic>> createLead({
    required String name,
    required String phone,
    String alternatePhoneNumber = '',
    required String email,
    required String source,
    String status = '',
    String callbackTime = '',
    String nextFollowUpTime = '',
    required String assignedTo,
    String projectId = '',
    String projectName = '',
    required String budget,
    required String locationPreference,
    String configuration = '',
    required String notes,
    List<Map<String, dynamic>> callRecordings = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> paymentProof = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> photos = const <Map<String, dynamic>>[],
    String? token,
  }) {
    return _authService.createLead(
      name: name,
      phone: phone,
      alternatePhoneNumber: alternatePhoneNumber,
      email: email,
      source: source,
      status: status,
      callbackTime: callbackTime,
      nextFollowUpTime: nextFollowUpTime,
      assignedTo: assignedTo,
      projectId: projectId,
      projectName: projectName,
      budget: budget,
      locationPreference: locationPreference,
      configuration: configuration,
      notes: notes,
      callRecordings: callRecordings,
      paymentProof: paymentProof,
      photos: photos,
      token: token,
    );
  }

  Future<Map<String, dynamic>> editLead({
    required String id,
    required String phone,
    String source = '',
    String status = '',
    String callbackTime = '',
    String nextFollowUpTime = '',
    String assignedTo = '',
    String projectId = '',
    String projectName = '',
    required String budget,
    required String locationPreference,
    String configuration = '',
    List<Map<String, dynamic>> callRecordings = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> paymentProof = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> photos = const <Map<String, dynamic>>[],
    String? token,
  }) {
    return _authService.editLead(
      id: id,
      phone: phone,
      source: source,
      status: status,
      callbackTime: callbackTime,
      nextFollowUpTime: nextFollowUpTime,
      assignedTo: assignedTo,
      projectId: projectId,
      projectName: projectName,
      budget: budget,
      locationPreference: locationPreference,
      configuration: configuration,
      callRecordings: callRecordings,
      paymentProof: paymentProof,
      photos: photos,
      token: token,
    );
  }

  Future<Map<String, dynamic>> updateLeadStatus({
    required String id,
    required String status,
    String note = '',
    String? token,
  }) {
    return _authService.updateLeadStatus(
      id: id,
      status: status,
      note: note,
      token: token,
    );
  }

  Future<Map<String, dynamic>> reassignLead({
    required String id,
    required String assignedTo,
    String note = '',
    String? token,
  }) {
    return _authService.reassignLead(
      id: id,
      assignedTo: assignedTo,
      note: note,
      token: token,
    );
  }

  Future<LeadsListResult> projects({
    String? token,
    String? city,
    String? status,
    String? search,
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.projects(
      token: token,
      city: city,
      status: status,
      search: search,
      page: page,
      perPage: perPage,
    );
  }

  Future<Map<String, dynamic>> createProject({
    required String name,
    required String developer,
    required String city,
    required String locality,
    required String address,
    required List<String> configurations,
    required String priceRange,
    required int totalUnits,
    required String possessionDate,
    required String reraNumber,
    required List<String> amenities,
    required String status,
    required String description,
    List<Map<String, dynamic>> unitPlans = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> creatives = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> paymentPlans = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> videos = const <Map<String, dynamic>>[],
    String brochureUrl = '',
    String videoUrl = '',
    String paymentPlanUrl = '',
    String homeLoanInfo = '',
    String? token,
  }) {
    return _authService.createProject(
      name: name,
      developer: developer,
      city: city,
      locality: locality,
      address: address,
      configurations: configurations,
      priceRange: priceRange,
      totalUnits: totalUnits,
      possessionDate: possessionDate,
      reraNumber: reraNumber,
      amenities: amenities,
      status: status,
      description: description,
      unitPlans: unitPlans,
      creatives: creatives,
      paymentPlans: paymentPlans,
      videos: videos,
      brochureUrl: brochureUrl,
      videoUrl: videoUrl,
      paymentPlanUrl: paymentPlanUrl,
      homeLoanInfo: homeLoanInfo,
      token: token,
    );
  }

  Future<Map<String, dynamic>> projectDetail(
      {required String id, String? token}) {
    return _authService.projectDetail(id: id, token: token);
  }

  Future<Map<String, dynamic>> projectDocuments({
    required String id,
    String? token,
  }) {
    return _authService.projectDocuments(id: id, token: token);
  }

  Future<LeadsListResult> projectLeads({
    required String id,
    String? token,
    String? search,
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.projectLeads(
      id: id,
      token: token,
      search: search,
      page: page,
      perPage: perPage,
    );
  }

  Future<Map<String, dynamic>> uploadProjectDocuments({
    required String id,
    List<String> unitPlanFilePaths = const <String>[],
    List<String> creativeFilePaths = const <String>[],
    List<String> paymentPlanFilePaths = const <String>[],
    List<String> videoFilePaths = const <String>[],
    String? token,
  }) {
    return _authService.uploadProjectDocuments(
      id: id,
      unitPlanFilePaths: unitPlanFilePaths,
      creativeFilePaths: creativeFilePaths,
      paymentPlanFilePaths: paymentPlanFilePaths,
      videoFilePaths: videoFilePaths,
      token: token,
    );
  }

  Future<ExportFileResult> downloadAllProjectDocuments({
    required String id,
    String? token,
  }) {
    return _authService.downloadAllProjectDocuments(id: id, token: token);
  }

  Future<ExportFileResult> downloadAllProjectPaymentPlans({
    required String id,
    String? token,
  }) {
    return _authService.downloadAllProjectPaymentPlans(id: id, token: token);
  }

  Future<ExportFileResult> downloadAllProjectVideos({
    required String id,
    String? token,
  }) {
    return _authService.downloadAllProjectVideos(id: id, token: token);
  }

  Future<ExportFileResult> downloadProjectDocument({
    required String projectId,
    required String documentId,
    String? token,
  }) {
    return _authService.downloadProjectDocument(
      projectId: projectId,
      documentId: documentId,
      token: token,
    );
  }

  Future<void> deleteProjectDocument({
    required String projectId,
    required String documentId,
    String? token,
  }) {
    return _authService.deleteProjectDocument(
      projectId: projectId,
      documentId: documentId,
      token: token,
    );
  }

  Future<Map<String, dynamic>> editProject({
    required String id,
    required String name,
    required String developer,
    required String city,
    required String locality,
    required String address,
    required List<String> configurations,
    required String priceRange,
    required int totalUnits,
    required String possessionDate,
    required String reraNumber,
    required List<String> amenities,
    required String status,
    required String description,
    List<Map<String, dynamic>> unitPlans = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> creatives = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> paymentPlans = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> videos = const <Map<String, dynamic>>[],
    String brochureUrl = '',
    String videoUrl = '',
    String paymentPlanUrl = '',
    String homeLoanInfo = '',
    String? token,
  }) {
    return _authService.editProject(
      id: id,
      name: name,
      developer: developer,
      city: city,
      locality: locality,
      address: address,
      configurations: configurations,
      priceRange: priceRange,
      totalUnits: totalUnits,
      possessionDate: possessionDate,
      reraNumber: reraNumber,
      amenities: amenities,
      status: status,
      description: description,
      unitPlans: unitPlans,
      creatives: creatives,
      paymentPlans: paymentPlans,
      videos: videos,
      brochureUrl: brochureUrl,
      videoUrl: videoUrl,
      paymentPlanUrl: paymentPlanUrl,
      homeLoanInfo: homeLoanInfo,
      token: token,
    );
  }

  Future<void> deleteProject({required String id, String? token}) {
    return _authService.deleteProject(id: id, token: token);
  }

  Future<Map<String, dynamic>> shareProject({
    required String id,
    required List<String> emails,
    String? message,
    List<String> fields = const <String>[],
    List<String> documentIds = const <String>[],
    String? token,
  }) {
    return _authService.shareProject(
      id: id,
      emails: emails,
      message: message,
      fields: fields,
      documentIds: documentIds,
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> notifications({
    String? token,
    String? type,
    bool? unreadOnly,
    int page = 1,
    int perPage = 30,
  }) {
    return _authService.notifications(
      token: token,
      type: type,
      unreadOnly: unreadOnly,
      page: page,
      perPage: perPage,
    );
  }

  Future<LeadsListResult> notificationsPaged({
    String? token,
    String? type,
    bool? unreadOnly,
    int page = 1,
    int perPage = 10,
  }) {
    return _authService.notificationsPaged(
      token: token,
      type: type,
      unreadOnly: unreadOnly,
      page: page,
      perPage: perPage,
    );
  }

  Future<void> deleteAllNotifications({String? token}) {
    return _authService.deleteAllNotifications(token: token);
  }

  Future<int> unreadNotificationsCount({String? token}) {
    return _authService.unreadNotificationsCount(token: token);
  }

  Future<List<String>> notificationTypes({String? token}) {
    return _authService.notificationTypes(token: token);
  }

  Future<void> markAllNotificationsRead({String? token}) {
    return _authService.markAllNotificationsRead(token: token);
  }

  Future<Map<String, dynamic>> markSingleNotificationRead({
    required String id,
    String? token,
  }) {
    return _authService.markSingleNotificationRead(id: id, token: token);
  }

  Future<void> deleteSingleNotification({
    required String id,
    String? token,
  }) {
    return _authService.deleteSingleNotification(id: id, token: token);
  }

  Future<Map<String, dynamic>> dashboardStats({
    required String from,
    required String to,
    String? token,
  }) {
    return _authService.dashboardStats(
      from: from,
      to: to,
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> dashboardUpcomingSiteVisits({
    int limit = 5,
    String? token,
  }) {
    return _authService.dashboardUpcomingSiteVisits(
      limit: limit,
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> dashboardRecentActivity({
    int limit = 5,
    String? token,
  }) {
    return _authService.dashboardRecentActivity(
      limit: limit,
      token: token,
    );
  }

  Future<Map<String, dynamic>> dashboardMyTargets({
    required String month,
    String? token,
  }) {
    return _authService.dashboardMyTargets(
      month: month,
      token: token,
    );
  }

  Future<Map<String, dynamic>> targets({
    required String month,
    int page = 1,
    int perPage = 10,
    String? token,
  }) {
    return _authService.targets(
      month: month,
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<Map<String, dynamic>> setTarget({
    required String userId,
    required String month,
    required int siteVisitTarget,
    required int closureTarget,
    String? token,
  }) {
    return _authService.setTarget(
      userId: userId,
      month: month,
      siteVisitTarget: siteVisitTarget,
      closureTarget: closureTarget,
      token: token,
    );
  }

  Future<Map<String, dynamic>> dashboardLeadPipeline({String? token}) {
    return _authService.dashboardLeadPipeline(token: token);
  }

  Future<Map<String, dynamic>> dashboardLeadSources({
    required String from,
    required String to,
    String? token,
  }) {
    return _authService.dashboardLeadSources(
      from: from,
      to: to,
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> leadSourcesConfig({String? token}) {
    return _authService.leadSourcesConfig(token: token);
  }

  Future<Map<String, dynamic>> createLeadSource({
    required String name,
    String? token,
  }) {
    return _authService.createLeadSource(
      name: name,
      token: token,
    );
  }

  Future<Map<String, dynamic>> updateLeadSource({
    required String id,
    required String name,
    required bool isActive,
    String? token,
  }) {
    return _authService.updateLeadSource(
      id: id,
      name: name,
      isActive: isActive,
      token: token,
    );
  }

  Future<void> deleteLeadSource({
    required String id,
    String? token,
  }) {
    return _authService.deleteLeadSource(
      id: id,
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> leadStatusesConfig({String? token}) {
    return _authService.leadStatusesConfig(token: token);
  }

  Future<Map<String, dynamic>> createLeadStatus({
    required String key,
    required String label,
    required String color,
    required int sortOrder,
    String? token,
  }) {
    return _authService.createLeadStatus(
      key: key,
      label: label,
      color: color,
      sortOrder: sortOrder,
      token: token,
    );
  }

  Future<Map<String, dynamic>> updateLeadStatusConfig({
    required String id,
    required String label,
    required String color,
    required bool isActive,
    String? token,
  }) {
    return _authService.updateLeadStatusConfig(
      id: id,
      label: label,
      color: color,
      isActive: isActive,
      token: token,
    );
  }

  Future<void> deleteLeadStatusConfig({
    required String id,
    String? token,
  }) {
    return _authService.deleteLeadStatusConfig(
      id: id,
      token: token,
    );
  }

  Future<Map<String, dynamic>> dashboardRevenue({
    required String range,
    String? token,
  }) {
    return _authService.dashboardRevenue(
      range: range,
      token: token,
    );
  }
}
