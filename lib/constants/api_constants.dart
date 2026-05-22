class ApiConstants {
  static const String baseUrl = 'https://nextoneapi.asynk.in/api/v1';

  // Auth Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String profile = '/auth/me';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';

  // User Endpoints
  static const String users = '/users';
  static const String usersdetail = '/users/{id}';
  static const String deleteuser = '/users/{id}';
  static const String edituser = '/users/{id}'; 
  static const String edituserrole = '/users/{id}/role';
  static const String assignUserManager = '/users/{id}/assign-manager';
  static const String userPerformance = '/users/{id}/performance';
  static const String teamHistoryLeads = '/team-history/{userId}/leads';
  static const String teamHistoryFollowUps =
      '/team-history/{userId}/follow-ups';
  static const String teamHistorySiteVisits =
      '/team-history/{userId}/site-visits';

  //leads Endpoints
  static const String leads = '/leads';
  static const String createsleads = '/leads';
  static const String leadsdetail = '/leads/{id}';
  static const String deleteleads = '/leads/{id}';
  static const String editleads = '/leads/{id}';
  static const String updatestatusleads = '/leads/{id}/status';
  static const String reassignmemberleads = '/leads/{id}/assign';
  static const String leadsBulkTemplate = '/leads/bulk/template';
  static const String leadsBulkUpload = '/leads/bulk/upload';
  static const String leadsBulkResult = '/leads/bulk/result/{filename}';

  // Phone Reveal Endpoints
  static const String phoneRevealMyRequests = '/phone-reveal/my-requests';
  static const String phoneRevealPending = '/phone-reveal/pending';
  static const String phoneRevealAll = '/phone-reveal/all';
  static const String phoneRevealCheck = '/phone-reveal/check/{leadId}';
  static const String phoneRevealRequest = '/phone-reveal/request';
  static const String phoneRevealBulkRequest = '/phone-reveal/bulk-request';
  static const String phoneRevealApprove = '/phone-reveal/{id}/approve';
  static const String phoneRevealDecline = '/phone-reveal/{id}/decline';

  //followup Endpoints
  static const String followups = '/tasks';
  static const String createfollowups = '/tasks';
  static const String followupsdetail = '/tasks/{id}';
  static const String deletefollowups = '/tasks/{id}';
  static const String editfollowups = '/tasks/{id}';
  static const String completestatusfollowups = '/tasks/{id}/complete';

  //project Endpoints
  static const String projects = '/projects';
  static const String createprojects = '/projects';
  static const String projectsdetail = '/projects/{id}';
  static const String deleteprojects = '/projects/{id}';
  static const String editprojects = '/projects/{id}';
  static const String projectDocuments = '/projects/{id}/documents';
  static const String projectDocumentsDownloadAll =
      '/projects/{id}/documents/download-all';
  static const String projectDocumentDownload =
      '/projects/{id}/documents/{docId}/download';
  static const String projectDocumentDelete = '/projects/{id}/documents/{docId}';

  //site visit Endpoints
  static const String sitevisits = '/site-visits';
  static const String createsitevisits = '/site-visits';
  static const String sitevisitsdetail = '/site-visits/{id}';
  static const String editsitevisits = '/site-visits/{id}';
  static const String updatestatussitevisits = '/site-visits/{id}/status';
  static const String submitfeedbacksitevisits = '/site-visits/{id}/feedback';
  static const String siteRevisits = '/site-revisits';

  // Export Endpoints
  static const String exportLeads = '/export/leads';
  static const String exportSiteVisits = '/export/site-visits';
  static const String exportFollowUps = '/export/follow-ups';
  static const String exportProjects = '/export/projects';
  static const String exportUsers = '/export/users';
  static const String exportAttendance = '/export/attendance';
  static const String exportAll = '/export/all';

  // Attendance Endpoints
  static const String attendanceCheckin = '/attendance/checkin';
  static const String attendanceCheckout = '/attendance/checkout';
  static const String attendanceUploadPhoto = '/attendance/upload-photo';
  static const String attendanceToday = '/attendance/today';
  static const String attendanceMe = '/attendance/me';
  static const String attendanceUser = '/attendance/user/{id}';
  static const String attendanceCalendar = '/attendance/calendar';
  static const String attendanceByMonth = '/attendance/by-month';
  static const String attendanceByDate = '/attendance/by-date';
  static const String attendanceSummary = '/attendance/summary';  
  static const String attendancePending = '/attendance/pending';
  static const String attendanceapprove = '/attendance/{id}/approve';

  // Dashboard Endpoints
  static const String dashboardStats = '/dashboard/stats';
  static const String dashboardUpcomingSiteVisits =   
      '/dashboard/upcoming-site-visits';
  static const String dashboardRecentActivity = '/dashboard/recent-activity';
  static const String dashboardLeadPipeline = '/dashboard/lead-pipeline';
  static const String dashboardLeadSources = '/dashboard/lead-sources';
  static const String dashboardRevenue = '/dashboard/revenue';

  // Notifications Endpoints
  static const String notifications = '/notifications';
  static const String deletenotifications = '/notifications';
  static const String unreadcountnotifications = '/notifications/unread-count';
  static const String typesnotifications = '/notifications/types';
  static const String readallnotifications = '/notifications/read-all';
  static const String readsinglenotification = '/notifications/{id}/read';
  static const String deletesinglenotification = '/notifications/{id}';

  // Salary Endpoints
  static const String salaryEmployees = '/salary/employees';
  static const String salarySlips = '/salary/slips';
  static const String salaryGenerateAll = '/salary/generate-all';
  static const String salarySet = '/salary/set';
  static const String salaryGenerate = '/salary/generate';
  static const String salaryHistory = '/salary/history/{userId}';
  static const String mySalary = '/salary/my-salary';
}
