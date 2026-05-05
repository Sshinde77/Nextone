import 'package:nextone/models/auth_models.dart';
import 'package:nextone/services/auth_service.dart';

class AuthProvider {
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  String? get currentAuthToken => AuthService.currentAuthToken;

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

  Future<AuthProfileResult> profile({String? token}) {
    return _authService.profile(token: token);
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

  Future<Map<String, dynamic>> usersDetail(
      {required String id, String? token}) {
    return _authService.usersDetail(id: id, token: token);
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

  Future<LeadsListResult> leads({
    String? token,
    String? source,
    String? from,
    String? to,
    String? search,
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.leads(
      token: token,
      source: source,
      from: from,
      to: to,
      search: search,
      page: page,
      perPage: perPage,
    );
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

  Future<ExportFileResult> exportSiteVisits({String? token}) {
    return _authService.exportSiteVisits(token: token);
  }

  Future<ExportFileResult> exportFollowUps({String? token}) {
    return _authService.exportFollowUps(token: token);
  }

  Future<ExportFileResult> exportProjects({String? token}) {
    return _authService.exportProjects(token: token);
  }

  Future<ExportFileResult> exportUsers({String? token}) {
    return _authService.exportUsers(token: token);
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

  Future<LeadsListResult> followUps({
    String? token,
    String? dueFrom,
    String? dueTo,
    String? search,
    int? page,
    int? perPage,
  }) {
    return _authService.followUps(
      token: token,
      dueFrom: dueFrom,
      dueTo: dueTo,
      search: search,
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
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.siteVisits(
      token: token,
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

  Future<Map<String, dynamic>> createSiteVisit({
    required String leadId,
    required String projectId,
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
      visitDate: visitDate,
      visitTime: visitTime,
      assignedTo: assignedTo,
      notes: notes,
      transportArranged: transportArranged,
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
    String? token,
  }) {
    return _authService.updateSiteVisitStatus(
      id: id,
      status: status,
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

  Future<Map<String, dynamic>> leadDetail({required String id, String? token}) {
    return _authService.leadDetail(id: id, token: token);
  }

  Future<Map<String, dynamic>> createLead({
    required String name,
    required String phone,
    required String email,
    required String source,
    required String assignedTo,
    required String budget,
    required String locationPreference,
    required String notes,
    String? token,
  }) {
    return _authService.createLead(
      name: name,
      phone: phone,
      email: email,
      source: source,
      assignedTo: assignedTo,
      budget: budget,
      locationPreference: locationPreference,
      notes: notes,
      token: token,
    );
  }

  Future<Map<String, dynamic>> editLead({
    required String id,
    required String name,
    required String phone,
    required String email,
    required String source,
    required String assignedTo,
    required String budget,
    required String locationPreference,
    required String notes,
    String? token,
  }) {
    return _authService.editLead(
      id: id,
      name: name,
      phone: phone,
      email: email,
      source: source,
      assignedTo: assignedTo,
      budget: budget,
      locationPreference: locationPreference,
      notes: notes,
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
    String? search,
    int page = 1,
    int perPage = 20,
  }) {
    return _authService.projects(
      token: token,
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
      token: token,
    );
  }

  Future<Map<String, dynamic>> projectDetail(
      {required String id, String? token}) {
    return _authService.projectDetail(id: id, token: token);
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
      token: token,
    );
  }

  Future<void> deleteProject({required String id, String? token}) {
    return _authService.deleteProject(id: id, token: token);
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
