import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import 'package:provider/provider.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _issue;
  String? _error;

  // ── Search Firestore by trackId ──────────────────────────────────
  Future<void> _track() async {
    final id = _controller.text.trim().toUpperCase();
    if (id.isEmpty) return;

    setState(() { _isLoading = true; _issue = null; _error = null; });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('issues')
          .where('trackId', isEqualTo: id)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        final lang = context.read<LanguageService>();
        setState(() {
          _isLoading = false;
          _error = "${lang.translate('no_issue_found')}$id${lang.translate('check_and_try')}";
        });
      } else {
        setState(() {
          _isLoading = false;
          _issue = snap.docs.first.data();
        });
      }
    } catch (e) {
      final lang = context.read<LanguageService>();
      setState(() {
        _isLoading = false;
        _error = lang.translate('error_generic');
      });
      print("Track error: $e");
    }
  }

  Color _statusColor(String s) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (s) {
      case 'resolved':    return colorScheme.tertiary; // Use tertiary for green success
      case 'in_progress': return Colors.orange;
      default:            return colorScheme.secondary;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'resolved':    return Icons.check_circle_rounded;
      case 'in_progress': return Icons.timelapse_rounded;
      default:            return Icons.pending_rounded;
    }
  }

  String _statusLabel(String s) {
    final lang = context.read<LanguageService>();
    switch (s) {
      case 'resolved':    return lang.translate('resolved');
      case 'in_progress': return lang.translate('in_progress');
      default:            return lang.translate('open');
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '-';
    try {
      final dt = ts is Timestamp
          ? ts.toDate().toLocal()
          : DateTime.parse(ts.toString()).toLocal();
      return "${dt.day}/${dt.month}/${dt.year}  "
          "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
    } catch (_) { return '-'; }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return Scaffold(
      backgroundColor:Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(lang.translate('track_complaint')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(
                color: const Color(0xFFF97316).withOpacity(0.3),
                blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.manage_search_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(width: 18),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.translate('track_complaint'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(lang.translate('track_subtitle'),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 32),

          // ── Search ───────────────────────────────────────────────
          Text(lang.translate('track_id'),
              style: TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 14, color: Theme.of(context).colorScheme.onBackground)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _track(),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: lang.translate('track_id_hint'),
                    hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.outline, fontSize: 13),
                    prefixIcon: Icon(Icons.tag,
                        color: Theme.of(context).colorScheme.primary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary, width: 2)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: _isLoading ? null : _track,
                child: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.search_rounded, size: 24),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // ── Error ────────────────────────────────────────────────
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                Icon(Icons.error_outline,
                    color: Colors.red.shade400, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!,
                    style: TextStyle(
                        color: Colors.red.shade700, fontSize: 13))),
              ]),
            ),

          // ── Result ───────────────────────────────────────────────
          if (_issue != null) ...[
            Text(lang.translate('complaint_details'),
                style: const TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 15, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 12),

            // Main card
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                // Image
                if (_issue!['imageUrl'] != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18)),
                    child: Image.network(
                      _issue!['imageUrl'],
                      height: 160, width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                    // Status row
                    Row(children: [
                      Icon(
                        _statusIcon(_issue!['status'] ?? 'open'),
                        color: _statusColor(_issue!['status'] ?? 'open'),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: _statusColor(_issue!['status'] ?? 'open')
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(_issue!['status'] ?? 'open'),
                          style: TextStyle(
                              color: _statusColor(
                                  _issue!['status'] ?? 'open'),
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                      ),
                    ]),

                    const Divider(height: 20),

                    Text(_issue!['title'] ?? '-',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Text(lang.translate(_issue!['category'] ?? 'cat_other'),
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                    const SizedBox(height: 12),
                    Text(_issue!['description'] ?? '-',
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13, height: 1.5)),

                    const Divider(height: 20),

                    _infoRow(Icons.tag, lang.translate('track_id'),
                        _issue!['trackId'] ?? '-'),
                    _infoRow(Icons.location_city_outlined, lang.translate('ward'),
                        "${lang.translate('ward')} ${_issue!['wardNo'] ?? '-'}"),
                    _infoRow(Icons.person_outline, lang.translate('reported_by'),
                        _issue!['userName'] ?? '-'),
                    _infoRow(Icons.calendar_today_outlined, lang.translate('filed_on'),
                        _formatDate(_issue!['createdAt'])),
                    if (_issue!['latitude'] != null)
                      _infoRow(Icons.location_on_outlined, lang.translate('gps'),
                          "Lat: ${(_issue!['latitude'] as num).toStringAsFixed(4)}, "
                          "Lng: ${(_issue!['longitude'] as num).toStringAsFixed(4)}"),

                    const Divider(height: 20),

                    // Timeline
                    Text(lang.translate('status_timeline'),
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 14),
                    _timelineStep(
                        Icons.send_rounded, lang.translate('submitted'),
                        _formatDate(_issue!['createdAt']),
                        Colors.blue, true, false),
                    _timelineStep(
                        Icons.timelapse_rounded, lang.translate('in_progress'),
                        lang.translate('bmc_team_assigned'),
                        Colors.orange,
                        _issue!['status'] == 'in_progress' ||
                            _issue!['status'] == 'resolved',
                        false),
                    _timelineStep(
                        Icons.check_circle_rounded, lang.translate('resolved'),
                        _issue!['status'] == 'resolved'
                            ? _formatDate(_issue!['updatedAt'])
                            : lang.translate('pending_resolution'),
                        Colors.green,
                        _issue!['status'] == 'resolved',
                        true),
                  ]),
                ),
              ]),
            ),
          ],

          // ── Empty state hint ─────────────────────────────────────
          if (_issue == null && _error == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(children: [
                  Icon(Icons.search_rounded,
                      size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(lang.translate('enter_track_id_above'),
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(lang.translate('track_id_hint'),
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 12,
                          fontFamily: 'monospace')),
                ]),
              ),
            ),

          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        SizedBox(width: 80,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.outline))),
        Expanded(child: Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface))),
      ]),
    );
  }

  Widget _timelineStep(IconData icon, String label, String sub,
      Color color, bool done, bool isLast) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: done ? color.withOpacity(0.12) : Colors.grey.shade100,
            shape: BoxShape.circle,
            border: Border.all(
                color: done ? color : Colors.grey.shade300, width: 2),
          ),
          child: Icon(icon,
              color: done ? color : Colors.grey.shade400, size: 16),
        ),
        if (!isLast)
          Container(width: 2, height: 34,
              color: done ? color.withOpacity(0.3) : Colors.grey.shade200),
      ]),
      const SizedBox(width: 12),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13,
                  color: done
                      ? const Color(0xFF1A1A2E)
                      : Colors.grey.shade400)),
          Text(sub,
              style: TextStyle(fontSize: 11,
                  color: done
                      ? Colors.grey.shade500
                      : Colors.grey.shade300)),
        ]),
      ),
    ]);
  }
}