import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/attendance_service.dart';

class AdminService {
  AdminService._();
  static final instance = AdminService._();

  final _db = FirebaseFirestore.instance;

  // Helper function to check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return false;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    return userData?['role'] == 'admin';
  }

  // REPORTS MANAGEMENT

  // Get all reports for admin review
  Stream<QuerySnapshot<Map<String, dynamic>>> getAllReports() {
    return _db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get reports by status (pending, reviewed, resolved)
  Stream<QuerySnapshot<Map<String, dynamic>>> getReportsByStatus(
    String status,
  ) {
    return _db
        .collection('reports')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Update report status
  Future<void> updateReportStatus(
    String reportId,
    String status, {
    String? adminNotes,
  }) async {
    final data = <String, dynamic>{
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': AuthService.instance.currentUser!.uid,
    };

    if (adminNotes != null) {
      data['adminNotes'] = adminNotes;
    }

    await _db.collection('reports').doc(reportId).update(data);

    // Log admin action
    await _logAdminAction('report_status_update', {
      'reportId': reportId,
      'newStatus': status,
      'adminNotes': adminNotes,
    });
  }

  // USER MANAGEMENT

  // Get all users for admin management
  Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers() {
    return _db.collection('users').orderBy('lastName').snapshots();
  }

  // Suspend a user
  Future<void> suspendUser(
    String userId, {
    String? reason,
    DateTime? until,
  }) async {
    final data = <String, dynamic>{
      'status': 'suspended',
      'suspendedAt': FieldValue.serverTimestamp(),
      'suspendedBy': AuthService.instance.currentUser!.uid,
      'suspensionReason': reason,
    };

    if (until != null) {
      data['suspendedUntil'] = Timestamp.fromDate(until);
    }

    await _db.collection('users').doc(userId).update(data);

    // Log admin action
    await _logAdminAction('user_suspend', {
      'userId': userId,
      'reason': reason,
      'until': until?.toIso8601String(),
    });
  }

  // Unsuspend a user
  Future<void> unsuspendUser(String userId) async {
    await _db.collection('users').doc(userId).update({
      'status': 'active',
      'suspendedAt': FieldValue.delete(),
      'suspendedBy': FieldValue.delete(),
      'suspensionReason': FieldValue.delete(),
      'suspendedUntil': FieldValue.delete(),
    });

    // Log admin action
    await _logAdminAction('user_unsuspend', {'userId': userId});
  }

  // Flag a user (warning level)
  Future<void> flagUser(String userId, String reason) async {
    await _db.collection('users').doc(userId).update({
      'flagged': true,
      'flaggedAt': FieldValue.serverTimestamp(),
      'flaggedBy': AuthService.instance.currentUser!.uid,
      'flagReason': reason,
    });

    // Log admin action
    await _logAdminAction('user_flag', {'userId': userId, 'reason': reason});
  }

  // Unflag a user
  Future<void> unflagUser(String userId) async {
    await _db.collection('users').doc(userId).update({
      'flagged': FieldValue.delete(),
      'flaggedAt': FieldValue.delete(),
      'flaggedBy': FieldValue.delete(),
      'flagReason': FieldValue.delete(),
    });

    // Log admin action
    await _logAdminAction('user_unflag', {'userId': userId});
  }

  // Delete a user permanently
  Future<void> deleteUser(String userId) async {
    final batch = _db.batch();

    try {
      // 1. Delete user's notes
      final userNotesQuery = await _db
          .collection('users')
          .doc(userId)
          .collection('notes')
          .get();

      for (final noteDoc in userNotesQuery.docs) {
        batch.delete(noteDoc.reference);
      }

      // 2. Delete user's notifications
      final userNotificationsQuery = await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      for (final notificationDoc in userNotificationsQuery.docs) {
        batch.delete(notificationDoc.reference);
      }

      // 3. Delete user from public notes if any
      final publicNotesQuery = await _db
          .collection('public_notes')
          .where('userId', isEqualTo: userId)
          .get();

      for (final noteDoc in publicNotesQuery.docs) {
        batch.delete(noteDoc.reference);
      }

      // 4. Delete reports made by the user
      final reportsQuery = await _db
          .collection('reports')
          .where('reporterId', isEqualTo: userId)
          .get();

      for (final reportDoc in reportsQuery.docs) {
        batch.delete(reportDoc.reference);
      }

      // 5. Delete reports about the user
      final reportsAboutUserQuery = await _db
          .collection('reports')
          .where('targetUserId', isEqualTo: userId)
          .get();

      for (final reportDoc in reportsAboutUserQuery.docs) {
        batch.delete(reportDoc.reference);
      }

      // 6. Finally, delete the user document
      final userDocRef = _db.collection('users').doc(userId);
      batch.delete(userDocRef);

      // Commit the batch
      await batch.commit();

      // Log admin action
      await _logAdminAction('user_delete', {
        'userId': userId,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // NOTE MODERATION

  // Get all notes for moderation
  Stream<QuerySnapshot<Map<String, dynamic>>> getAllNotesForModeration() {
    return _db
        .collectionGroup('notes')
        .orderBy('aud_dt', descending: true)
        .snapshots();
  }

  // Get flagged notes
  Stream<QuerySnapshot<Map<String, dynamic>>> getFlaggedNotes() {
    return _db
        .collectionGroup('notes')
        .where('flagged', isEqualTo: true)
        .orderBy('aud_dt', descending: true)
        .snapshots();
  }

  // Flag a note
  Future<void> flagNote(String userId, String noteId, String reason) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notes')
        .doc(noteId)
        .update({
          'flagged': true,
          'flaggedAt': FieldValue.serverTimestamp(),
          'flaggedBy': AuthService.instance.currentUser!.uid,
          'flagReason': reason,
        });

    // Log admin action
    await _logAdminAction('note_flag', {
      'userId': userId,
      'noteId': noteId,
      'reason': reason,
    });
  }

  // Suspend a note (hide from public view)
  Future<void> suspendNote(String userId, String noteId, String reason) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notes')
        .doc(noteId)
        .update({
          'suspended': true,
          'suspendedAt': FieldValue.serverTimestamp(),
          'suspendedBy': AuthService.instance.currentUser!.uid,
          'suspensionReason': reason,
          'visibility': 'private', // Force to private when suspended
        });

    // Log admin action
    await _logAdminAction('note_suspend', {
      'userId': userId,
      'noteId': noteId,
      'reason': reason,
    });
  }

  // Delete a note
  Future<void> deleteNote(String userId, String noteId, String reason) async {
    // Log admin action before deletion
    await _logAdminAction('note_delete', {
      'userId': userId,
      'noteId': noteId,
      'reason': reason,
    });

    await _db
        .collection('users')
        .doc(userId)
        .collection('notes')
        .doc(noteId)
        .delete();
  }

  // Restore a suspended note
  Future<void> restoreNote(String userId, String noteId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notes')
        .doc(noteId)
        .update({
          'suspended': FieldValue.delete(),
          'suspendedAt': FieldValue.delete(),
          'suspendedBy': FieldValue.delete(),
          'suspensionReason': FieldValue.delete(),
          'flagged': FieldValue.delete(),
          'flaggedAt': FieldValue.delete(),
          'flaggedBy': FieldValue.delete(),
          'flagReason': FieldValue.delete(),
        });

    // Log admin action
    await _logAdminAction('note_restore', {'userId': userId, 'noteId': noteId});
  }

  // ADMIN ACTIONS LOGGING

  Future<void> _logAdminAction(
    String actionType,
    Map<String, dynamic> details,
  ) async {
    await _db.collection('adminActions').add({
      'actionType': actionType,
      'adminId': AuthService.instance.currentUser!.uid,
      'adminEmail': AuthService.instance.currentUser!.email,
      'timestamp': FieldValue.serverTimestamp(),
      'details': details,
    });
  }

  // Get admin action logs
  Stream<QuerySnapshot<Map<String, dynamic>>> getAdminActionLogs() {
    return _db
        .collection('adminActions')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get admin action logs by action type
  Stream<QuerySnapshot<Map<String, dynamic>>> getAdminActionLogsByType(
    String actionType,
  ) {
    return _db
        .collection('adminActions')
        .where('actionType', isEqualTo: actionType)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // REPORTING SYSTEM

  // Create a report
  Future<void> createReport({
    required String reportType, // 'note', 'user', 'behavior'
    required String targetId, // noteId or userId
    required String targetUserId, // owner of the reported content/user
    required String reason,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    await _db.collection('reports').add({
      'reportType': reportType,
      'targetId': targetId,
      'targetUserId': targetUserId,
      'reporterId': AuthService.instance.currentUser!.uid,
      'reporterEmail': AuthService.instance.currentUser!.email,
      'reason': reason,
      'description': description,
      'metadata': metadata ?? {},
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get reports for a specific user
  Stream<QuerySnapshot<Map<String, dynamic>>> getReportsForUser(String userId) {
    return _db
        .collection('reports')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get reports by a specific reporter
  Stream<QuerySnapshot<Map<String, dynamic>>> getReportsByReporter(
    String reporterId,
  ) {
    return _db
        .collection('reports')
        .where('reporterId', isEqualTo: reporterId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ATTENDANCE MANAGEMENT

  /// Get attendance overview for all students on a specific date
  Stream<QuerySnapshot<Map<String, dynamic>>> getAttendanceForDate(
    DateTime date,
  ) {
    return AttendanceService.streamAllUsersAttendanceForDate(date);
  }

  /// Get attendance for a specific user over a date range
  Stream<QuerySnapshot<Map<String, dynamic>>> getUserAttendanceRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return AttendanceService.streamUserAttendanceRange(
      userId,
      startDate,
      endDate,
    );
  }

  /// Get current week attendance overview
  Stream<QuerySnapshot<Map<String, dynamic>>> getCurrentWeekAttendance() {
    return AttendanceService.streamCurrentWeekAttendance();
  }

  /// Get attendance summary statistics for a user
  Future<Map<String, int>> getUserAttendanceSummary(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return AttendanceService.getAttendanceSummary(
      userId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get attendance summary for all users in a course group
  Future<Map<String, Map<String, int>>> getCourseAttendanceSummary(
    String courseGroup, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Get all users in the course group
    final usersSnapshot = await _db
        .collection('users')
        .where('courseGroup', isEqualTo: courseGroup)
        .where('role', isEqualTo: 'student')
        .get();

    final summaries = <String, Map<String, int>>{};

    for (final userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      final summary = await AttendanceService.getAttendanceSummary(
        userId,
        startDate: startDate,
        endDate: endDate,
      );
      summaries[userId] = summary;
    }

    return summaries;
  }

  /// Get students who are frequently absent (configurable threshold)
  Future<List<Map<String, dynamic>>> getFrequentAbsentees({
    int absentThreshold = 3, // days absent in the period
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    // Get all students
    final studentsSnapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'student')
        .get();

    final absentees = <Map<String, dynamic>>[];

    for (final studentDoc in studentsSnapshot.docs) {
      final userId = studentDoc.id;
      final userData = studentDoc.data();

      final summary = await AttendanceService.getAttendanceSummary(
        userId,
        startDate: start,
        endDate: end,
      );

      if (summary['absent']! >= absentThreshold) {
        absentees.add({
          'userId': userId,
          'name': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
              .trim(),
          'email': userData['email'] ?? '',
          'courseGroup': userData['courseGroup'] ?? '',
          'attendanceSummary': summary,
        });
      }
    }

    // Sort by absence count (highest first)
    absentees.sort(
      (a, b) => (b['attendanceSummary']['absent'] as int).compareTo(
        a['attendanceSummary']['absent'] as int,
      ),
    );

    return absentees;
  }

  /// Mark a student absent for a specific date (admin override)
  Future<void> markStudentAbsent(
    String userId,
    DateTime date, {
    String? reason,
  }) async {
    final dateId = JmTime.dateId(date);
    final docRef = _db
        .collection('attendance')
        .doc(userId)
        .collection('days')
        .doc(dateId);

    await docRef.set({
      'dayId': dateId,
      'status': 'absent',
      'inAt': null,
      'inLoc': null,
      'outAt': null,
      'outLoc': null,
      'lateReason': reason,
      'adminOverride': true,
      'overrideBy': AuthService.instance.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update attendance status (admin correction)
  Future<void> updateAttendanceStatus(
    String userId,
    DateTime date,
    String status, {
    String? reason,
  }) async {
    final dateId = JmTime.dateId(date);
    final docRef = _db
        .collection('attendance')
        .doc(userId)
        .collection('days')
        .doc(dateId);

    await docRef.update({
      'status': status,
      'lateReason': reason,
      'adminOverride': true,
      'overrideBy': AuthService.instance.currentUser!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
