import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _hotspots = [];
  bool _isLoading = true;
  String _selectedFilter = "All";

  // Mumbai center
  static const LatLng _mumbaiCenter = LatLng(19.0760, 72.8777);

  final List<String> _filters = [
    "All", "Road Damage", "Street Light", "Garbage",
    "Water Leakage", "Traffic Signal", "Other Issue",
  ];

  @override
  void initState() {
    super.initState();
    _loadHotspots();
  }

  // ── Load & group issues from Firestore by lat/lng cluster ────────
  Future<void> _loadHotspots() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('issues')
          .get();

      // Group by rounded lat/lng (0.005 degree ≈ 500m radius cluster)
      final Map<String, Map<String, dynamic>> clusters = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // Robust coordinate parsing (handles Num, double, or String)
        double? lat;
        double? lng;
        
        try {
          if (data['latitude'] != null) {
            lat = double.tryParse(data['latitude'].toString());
          }
          if (data['longitude'] != null) {
            lng = double.tryParse(data['longitude'].toString());
          }
        } catch (_) {}

        final category = data['category'] as String? ?? 'Other Issue';
        final status   = data['status']   as String? ?? 'open';
        final ward     = data['wardNo']   as String? ?? '-';

        if (lat == null || lng == null) continue;

        // Round to cluster key
        final clat = (lat / 0.005).round() * 0.005;
        final clng = (lng / 0.005).round() * 0.005;
        final key  = '${clat}_${clng}_$category';

        if (!clusters.containsKey(key)) {
          clusters[key] = {
            'latitude':  clat,
            'longitude': clng,
            'category':  category,
            'ward':      ward,
            'total':     0,
            'open':      0,
            'resolved':  0,
          };
        }
        clusters[key]!['total'] = (clusters[key]!['total'] as int) + 1;
        if (status == 'resolved') {
          clusters[key]!['resolved'] = (clusters[key]!['resolved'] as int) + 1;
        } else {
          clusters[key]!['open'] = (clusters[key]!['open'] as int) + 1;
        }
      }

      setState(() {
        _hotspots = clusters.values.toList()
          ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
        _isLoading = false;
      });
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('permission')) {
        _snack('Permission Denied: Update your Firestore rules.', err:true);
      } else {
        debugPrint("Map load error: $e");
      }
      setState(() => _isLoading = false);
    }
  }

  void _snack(String m, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: err ? Colors.red : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Color logic based on open issue count ────────────────────────
  // 10+  resolved → green
  // 1+   open     → green
  // 3+   open     → yellow
  // 5+   open     → orange
  // 10+  open     → red
  Color _circleColor(Map<String, dynamic> h) {
    final open     = h['open']     as int;
    final resolved = h['resolved'] as int;

    if (open == 0 && resolved >= 1) return const Color(0xFF10B981); // Emerald
    if (open >= 10) return const Color(0xFFEF4444); // Red
    if (open >= 5)  return const Color(0xFFF97316); // Orange
    if (open >= 3)  return const Color(0xFFF59E0B); // Amber
    return const Color(0xFF10B981);
  }

  double _circleRadius(Map<String, dynamic> h) {
    final open = h['open'] as int;
    if (open >= 10) return 600;
    if (open >= 5)  return 450;
    if (open >= 3)  return 320;
    return 200;
  }

  List<Map<String, dynamic>> get _filteredHotspots {
    if (_selectedFilter == "All") return _hotspots;
    return _hotspots
        .where((h) => h['category'] == _selectedFilter)
        .toList();
  }

  // ── Category icon ─────────────────────────────────────────────────
  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Road Damage':    return Icons.construction_rounded;
      case 'Street Light':   return Icons.lightbulb_outline;
      case 'Garbage':        return Icons.delete_outline_rounded;
      case 'Water Leakage':  return Icons.water_drop_outlined;
      case 'Traffic Signal': return Icons.traffic_rounded;
      case 'Tree Fallen':    return Icons.park_outlined;
      default:               return Icons.report_problem_outlined;
    }
  }

  void _showHotspotDetail(Map<String, dynamic> h) {
    final open     = h['open']     as int;
    final resolved = h['resolved'] as int;
    final total    = h['total']    as int;
    final color    = _circleColor(h);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),

            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_categoryIcon(h['category']),
                    color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h['category'],
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface)),
                  Text("Ward ${h['ward']}",
                      style: TextStyle(
                          fontSize: 13, color: Theme.of(context).colorScheme.outline)),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("$total total",
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 20),

            // Stats row
            Row(children: [
              _detailStat("$open", "Open Issues",   Colors.red),
              _detailStat("$resolved", "Resolved",  Colors.green),
              _detailStat(
                total > 0
                    ? "${((resolved / total) * 100).toStringAsFixed(0)}%"
                    : "0%",
                "Resolution",
                Colors.blue,
              ),
            ]),
            const SizedBox(height: 16),

            // Status bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total > 0 ? resolved / total : 0,
                minHeight: 10,
                backgroundColor: Colors.red.shade100,
                valueColor: AlwaysStoppedAnimation(Colors.green.shade400),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Open: $open",
                    style: TextStyle(
                        fontSize: 11, color: Colors.red.shade400)),
                Text("Resolved: $resolved",
                    style: TextStyle(
                        fontSize: 11, color: Colors.green.shade600)),
              ],
            ),
            const SizedBox(height: 20),

            // Coordinates
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: Color(0xFFF97316)),
                  const SizedBox(width: 6),
                  Text(
                    "Lat: ${(h['latitude'] as double).toStringAsFixed(4)}, "
                    "Lng: ${(h['longitude'] as double).toStringAsFixed(4)}",
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Theme.of(context).colorScheme.outline)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text("Issue Hotspot Map"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHotspots,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : Column(children: [

              // ── Filter chips ─────────────────────────────────────
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: _filters.length,
                  itemBuilder: (ctx, i) {
                    final active = _selectedFilter == _filters[i];
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedFilter = _filters[i]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: Text(_filters[i],
                            style: TextStyle(
                                color: active
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                      ),
                    );
                  },
                ),
              ),

              // ── Map ──────────────────────────────────────────────
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mumbaiCenter,
                      initialZoom: 11.5,
                      minZoom: 9,
                      maxZoom: 18,
                    ),
                    children: [
                      // OpenStreetMap tiles — FREE, no key needed
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.citizen_app',
                        maxZoom: 19,
                      ),

                      // ── Colored circles ──────────────────────────
                      CircleLayer(
                        circles: _filteredHotspots.map((h) {
                          final color = _circleColor(h);
                          return CircleMarker(
                            point: LatLng(
                              h['latitude'] as double,
                              h['longitude'] as double,
                            ),
                            radius: _circleRadius(h),
                            useRadiusInMeter: true,
                            color: color.withOpacity(0.25),
                            borderColor: color.withOpacity(0.8),
                            borderStrokeWidth: 2,
                          );
                        }).toList(),
                      ),

                      // ── Tap markers ──────────────────────────────
                      MarkerLayer(
                        markers: _filteredHotspots.map((h) {
                          final color = _circleColor(h);
                          final open  = h['open'] as int;
                          return Marker(
                            point: LatLng(
                              h['latitude'] as double,
                              h['longitude'] as double,
                            ),
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              onTap: () => _showHotspotDetail(h),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.5),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    "$open",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Legend ───────────────────────────────────────────
              Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Severity Legend",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.outline)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _legendItem(const Color(0xFF10B981), "Resolved / 1+"),
                        _legendItem(const Color(0xFFF59E0B), "3+ open"),
                        _legendItem(const Color(0xFFF97316), "5+ open"),
                        _legendItem(const Color(0xFFEF4444), "10+ open"),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Summary
                    if (_hotspots.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [
                            _summaryNum(
                                "${_filteredHotspots.length}",
                                "Hotspots"),
                            _summaryNum(
                                "${_filteredHotspots.fold(0, (s, h) => s + (h['open'] as int))}",
                                "Open"),
                            _summaryNum(
                                "${_filteredHotspots.fold(0, (s, h) => s + (h['resolved'] as int))}",
                                "Resolved"),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ]),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(children: [
      Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color:color.withOpacity(0.3), blurRadius:4)])),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _summaryNum(String value, String label) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary)),
      Text(label,
          style: TextStyle(
              fontSize: 10, color: Colors.grey.shade500)),
    ]);
  }
}