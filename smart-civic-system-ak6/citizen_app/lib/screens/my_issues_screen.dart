import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import 'package:provider/provider.dart';

// ═══════════════════════════════════════════════════════════
//  MY ISSUES SCREEN
// ═══════════════════════════════════════════════════════════
class MyIssuesScreen extends StatefulWidget {
  const MyIssuesScreen({super.key});
  @override
  State<MyIssuesScreen> createState() => _MyIssuesScreenState();
}

class _MyIssuesScreenState extends State<MyIssuesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Firestore stream — no orderBy so no composite index needed ────
  Stream<QuerySnapshot> _stream(String? status) {
    Query q = FirebaseFirestore.instance
        .collection('issues')
        .where('userId', isEqualTo: _uid);
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.snapshots();
  }

  // ── Helpers ───────────────────────────────────────────────────────
  Color _statusColor(String s) {
    switch (s) {
      case 'resolved':    return const Color(0xFF10B981); // Emerald
      case 'in_progress': return const Color(0xFFF59E0B); // Amber
      case 'rejected':    return const Color(0xFFEF4444); // Red
      default:            return const Color(0xFFF97316); // Orange (Primary)
    }
  }

  String _statusLabel(String s) {
    final lang = context.read<LanguageService>();
    switch (s.toLowerCase()) {
      case 'resolved':    return lang.translate('resolved').toUpperCase();
      case 'in_progress': return lang.translate('in_progress').toUpperCase();
      case 'rejected':    return lang.translate('rejected').toUpperCase();
      default:            return lang.translate('open').toUpperCase();
    }
  }

  IconData _catIcon(String c) {
    switch (c) {
      case 'cat_road':
      case 'Road Damage':    return Icons.construction_rounded;
      case 'cat_light':
      case 'Street Light':   return Icons.lightbulb_outline_rounded;
      case 'cat_garbage':
      case 'Garbage':        return Icons.delete_outline_rounded;
      case 'cat_water':
      case 'Water Leakage':  return Icons.water_drop_outlined;
      case 'cat_traffic':
      case 'Traffic Signal': return Icons.traffic_rounded;
      case 'cat_encroach':
      case 'Encroachment':   return Icons.warning_amber_rounded;
      case 'cat_tree':
      case 'Tree Fallen':    return Icons.park_outlined;
      default:               return Icons.report_problem_outlined;
    }
  }

  Color _catColor(String c) {
    switch (c) {
      case 'cat_road':
      case 'Road Damage':    return const Color(0xFFE65100);
      case 'cat_light':
      case 'Street Light':   return const Color(0xFFFFB300);
      case 'cat_garbage':
      case 'Garbage':        return const Color(0xFF2E7D32);
      case 'cat_water':
      case 'Water Leakage':  return const Color(0xFF1565C0);
      case 'cat_traffic':
      case 'Traffic Signal': return const Color(0xFF6A1B9A);
      case 'cat_encroach':
      case 'Encroachment':   return const Color(0xFFC62828);
      case 'cat_tree':
      case 'Tree Fallen':    return const Color(0xFF00695C);
      default:               return const Color(0xFF455A64);
    }
  }

  String _formatDate(dynamic ts, {bool includeTime = false}) {
    if (ts == null) return '—';
    try {
      final dt = ts is Timestamp
          ? ts.toDate().toLocal()
          : DateTime.parse(ts.toString()).toLocal();
      final date = '${dt.day}/${dt.month}/${dt.year}';
      if (!includeTime) return date;
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$date  $hh:$mm';
    } catch (_) {
      return '—';
    }
  }

  // ── Issue card ────────────────────────────────────────────────────
  Widget _card(Map<String, dynamic> d, String docId) {
    final lang     = context.watch<LanguageService>();
    final status   = (d['status']   as String?) ?? 'open';
    final category = (d['category'] as String?) ?? 'cat_other';
    final catColor = _catColor(category);
    final stColor  = _statusColor(status);

    return GestureDetector(
      onTap: () {
        // Haptic removed
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IssueDetailScreen(data: d, docId: docId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top accent stripe
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: catColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18)),
              ),
            ),

            // Optional image
            if ((d['imageUrl'] as String?)?.isNotEmpty == true)
              ClipRRect(
                child: Image.network(
                  d['imageUrl'] as String,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 130,
                      color: Colors.grey.shade100,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_catIcon(category),
                            color: catColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (d['title'] as String?) ?? lang.translate('no_title'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              lang.translate(category),
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status badge
                      _statusBadge(status, stColor),
                    ],
                  ),

                  // Description
                  if ((d['description'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text(
                      d['description'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Footer row
                  Row(
                    children: [
                      Icon(Icons.tag_rounded,
                          size: 13, color: catColor),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          (d['trackId'] as String?) ?? '—',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: catColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.location_city_outlined,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(
                        '${lang.translate('ward')} ${(d['wardNo'] ?? '—')}',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.calendar_today_outlined,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(
                        _formatDate(d['createdAt']),
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status badge widget ───────────────────────────────────────────
  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab content ───────────────────────────────────────────────────
  Widget _tabView(String? statusFilter) {
    final lang = context.watch<LanguageService>();
    if (_uid == null) {
      return Center(
        child: Text(
          lang.translate('login_again'),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _stream(statusFilter),
      builder: (ctx, snap) {
        // Loading
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
              strokeWidth: 2.5,
            ),
          );
        }

        // Error — show proper message with guidance
        if (snap.hasError) {
          final err = snap.error.toString();
          final isIndexError =
              err.contains('index') || err.contains('FAILED_PRECONDITION');
          final isPermissionError = err.contains('permission-denied') || err.contains('permission');

          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isIndexError
                          ? Icons.cloud_off_rounded
                          : isPermissionError
                              ? Icons.lock_person_rounded
                              : Icons.error_outline_rounded,
                      size: 34,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isIndexError
                        ? 'Firestore Index Required'
                        : isPermissionError
                            ? 'Permission Denied'
                            : lang.translate('error_generic'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isIndexError
                        ? 'A Firestore composite index is needed.\n'
                          'Check the debug console for the direct link to create it.'
                        : isPermissionError
                            ? 'Your Firestore security rules are blocking this request. '
                              'Please ensure rules allow reading from "issues" collection.'
                            : err,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(lang.translate('retry'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        }

        // Sort client-side — descending by createdAt
        final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? [])
          ..sort((a, b) {
            final at = (a.data() as Map<String, dynamic>)['createdAt']
                as Timestamp?;
            final bt = (b.data() as Map<String, dynamic>)['createdAt']
                as Timestamp?;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });

        // Empty state
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 72, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  statusFilter == null
                      ? lang.translate('no_complaints')
                      : '${lang.translate('no_status_issues').replaceAll('{status}', _statusLabel(statusFilter ?? 'open'))}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lang.translate('report_hint'),
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 13),
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 13),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/report'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(lang.translate('report_issue'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        }

        // List
        return RefreshIndicator(
          color: const Color(0xFFE65100),
          onRefresh: () async {
            // StreamBuilder auto-refreshes; pull-to-refresh is visual only
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return _card(d, docs[i].id);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          lang.translate('my_complaints'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(icon: const Icon(Icons.list_alt_rounded, size: 18), text: lang.translate('all')),
            Tab(icon: const Icon(Icons.pending_outlined, size: 18), text: lang.translate('open')),
            Tab(
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                text: lang.translate('resolved')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _tabView(null),
          _tabView('open'),
          _tabView('resolved'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: () {
          // Haptic removed
          Navigator.pushNamed(context, '/report');
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(lang.translate('report_issue'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ISSUE DETAIL SCREEN
// ═══════════════════════════════════════════════════════════
class IssueDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const IssueDetailScreen({
    super.key,
    required this.data,
    required this.docId,
  });

  Color _statusColor(BuildContext context, String s) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (s) {
      case 'resolved':    return colorScheme.tertiary;
      case 'in_progress': return Colors.orange;
      case 'rejected':    return colorScheme.error;
      default:            return colorScheme.secondary;
    }
  }

   String _statusLabel(BuildContext context, String s) {
    final lang = context.read<LanguageService>();
    switch (s.toLowerCase()) {
      case 'resolved':    return lang.translate('resolved');
      case 'in_progress': return lang.translate('in_progress');
      case 'rejected':    return lang.translate('rejected');
      default:            return lang.translate('open');
    }
  }

  String _formatDate(dynamic ts, {bool includeTime = false}) {
    if (ts == null) return '—';
    try {
      final dt = ts is Timestamp
          ? ts.toDate().toLocal()
          : DateTime.parse(ts.toString()).toLocal();
      final date = '${dt.day}/${dt.month}/${dt.year}';
      if (!includeTime) return date;
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$date  $hh:$mm';
    } catch (_) {
      return '—';
    }
  }

  // ── Detail row ────────────────────────────────────────────────────
  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Timeline step ──────────────────────────────────────────────────
   Widget _step(
    BuildContext context,
    IconData icon,
    String label,
    String sub,
    Color color,
    bool done,
    bool isLast,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    done ? color.withOpacity(0.12) : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? color : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Icon(
                done ? Icons.check_rounded : icon,
                color: done ? color : Colors.grey.shade400,
                size: 18,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: done
                        ? [color.withOpacity(0.4), color.withOpacity(0.1)]
                        : [Colors.grey.shade200, Colors.grey.shade100],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(top: 8, bottom: isLast ? 0 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: done
                        ? const Color(0xFF0F172A)
                        : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    color: done
                        ? Colors.grey.shade500
                        : Colors.grey.shade300,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── White card container ──────────────────────────────────────────
  Widget _infoCard(BuildContext context, {String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF0F172A),
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final status     = (data['status']   as String?) ?? 'open';
    final category   = (data['category'] as String?) ?? 'cat_other';
    final stColor    = _statusColor(context, status);
    final isAssigned = status == 'in_progress' || status == 'resolved';
    final isResolved = status == 'resolved';
    final isRejected = status == 'rejected';

    // Priority display
    final priority   = (data['priority'] as String?);
    final prioColors = {
      'urgent': const Color(0xFFDC2626),
      'high':   const Color(0xFFEA580C),
      'normal': const Color(0xFF16A34A),
    };
    final prioColor = priority != null
        ? (prioColors[priority] ?? Colors.grey)
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar with image ────────────────────────────
          SliverAppBar(
            expandedHeight:
                (data['imageUrl'] as String?)?.isNotEmpty == true ? 250 : 120,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            title: const Text(
              'Issue Details',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: (data['imageUrl'] as String?)?.isNotEmpty == true
                  ? Image.network(
                      data['imageUrl'] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFBF360C),
                              Color(0xFFFF8F00),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFBF360C),
                            Color(0xFFFF8F00),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white38,
                          size: 44,
                        ),
                      ),
                    ),
            ),
          ),

          // ── Content ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Title card
                  _infoCard(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                (data['title'] as String?) ?? 'No Title',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: stColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: stColor.withOpacity(0.30)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: stColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _statusLabel(context, status),
                                    style: TextStyle(
                                      color: stColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),
                        Text(
                          category,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13),
                        ),

                        // Priority badge
                        if (priority != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: prioColor!.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: prioColor.withOpacity(0.25)),
                            ),
                            child: Text(
                              '${priority[0].toUpperCase()}${priority.substring(1)} Priority',
                              style: TextStyle(
                                color: prioColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Track ID chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFFFB300)
                                    .withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tag_rounded,
                                  color: Theme.of(context).colorScheme.primary, size: 17),
                              const SizedBox(width: 7),
                              Text(
                                (data['trackId'] as String?) ?? '—',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 15,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Info card
                  _infoCard(
                    context,
                    title: 'Complaint Details',
                    child: Column(
                      children: [
                        if ((data['description'] as String?)?.isNotEmpty == true)
                          _row(context, Icons.description_outlined, 'Description',
                              data['description'] as String),
                        _row(
                          context,
                          Icons.location_city_outlined,
                          'Ward',
                          'Ward ${data['wardNo'] ?? '—'}',
                        ),
                        if (data['latitude'] != null)
                          _row(
                            context,
                            Icons.location_on_outlined,
                            'GPS Location',
                            'Lat: ${(data['latitude'] as num).toStringAsFixed(5)}'
                            '\nLng: ${(data['longitude'] as num).toStringAsFixed(5)}',
                          ),
                        if ((data['assignedTo'] as String?)?.isNotEmpty ==
                            true)
                          _row(
                            context,
                            Icons.business_outlined,
                            'Assigned To',
                            data['assignedTo'] as String,
                          ),
                        _row(
                          context,
                          Icons.person_outline_rounded,
                          'Reported By',
                          (data['userName'] as String?) ?? '—',
                        ),
                        _row(
                          context,
                          Icons.calendar_today_outlined,
                          'Filed On',
                          _formatDate(data['createdAt'],
                              includeTime: true),
                        ),
                        if (isResolved || isRejected)
                          _row(
                            context,
                            Icons.update_rounded,
                            isResolved ? 'Resolved On' : 'Closed On',
                            _formatDate(data['updatedAt'],
                                includeTime: true),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Timeline card
                  _infoCard(
                    context,
                    title: 'Status Timeline',
                    child: Column(
                      children: [
                        _step(
                          context,
                          Icons.send_rounded,
                          lang.translate('submitted'),
                          _formatDate(data['createdAt'],
                              includeTime: true),
                          const Color(0xFF2563EB),
                          true,
                          false,
                        ),
                        _step(
                          context,
                          Icons.engineering_outlined,
                          lang.translate('in_progress'),
                          isAssigned
                              ? (data['assignedTo'] != null
                                  ? 'Assigned to ${data['assignedTo']}'
                                  : 'BMC team is working on this')
                              : 'Awaiting assignment',
                          const Color(0xFFEA580C),
                          isAssigned,
                          false,
                        ),
                        _step(
                          context,
                          isRejected
                              ? Icons.cancel_outlined
                              : Icons.check_circle_outline_rounded,
                          isRejected ? lang.translate('rejected') : lang.translate('resolved'),
                          isResolved
                              ? _formatDate(data['updatedAt'],
                                  includeTime: true)
                              : isRejected
                                  ? 'This complaint was rejected by BMC'
                                  : lang.translate('pending_resolution'),
                          isRejected
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF16A34A),
                          isResolved || isRejected,
                          true,
                        ),
                      ],
                    ),
                  ),

                  // Admin notes (if any)
                  if ((data['comments'] as List?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    _infoCard(
                      context,
                      title: 'Admin Notes',
                      child: Column(
                        children: [
                          for (final c
                              in data['comments'] as List<dynamic>)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFE8ECF4)),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (c as Map<String, dynamic>)['text']
                                            as String? ??
                                        '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Admin · ${c['time'] != null ? _formatDate(c['time']) : ''}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}