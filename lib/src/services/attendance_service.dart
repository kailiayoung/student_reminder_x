import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // for DateUtils.dateOnly

/* ----------------------- JmTime (time helpers) ----------------------- */
class JmTime {
  // Local "now" (America/Jamaica has no DST; if you need strict TZ, add timezone pkg)
  static DateTime nowLocal() => DateTime.now();

  // Lexicographically sortable day id, e.g., "2025-09-01"
  static String dateId(DateTime d) {
    final day = DateUtils.dateOnly(d);
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return '${day.year}-$mm-$dd';
  }

  static DateTime onDate(DateTime d, int hour, int minute) =>
      DateTime(d.year, d.month, d.day, hour, minute);

  /// Attendance windows for a given calendar day:
  /// start: 08:00 (earliest clock-in)
  /// lateEdge: 08:30 (after this = "late")
  /// cutoff: 16:00 (auto clock-out threshold)
  static ({DateTime start, DateTime lateEdge, DateTime cutoff}) windows(
    DateTime d,
  ) {
    final day = DateUtils.dateOnly(d);
    final start = onDate(day, 8, 0);
    final late = onDate(day, 8, 30);
    final cutoff = onDate(day, 16, 0);
    return (start: start, lateEdge: late, cutoff: cutoff);
  }
}

/* -------------------- Firestore path utilities -------------------- */
class _AttendanceDocPaths {
  static DocumentReference<Map<String, dynamic>> dayRef({
    required String uid,
    required DateTime when,
  }) {
    final id = JmTime.dateId(when);
    return FirebaseFirestore.instance
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .doc(id);
  }
}

/* ------------------------ AttendanceService ------------------------ */
class AttendanceService {
  AttendanceService._();
  static final instance = AttendanceService._();

  /* ----- helpers ----- */
  static String statusFromClockIn(DateTime t) {
    final w = JmTime.windows(t); // named record
    return t.isAfter(w.lateEdge) ? 'late' : 'early';
  }

  static bool canClockInNow(DateTime now) {
    final w = JmTime.windows(now);
    final atOrAfterStart =
        now.isAfter(w.start) || now.isAtSameMomentAs(w.start);
    final atOrBeforeCutoff =
        now.isBefore(w.cutoff) || now.isAtSameMomentAs(w.cutoff);
    return atOrAfterStart && atOrBeforeCutoff; // 08:00 ≤ now ≤ 16:00
  }

  static bool shouldAutoClockOut(DateTime now) {
    final w = JmTime.windows(now);
    return now.isAfter(w.cutoff);
  }

  /* ----- streams ----- */

  /// Last 14 days (newest → oldest). UI builds a fixed 14-day window around this.
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamLast14Days(
    String uid,
  ) {
    final now = JmTime.nowLocal();
    final start = DateUtils.dateOnly(now).subtract(const Duration(days: 13));
    return FirebaseFirestore.instance
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .where('dayId', isGreaterThanOrEqualTo: JmTime.dateId(start))
        .orderBy('dayId', descending: true)
        .limit(14)
        .snapshots();
  }

  /// Optional: dayId-bounded range (inclusive, oldest → newest).
  static Stream<QuerySnapshot<Map<String, dynamic>>> myRange(
    String uid,
    String startDayId,
    String endDayId,
  ) {
    return FirebaseFirestore.instance
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .where('dayId', isGreaterThanOrEqualTo: startDayId)
        .where('dayId', isLessThanOrEqualTo: endDayId)
        .orderBy('dayId', descending: false)
        .snapshots();
  }

  /* ----- Admin Methods ----- */

  /// Get attendance for all users on a specific date (for admin)
  static Stream<QuerySnapshot<Map<String, dynamic>>>
  streamAllUsersAttendanceForDate(DateTime date) {
    final dateId = JmTime.dateId(date);
    return FirebaseFirestore.instance
        .collectionGroup('days')
        .where('dayId', isEqualTo: dateId)
        .snapshots();
  }

  /// Get attendance for a specific user over date range (for admin)
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamUserAttendanceRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    final startId = JmTime.dateId(startDate);
    final endId = JmTime.dateId(endDate);
    return FirebaseFirestore.instance
        .collection('attendance')
        .doc(userId)
        .collection('days')
        .where('dayId', isGreaterThanOrEqualTo: startId)
        .where('dayId', isLessThanOrEqualTo: endId)
        .orderBy('dayId', descending: true)
        .snapshots();
  }

  /// Get all users' attendance for the current week (for admin dashboard)
  static Stream<QuerySnapshot<Map<String, dynamic>>>
  streamCurrentWeekAttendance() {
    final now = JmTime.nowLocal();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startId = JmTime.dateId(DateUtils.dateOnly(startOfWeek));

    return FirebaseFirestore.instance
        .collectionGroup('days')
        .where('dayId', isGreaterThanOrEqualTo: startId)
        .orderBy('dayId', descending: true)
        .snapshots();
  }

  /// Get attendance summary for a user (total present/absent/late days)
  static Future<Map<String, int>> getAttendanceSummary(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    final startId = JmTime.dateId(start);
    final endId = JmTime.dateId(end);

    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(userId)
        .collection('days')
        .where('dayId', isGreaterThanOrEqualTo: startId)
        .where('dayId', isLessThanOrEqualTo: endId)
        .get();

    int present = 0, absent = 0, late = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String? ?? 'absent';

      switch (status) {
        case 'present':
          present++;
          break;
        case 'late':
          late++;
          break;
        case 'absent':
        default:
          absent++;
          break;
      }
    }

    return {
      'present': present,
      'late': late,
      'absent': absent,
      'total': present + late + absent,
    };
  }

  /* ----- mutations ----- */

  /// Clock In
  /// - Writes: dayId, status ('early'|'late'), inAt, inLoc
  /// - Requires: 08:00–16:00
  /// - Error if already in and not out.
  Future<void> clockIn({
    required String uid,
    required double lat,
    required double lng,
    String? lateReason, // provide if after 08:30
    DateTime? now,
  }) async {
    final ts = now ?? JmTime.nowLocal();
    if (!canClockInNow(ts)) {
      throw StateError('Clock-in allowed between 08:00 and 16:00.');
    }

    final ref = _AttendanceDocPaths.dayRef(uid: uid, when: ts);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();

      if (data != null && data['inAt'] != null && data['outAt'] == null) {
        throw StateError('Already clocked in.');
      }

      final status = statusFromClockIn(ts);
      final write = <String, dynamic>{
        'dayId': JmTime.dateId(ts),
        'status': status, // 'early'|'late'|'absent'|'in_progress'
        'inAt': Timestamp.fromDate(ts),
        'inLoc': {'lat': lat, 'lng': lng},
        'outAt': null,
        'outLoc': null,
        'lateReason': status == 'late' ? (lateReason ?? '') : null,
        'createdAt': data?['createdAt'] ?? Timestamp.fromDate(ts),
        'updatedAt': Timestamp.fromDate(ts),
      };

      if (snap.exists) {
        tx.update(ref, write);
      } else {
        tx.set(ref, write);
      }
    });
  }

  /// Clock Out
  /// - Requires an active inAt and no outAt.
  Future<void> clockOut({
    required String uid,
    required double lat,
    required double lng,
    DateTime? now,
  }) async {
    final ts = now ?? JmTime.nowLocal();
    final ref = _AttendanceDocPaths.dayRef(uid: uid, when: ts);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || data['inAt'] == null) {
        throw StateError('Not clocked in.');
      }
      if (data['outAt'] != null) {
        throw StateError('Already clocked out.');
      }

      tx.update(ref, {
        'outAt': Timestamp.fromDate(ts),
        'outLoc': {'lat': lat, 'lng': lng},
        'updatedAt': Timestamp.fromDate(ts),
      });
    });
  }

  /// Auto clock-out after 16:00 if still clocked in.
  Future<void> autoClockOutIfNeeded({
    required String uid,
    required double lat,
    required double lng,
    DateTime? now,
  }) async {
    final ts = now ?? JmTime.nowLocal();
    if (!shouldAutoClockOut(ts)) return;

    final ref = _AttendanceDocPaths.dayRef(uid: uid, when: ts);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data?['inAt'] != null && data?['outAt'] == null) {
        tx.update(ref, {
          'outAt': Timestamp.fromDate(ts),
          'outLoc': {'lat': lat, 'lng': lng},
          'updatedAt': Timestamp.fromDate(ts),
        });
      }
    });
  }

  /// If yesterday has no doc, mark it 'absent'.
  Future<void> markYesterdayAbsentIfMissing({
    required String uid,
    DateTime? now,
  }) async {
    final ts = now ?? JmTime.nowLocal();
    final y = DateUtils.dateOnly(ts).subtract(const Duration(days: 1));
    final ref = _AttendanceDocPaths.dayRef(uid: uid, when: y);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'dayId': JmTime.dateId(y),
        'status': 'absent',
        'inAt': null,
        'inLoc': null,
        'outAt': null,
        'outLoc': null,
        'lateReason': null,
        'createdAt': Timestamp.fromDate(ts),
        'updatedAt': Timestamp.fromDate(ts),
      });
    }
  }
}

Future<void> markMissedDaysAbsent(String userId) async {
  final firestore = FirebaseFirestore.instance;
  final attendanceRef = firestore
      .collection('attendance')
      .doc(userId)
      .collection('days');

  // Get all attendance dates (or just the latest one)
  final lastAttendanceSnapshot = await attendanceRef
      .orderBy('date', descending: true)
      .limit(1)
      .get();

  DateTime lastDate;

  if (lastAttendanceSnapshot.docs.isEmpty) {
    // If no attendance at all, start from a default (e.g., semester start date)
    lastDate = DateTime.now().subtract(
      Duration(days: 30),
    ); // Or use actual semester start
  } else {
    lastDate = DateTime.parse(lastAttendanceSnapshot.docs.first['date']);
  }

  // Go from lastDate + 1 to yesterday
  final now = DateTime.now();
  DateTime currentDate = lastDate.add(Duration(days: 1));
  final yesterday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: 1));

  while (currentDate.isBefore(yesterday) ||
      currentDate.isAtSameMomentAs(yesterday)) {
    // Only mark weekdays (Mon–Fri)
    if (currentDate.weekday >= 1 && currentDate.weekday <= 5) {
      final dateString = currentDate.toIso8601String().substring(
        0,
        10,
      ); // e.g., "2025-09-05"

      final docRef = attendanceRef.doc(dateString);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'date': dateString,
          'status': 'Absent',
          'clockInTime': null,
          'clockOutTime': null,
          'clockInLocation': null,
          'clockOutLocation': null,
          'lateReason': null,
        });
      }
    }

    currentDate = currentDate.add(Duration(days: 1));
  }
}
