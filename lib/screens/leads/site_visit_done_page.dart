import 'package:flutter/material.dart';
import 'package:nextone/screens/leads/leads_page.dart';

class SiteVisitDonePage extends StatelessWidget {
  const SiteVisitDonePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LeadsPage(
      title: 'Site Visit Done',
      fixedStatus: 'site_visit_done',
      lockStatusFilter: true,
    );
  }
}
