import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
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
      body: Column(
        children: [
          // Clock In / Clock Out buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _clockIn(uid),
                    icon: const Icon(Icons.login),
                    label: const Text("Clock In"),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _clockOut(uid),
                    icon: const Icon(Icons.logout),
                    label: const Text("Clock Out"),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AttendanceService.streamLast14Days(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final byDate = {for (final d in docs) (d.data()['dayId'] as String): d.data()};

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
          ),
        ],
      ),
    );
  }

  // ------------------ Clock In ------------------
  Future<void> _clockIn(String uid) async {
    final now = DateTime.now();
    final eightAM = DateTime(now.year, now.month, now.day, 8, 0);
    final eightThirty = DateTime(now.year, now.month, now.day, 8, 30);

    Position? location;
    try {
      location = await _getLocation();
    } catch (e) {
      _showSnack("Location error: $e");
      return;
    }

    String status;
    String? reason;
    if (now.isAfter(eightAM) && now.isBefore(eightThirty)) {
      status = "early";
    } else if (now.isAfter(eightThirty) &&
        now.isBefore(DateTime(now.year, now.month, now.day, 16))) {
      status = "late";
      reason = await _askLateReason();
      if (reason == null || reason.trim().isEmpty) {
        _showSnack("Late reason required.");
        return;
      }
      status += " — Reason: $reason";
    } else {
      _showSnack("Too late to clock in.");
      return;
    }

    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .doc(JmTime.dateId(now))
        .set({
      'dayId': JmTime.dateId(now),
      'inAt': Timestamp.fromDate(now),
      'inLoc': GeoPoint(location.latitude, location.longitude),
      'status': status,
    }, SetOptions(merge: true));

    _showSnack("Clocked in: $status at ${location.latitude}, ${location.longitude}");
  }

  // ------------------ Clock Out ------------------
  Future<void> _clockOut(String uid) async {
    final now = DateTime.now();

    Position? location;
    try {
      location = await _getLocation();
    } catch (e) {
      _showSnack("Location error: $e");
      return;
    }

    final dayDoc = FirebaseFirestore.instance
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .doc(JmTime.dateId(now));

    final snapshot = await dayDoc.get();
    if (!snapshot.exists || snapshot.data()?['inAt'] == null) {
      _showSnack("Cannot clock out before clocking in.");
      return;
    }

    await dayDoc.set({
      'outAt': Timestamp.fromDate(now),
      'outLoc': GeoPoint(location.latitude, location.longitude),
    }, SetOptions(merge: true));

    _showSnack("Clocked out at ${location.latitude}, ${location.longitude}");
  }

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'Location services disabled';

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw 'Location permission denied';
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<String?> _askLateReason() async {
    String reason = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Late Reason'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => reason = value,
          decoration: const InputDecoration(hintText: 'Why are you late?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reason),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ------------------ Models + Helpers ------------------

class _DayItem {
  final DateTime date;
  final String dateId;
  final Map<String, dynamic>? data;
  _DayItem({required this.date, required this.dateId, required this.data});

  String get rawStatus => (data?['status'] ?? 'absent').toString();

  String get status {
    if (rawStatus.toLowerCase().startsWith('early')) return 'early';
    if (rawStatus.toLowerCase().startsWith('late')) return 'late';
    if (rawStatus.toLowerCase().startsWith('in_progress')) return 'in_progress';
    return 'absent';
  }

  String? get reason {
    if (rawStatus.contains('— Reason:')) {
      return rawStatus.split('— Reason:')[1].trim();
    }
    return null;
  }

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

Widget _statusBadge(String status, [String? reason]) {
  final c = _statusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      border: Border.all(color: c.withOpacity(0.6)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      reason != null ? '$status\n$reason' : status.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
      textAlign: TextAlign.center,
    ),
  );
}

Widget _statusChip(String status, [String? reason]) {
  Color c;
  String label = status.toUpperCase();
  switch (status.toLowerCase()) {
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
  if (reason != null) label += '\n$reason';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      border: Border.all(color: c.withOpacity(0.6)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
      textAlign: TextAlign.center,
    ),
  );
}

String _fmtJM(DateTime? t) => t == null ? '—' : DateFormat.jm().format(t);

// ------------------ List View ------------------

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
          trailing: _statusBadge(d.status, d.reason),
          onTap: () => _openMapModal(context, uid: uid, dayId: d.dateId),
        );
      },
    );
  }
}

// ------------------ Calendar Grid ------------------

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.uid, required this.days});
  final String uid;
  final List<_DayItem> days;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
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

// ------------------ Map Modal ------------------

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
  bool _mapReady = false;
  LatLng? _inLoc;
  LatLng? _outLoc;
  String status = 'absent';
  DateTime? inAt;
  DateTime? outAt;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final ref = FirebaseFirestore.instance
        .collection('attendance')
        .doc(widget.uid)
        .collection('days')
        .doc(widget.dayId);
    final snap = await ref.get();
    if (!mounted) return;
    final data = snap.data();
    if (data != null) {
      setState(() {
        status = (data['status'] as String?) ?? 'absent';
        inAt = (data['inAt'] as Timestamp?)?.toDate();
        outAt = (data['outAt'] as Timestamp?)?.toDate();
        _inLoc = _toLatLng(data['inLoc']);
        _outLoc = _toLatLng(data['outLoc']);
        _mapReady = true;
      });
    }
  }

  LatLng? _toLatLng(dynamic data) {
    if (data is GeoPoint) return LatLng(data.latitude, data.longitude);
    return null;
  }

  LatLngBounds _latLngBoundsFrom(LatLng a, LatLng b) {
    final sw = LatLng(min(a.latitude, b.latitude), min(a.longitude, b.longitude));
    final ne = LatLng(max(a.latitude, b.latitude), max(a.longitude, b.longitude));
    return LatLngBounds(southwest: sw, northeast: ne);
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      if (_inLoc != null)
        Marker(markerId: const MarkerId('in'), position: _inLoc!, infoWindow: InfoWindow(title: 'Clock In', snippet: _fmtJM(inAt))),
      if (_outLoc != null)
        Marker(markerId: const MarkerId('out'), position: _outLoc!, infoWindow: InfoWindow(title: 'Clock Out', snippet: _fmtJM(outAt))),
    };

    final polylines = <Polyline>{
      if (_inLoc != null && _outLoc != null)
        Polyline(polylineId: const PolylineId('route'), points: [_inLoc!, _outLoc!], width: 4),
    };

    final initial = _inLoc ?? _outLoc ?? const LatLng(18.0179, -76.8099);
    final initialZoom = (_inLoc != null && _outLoc != null) ? 12.5 : 15.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          height: 420,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text('Attendance • ${widget.dayId}', style: Theme.of(context).textTheme.titleMedium)),
                    _statusChip(status),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _mapReady && !kIsWeb
                    ? GoogleMap(
                        initialCameraPosition: CameraPosition(target: initial, zoom: initialZoom),
                        markers: markers,
                        polylines: polylines,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: true,
                        mapToolbarEnabled: false,
                        onMapCreated: (c) async {
                          _controller = c;
                          if (_inLoc != null && _outLoc != null) {
                            final bounds = _latLngBoundsFrom(_inLoc!, _outLoc!);
                            await Future.delayed(const Duration(milliseconds: 200));
                            _controller?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
                          }
                        },
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.map, size: 50, color: Colors.grey),
                              const SizedBox(height: 10),
                              Text(
                                (_inLoc != null || _outLoc != null)
                                    ? 'Map not supported. Showing coordinates below.'
                                    : 'No location data available.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
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
          ),
        ),
      ),
    );
  }
}

// ------------------ Info Tile ------------------

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
