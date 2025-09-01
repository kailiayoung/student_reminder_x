import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:students_reminder/src/services/attendance_service.dart';
import 'package:students_reminder/src/services/auth_service.dart';

class AttendanceHistory14d extends StatefulWidget {
  const AttendanceHistory14d({super.key});

  @override
  State<AttendanceHistory14d> createState() => _AttendanceHistory14dState();
}

class _AttendanceHistory14dState extends State<AttendanceHistory14d> {
  bool _showCalendar = false;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser!.uid;

    // Past 14 days inclusive (local)
    final now = JmTime.nowLocal();
    final end = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance • Last 14 days'),
        actions: [
          IconButton(
            tooltip: _showCalendar ? 'Show list' : 'Show calendar',
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
            icon: Icon(_showCalendar ? Icons.view_list : Icons.calendar_month),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AttendanceService.streamLast14Days(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          // Lookup by 'dayId'
          final byDate = <String, Map<String, dynamic>>{
            for (final d in docs) (d.data()['dayId'] as String): d.data(),
          };

          // Fixed 14-day window (oldest → newest)
          final items = <_DayItem>[];
          for (int i = 13; i >= 0; i--) {
            final day = end.subtract(Duration(days: i));
            final id = JmTime.dateId(day);
            items.add(_DayItem(date: day, dateId: id, data: byDate[id]));
          }

          return _showCalendar
              ? _CalendarGrid(uid: uid, days: items)
              : _HistoryList(uid: uid, days: items);
        },
      ),
    );
  }
}

/* ---------- Model + helpers ---------- */

class _DayItem {
  final DateTime date;
  final String dateId;
  final Map<String, dynamic>? data;
  _DayItem({required this.date, required this.dateId, required this.data});

  String get status => (data?['status'] ?? 'absent').toString();
  DateTime? get inAt => (data?['inAt'] as Timestamp?)?.toDate();
  DateTime? get outAt => (data?['outAt'] as Timestamp?)?.toDate();
}

Color _statusColor(String status) {
  switch (status) {
    case 'early':
      return Colors.green;
    case 'late':
      return Colors.orange;
    case 'in_progress':
      return Colors.blue;
    case 'absent':
    default:
      return Colors.red;
  }
}

Widget _statusBadge(String status) {
  final c = _statusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      border: Border.all(color: c.withOpacity(0.6)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      status.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
    ),
  );
}

String _fmtJM(DateTime? t) => t == null ? '—' : DateFormat.jm().format(t);

/* ---------- List view ---------- */

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.uid, required this.days});
  final String uid;
  final List<_DayItem> days;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: days.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final d = days[i];
        final dateLabel = DateFormat('EEE, MMM d').format(d.date);
        return ListTile(
          title: Text(dateLabel),
          subtitle: Row(
            children: [
              if (d.inAt != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text('In: ${_fmtJM(d.inAt)}'),
                ),
              if (d.outAt != null)
                Text('Out: ${_fmtJM(d.outAt)}'),
            ],
          ),
          trailing: _statusBadge(d.status),
          onTap: () => _openMapModal(context, uid: uid, dayId: d.dateId),
        );
      },
    );
  }
}

/* ---------- Compact calendar grid (2×7) ---------- */

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.uid, required this.days});
  final String uid;
  final List<_DayItem> days;

  @override
  Widget build(BuildContext context) {
    // 2 rows × 7 cols, oldest → newest
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: const [
              _Legend(color: Colors.green, label: 'Early'),
              _Legend(color: Colors.orange, label: 'Late'),
              _Legend(color: Colors.red, label: 'Absent'),
              _Legend(color: Colors.blue, label: 'In progress'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (context, i) {
                final d = days[i];
                final dot = _statusColor(d.status);
                return InkWell(
                  onTap: () => _openMapModal(context, uid: uid, dayId: d.dateId),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('d').format(d.date),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                        const SizedBox(height: 6),
                        Text(
                          d.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: dot),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/* ---------- Map modal ---------- */

void _openMapModal(BuildContext context, {required String uid, required String dayId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => DayMapModal(uid: uid, dayId: dayId),
  );
}

class DayMapModal extends StatefulWidget {
  const DayMapModal({super.key, required this.uid, required this.dayId});
  final String uid;
  final String dayId;

  @override
  State<DayMapModal> createState() => _DayMapModalState();
}

class _DayMapModalState extends State<DayMapModal> {
  GoogleMapController? _controller;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('attendance').doc(widget.uid)
        .collection('days').doc(widget.dayId);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: ref.get(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(height: 420, child: Center(child: CircularProgressIndicator()));
            }
            final data = snap.data!.data();
            if (data == null) {
              return _EmptyDayView(dayId: widget.dayId);
            }

            final status = (data['status'] as String?) ?? 'absent';
            final inAt   = (data['inAt']  as Timestamp?)?.toDate();
            final outAt  = (data['outAt'] as Timestamp?)?.toDate();
            final inLoc  = _toLatLng(data['inLoc']);
            final outLoc = _toLatLng(data['outLoc']);

            // Build markers
            final markers = <Marker>{
              if (inLoc != null)
                Marker(
                  markerId: const MarkerId('in'),
                  position: inLoc,
                  infoWindow: InfoWindow(title: 'Clock In', snippet: _fmtJM(inAt)),
                ),
              if (outLoc != null)
                Marker(
                  markerId: const MarkerId('out'),
                  position: outLoc,
                  infoWindow: InfoWindow(title: 'Clock Out', snippet: _fmtJM(outAt)),
                ),
            };

            // Build polyline (in → out) if both present
            final polylines = <Polyline>{
              if (inLoc != null && outLoc != null)
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: [inLoc, outLoc],
                  width: 4,
                ),
            };

            // Choose initial camera
            final LatLng initial = inLoc ?? outLoc ?? const LatLng(18.0179, -76.8099); // Kingston fallback
            final initialZoom = (inLoc != null && outLoc != null) ? 12.5 : 15.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Attendance • ${widget.dayId}',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      _statusChip(status),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 360,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: initial, zoom: initialZoom),
                    markers: markers,
                    polylines: polylines,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                    onMapCreated: (c) async {
                      _controller = c;
                      // If both markers exist, fit to bounds
                      if (inLoc != null && outLoc != null) {
                        final bounds = _latLngBoundsFrom(inLoc, outLoc);
                        await Future.delayed(const Duration(milliseconds: 200));
                        _controller?.animateCamera(
                          CameraUpdate.newLatLngBounds(bounds, 60),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: _InfoTile(label: 'Clock In', value: _fmtJM(inAt))),
                      const SizedBox(width: 12),
                      Expanded(child: _InfoTile(label: 'Clock Out', value: _fmtJM(outAt))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }

  LatLng? _toLatLng(dynamic v) {
    if (v is Map<String, dynamic>) {
      final lat = v['lat'];
      final lng = v['lng'];
      if (lat is num && lng is num) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  // Fit two points into bounds
  LatLngBounds _latLngBoundsFrom(LatLng a, LatLng b) {
    final sw = LatLng(
      a.latitude  < b.latitude  ? a.latitude  : b.latitude,
      a.longitude < b.longitude ? a.longitude : b.longitude,
    );
    final ne = LatLng(
      a.latitude  > b.latitude  ? a.latitude  : b.latitude,
      a.longitude > b.longitude ? a.longitude : b.longitude,
    );
    return LatLngBounds(southwest: sw, northeast: ne);
  }
}

Widget _statusChip(String status) {
  Color c;
  String label = status.toUpperCase();
  switch (status) {
    case 'early':
      c = Colors.green;
      break;
    case 'late':
      c = Colors.orange;
      break;
    case 'in_progress':
      c = Colors.blue;
      break;
    case 'absent':
    default:
      c = Colors.red;
      label = 'ABSENT';
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      border: Border.all(color: c.withOpacity(0.6)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
  );
}


class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _EmptyDayView extends StatelessWidget {
  const _EmptyDayView({required this.dayId, this.inAt, this.outAt});
  final String dayId;
  final DateTime? inAt;
  final DateTime? outAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Attendance • $dayId', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Icon(Icons.map_outlined, size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 8),
          Text(
            'No location data for this day.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _InfoTile(label: 'Clock In', value: _fmtJM(inAt))),
              const SizedBox(width: 12),
              Expanded(child: _InfoTile(label: 'Clock Out', value: _fmtJM(outAt))),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
