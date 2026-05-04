class ApiConstants {
  static const String baseUrl = 'https://nextoneapi.onrender.com/api/v1';

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

  //leads Endpoints
  static const String leads = '/leads';
  static const String createsleads = '/leads';
  static const String leadsdetail = '/leads/{id}';
  static const String deleteleads = '/leads/{id}';
  static const String editleads = '/leads/{id}';
  static const String updatestatusleads = '/leads/{id}/status';
  static const String reassignmemberleads = '/leads/{id}/assign';

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

  //site visit Endpoints
  static const String sitevisits = '/site-visits';
  static const String createsitevisits = '/site-visits';
  static const String sitevisitsdetail = '/site-visits/{id}';
  static const String editsitevisits = '/site-visits/{id}';
  static const String updatestatussitevisits = '/site-visits/{id}/status';
  static const String submitfeedbacksitevisits = '/site-visits/{id}/feedback';

  // Export Endpoints
  static const String exportLeads = '/export/leads';
  static const String exportSiteVisits = '/export/site-visits';
  static const String exportFollowUps = '/export/follow-ups';
  static const String exportProjects = '/export/projects';
  static const String exportUsers = '/export/users';
  static const String exportAttendance = '/export/attendance';
  static const String exportAll = '/export/all';
}
