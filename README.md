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

in the @home screen theren will be not target section for admin and super admin 

now in the app i want to add one more part which will open in the side navigation 
which will be target which will include all the things in the image but in the mobile format for all the roles 

on click of the set target button it will open a pop to set target
below are the api curl request for get all data and set target post api 
curl -X 'GET' \
  'https://api.nextonerealty.in/api/v1/targets?month=2026-06' \
  -H 'accept: application/json' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjRjMWNmNzhkLTdlMDctNGVlYS1hNGQxLWUxNTNkNjBiNTI3MSIsImVtYWlsIjoiYW5pa2V0amhhQGdtYWlsLmNvbSIsInJvbGUiOiJhc3NvY2lhdGUiLCJpYXQiOjE3ODE3MjU3ODUsImV4cCI6MTc4MjMzMDU4NX0.1AqFkkpgJt7Y1I06OcfuKqhX_trNhl7eFGhqV-R1xmM'

  curl -X 'POST' \
  'https://api.nextonerealty.in/api/v1/targets/278de626-0b6e-436a-95e1-f32f60f3a0b1' \
  -H 'accept: */*' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjRjMWNmNzhkLTdlMDctNGVlYS1hNGQxLWUxNTNkNjBiNTI3MSIsImVtYWlsIjoiYW5pa2V0amhhQGdtYWlsLmNvbSIsInJvbGUiOiJhc3NvY2lhdGUiLCJpYXQiOjE3ODE3MjU3ODUsImV4cCI6MTc4MjMzMDU4NX0.1AqFkkpgJt7Y1I06OcfuKqhX_trNhl7eFGhqV-R1xmM' \
  -H 'Content-Type: application/json' \
  -d '{
  "month": "2026-06",
  "site_visit_target": 20,
  "closure_target": 2
}'


also for target check the permission before giving access