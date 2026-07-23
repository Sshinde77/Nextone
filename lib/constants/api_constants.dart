class ApiConstants {
  static const String baseUrl = 'https://api.nextonerealty.in/api/v1';

  // Auth Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String profile = '/auth/me';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';

  // User Endpoints
  static const String users = '/users';
  static const String usersRoles = '/users/roles';
  static const String usersdetail = '/users/{id}';
  static const String deleteuser = '/users/{id}';
  static const String edituser = '/users/{id}';
  static const String edituserrole = '/users/{id}/role';
  static const String userTeamTree = '/users/{id}/team-tree';
  static const String eligibleManagers = '/users/eligible-managers';
  static const String assignUserManager = '/users/{id}/assign-manager';
  static const String myPermissions = '/users/me/permissions';
  static const String userPerformance = '/users/{id}/performance';
  static const String teamHistoryLeads = '/team-history/{userId}/leads';
  static const String teamHistoryFollowUps =
      '/team-history/{userId}/follow-ups';
  static const String teamHistorySiteVisits =
      '/team-history/{userId}/site-visits';
  static const String mySummary = '/me/summary';
  static const String myActivities = '/me/activities';

  //leads Endpoints
  static const String myLeads = '/me/leads';
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
  static const String leadSourcesConfig = '/config/lead-sources';
  static const String leadSourceConfigDetail = '/config/lead-sources/{id}';
  static const String leadStatusesConfig = '/config/lead-statuses';
  static const String leadStatusConfigDetail = '/config/lead-statuses/{id}';
  static const String uploadPaymentProof = '/upload/payment-proof';
  static const String leadPaymentProof = '/leads/{id}/payment-proof';
  static const String leadPaymentProofs = '/leads/{id}/payment-proofs';
  static const String leadPaymentProofDetail =
      '/leads/{id}/payment-proofs/{proofId}';
  static const String leadPhotos = '/leads/{id}/photos';
  static const String leadPhotoDetail = '/leads/{id}/photos/{photoId}';

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
  static const String createFollowUpWithLead = '/tasks/create-with-lead';
  static const String followupsdetail = '/tasks/{id}';
  static const String deletefollowups = '/tasks/{id}';
  static const String editfollowups = '/tasks/{id}';
  static const String completestatusfollowups = '/tasks/{id}/complete';
  static const String myFollowUps = '/me/tasks';

  //project Endpoints
  static const String projects = '/projects';
  static const String publicProjects = '/public/projects';
  static const String uploadProjectPhoto = '/projects/upload-photo';
  static const String uploadUnitPlan = '/projects/upload-unit-plan';
  static const String uploadCreative = '/projects/upload-creative';
  static const String uploadVideo = '/projects/upload-video';
  static const String uploadDeveloperLogo = '/projects/upload-developer-logo';
  static const String createprojects = '/projects';
  static const String projectsdetail = '/projects/{id}';
  static const String deleteprojects = '/projects/{id}';
  static const String editprojects = '/projects/{id}';
  static const String projectDocuments = '/projects/{id}/documents';
  static const String projectDocumentsDownloadAll =
      '/projects/{id}/documents/download-all';
  static const String projectPaymentPlansDownloadAll =
      '/projects/{id}/documents/payment-plans/download-all';
  static const String projectVideosDownloadAll =
      '/projects/{id}/documents/videos/download-all';
  static const String projectDocumentDownload =
      '/projects/{id}/documents/{docId}/download';
  static const String projectDocumentDelete =
      '/projects/{id}/documents/{docId}';
  static const String projectShare = '/projects/{id}/share';
  static const String projectLeads = '/projects/{id}/leads';

  //site visit Endpoints
  static const String sitevisits = '/site-visits';
  static const String createsitevisits = '/site-visits';
  static const String createSiteVisitWithLead = '/site-visits/create-with-lead';
  static const String sitevisitsdetail = '/site-visits/{id}';
  static const String editsitevisits = '/site-visits/{id}';
  static const String updatestatussitevisits = '/site-visits/{id}/status';
  static const String submitfeedbacksitevisits = '/site-visits/{id}/feedback';
  static const String mySiteVisits = '/me/site-visits';
  static const String siteRevisits = '/site-revisits';
  static const String myRevisits = '/me/revisits';
  static const String submitfeedbacksiteRevisits =
      '/site-revisits/{id}/feedback';
  static const String closures = '/closures';
  static const String closuresDetail = '/closures/{id}';
  static const String closuresStatus = '/closures/{id}/status';
  static const String closuresLeadDetail = '/closures/lead/{id}';
  static const String closureDocuments = '/closures/{id}/documents';
  static const String closureDocumentDetail =
      '/closures/{id}/documents/{documentId}';

  // Export Endpoints
  static const String exportLeads = '/export/leads';
  static const String exportSiteVisits = '/export/site-visits';
  static const String exportSiteRevisits = '/export/site-revisits';
  static const String exportFollowUps = '/export/follow-ups';
  static const String exportProjects = '/export/projects';
  static const String exportClosures = '/export/closures';
  static const String exportUsers = '/export/users';
  static const String exportAttendance = '/export/attendance';
  static const String exportAll = '/export/all';

  // Attendance Endpoints
  static const String attendanceCheckin = '/attendance/checkin';
  static const String attendanceCheckout = '/attendance/checkout';
  static const String attendanceUploadPhoto = '/attendance/upload-photo';
  static const String attendanceToday = '/attendance/today';
  static const String attendanceMe = '/attendance/me';
  static const String attendanceUserHistory =
      '/attendance/user/{userId}/history';
  static const String attendanceUser = attendanceUserHistory;
  static const String attendanceCalendar = '/attendance/calendar';
  static const String attendanceByMonth = '/attendance/by-month';
  static const String attendanceByDate = '/attendance/by-date';
  static const String attendanceSummary = '/attendance/summary';
  static const String attendanceTeam = '/attendance/team';
  static const String attendanceLate = '/attendance/late';
  static const String attendancePending = '/attendance/pending';
  static const String attendanceapprove = '/attendance/{id}/approve';
  static const String attendanceLeaveMark = '/attendance/leave';
  static const String attendanceLeaveApply = '/attendance/leave/apply';
  static const String attendanceLeaves = '/attendance/leaves';
  static const String attendanceLeavesToday = '/attendance/leaves/today';
  static const String holidays = '/holidays';
  static const String holidayDetail = '/holidays/{id}';

  // Dashboard Endpoints
  static const String dashboardStats = '/dashboard/stats';
  static const String dashboardUpcomingSiteVisits =
      '/dashboard/upcoming-site-visits';
  static const String dashboardRecentActivity = '/dashboard/recent-activity';
  static const String dashboardMyTargets = '/targets/me';
  static const String dashboardLeadPipeline = '/dashboard/lead-pipeline';
  static const String dashboardLeadSources = '/dashboard/lead-sources';
  static const String dashboardRevenue = '/dashboard/revenue';
  static const String targets = '/targets';
  static const String targetSet = '/targets/{userId}';

  // Notifications Endpoints
  static const String notifications = '/notifications';
  static const String deletenotifications = '/notifications';
  static const String unreadcountnotifications = '/notifications/unread-count';
  static const String typesnotifications = '/notifications/types';
  static const String readallnotifications = '/notifications/read-all';
  static const String readsinglenotification = '/notifications/{id}/read';
  static const String deletesinglenotification = '/notifications/{id}';
  static const String fcmToken = '/fcm/token';

  // Salary Endpoints
  static const String salaryEmployees = '/salary/employees';
  static const String salarySlips = '/salary/slips';
  static const String salarySlipDetail = '/salary/slips/{id}';
  static const String salarySlipPdf = '/salary/slips/{id}/pdf';
  static const String salaryGenerateAll = '/salary/generate-all';
  static const String salarySet = '/salary/set';
  static const String salaryAppraisal = '/salary/appraisal';
  static const String salaryGenerate = '/salary/generate';
  static const String salaryHistory = '/salary/history/{userId}';
  static const String salaryIncentives = '/salary/incentives';
  static const String salaryIncentiveCreate = '/salary/incentive';
  static const String salaryCommissions = '/salary/commissions';
  static const String salaryCommissionCreate = '/salary/commission';
  static const String salaryCommissionPaid = '/salary/commission/{id}/paid';
  static const String salaryCommissionDelete = '/salary/commission/{id}';
  static const String salaryAdvances = '/salary/advances';
  static const String salaryAdvanceCreate = '/salary/advance';
  static const String salaryAdvanceDelete = '/salary/advance/{id}';
  static const String mySalary = '/salary/my-salary';
  static const String mySalaryHistory = '/salary/my-salary-history';
  static const String myIncentives = '/salary/my-incentives';
  static const String myCommissions = '/salary/my-commissions';
  static const String myAdvances = '/salary/my-advances';
}
