# nextone

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.




when we click on the add follow up button in the @sitevisit it will open these kind of thing and 

and the current form is for existing one 

and for the new lead + follow up the form is given in image and below is the api given 

for the lead source drop down you and use the same dropdown of lead source which is in the [lead_detail_page.dart](lib/screens/leads/lead_detail_page.dart) 

###  Create Lead + Site Visit
Endpoint : POST /api/v1/site-visits/create-with-lead

Request Body
{
  // Lead fields
  "name": "Jane Smith",
  "phone": "+919876543212",
  "alternate_phone_number": "+919876543213",
  "email": "jane.smith@example.com",
  "source": "Walk-in",
  "project_id": "proj-uuid-001",
  "assigned_to": "user-uuid-001",
  "budget": "1Cr+",
  "location_preference": "Bandra",
  "configuration": "3BHK",
  "lead_notes": "Interested in 3BHK units",
  "callback_time": "2026-07-01T10:30:00Z",
  "next_followup_time": "2026-07-03T11:00:00Z",
  
  // Site visit fields
  "visit_date": "2026-07-05",
  "visit_time": "11:00",
  "notes": "Bring brochure and price list",
  "transport_arranged": false
}