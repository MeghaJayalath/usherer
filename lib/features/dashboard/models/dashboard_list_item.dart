import '../../../data/models/tourist_group.dart';

sealed class DashboardListItem {}

class TimeHeaderItem extends DashboardListItem {
  final String timeStr;
  final bool isFirst;
  TimeHeaderItem({required this.timeStr, required this.isFirst});
}

class GroupCardItem extends DashboardListItem {
  final TouristGroup group;
  GroupCardItem(this.group);
}
