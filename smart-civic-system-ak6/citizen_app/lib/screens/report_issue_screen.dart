import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../services/image_upload_service.dart';
import '../services/api_service.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../services/pdf_service.dart';
import '../services/email_service.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});
  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen>
    with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  final _picker    = ImagePicker();

  // ── Page enter animation ─────────────────────────────────
  late final AnimationController _pageCtrl;
  late final Animation<double>   _pageFade;
  late final Animation<Offset>   _pageSlide;

  final _addressCtrl = TextEditingController();
  final _wardCtrl    = TextEditingController(); // Used if user edits ward

  String    _category   = 'Road Damage';
  File?     _image;
  Position? _position;
  bool      _submitting = false;
  bool      _gettingLoc = false;
  bool      _uploading  = false;
  double    _uploadPct  = 0;
  String?   _wardNo;
  String?   _userName;

  // ── Voice Recording ──────────────────────────────────────
  final _audioRecorder = AudioRecorder();
  final _audioPlayer   = AudioPlayer();
  String? _audioPath;
  bool    _recording   = false;
  bool    _playing     = false;
  String? _voiceUrl;

  static const _cats = [
    {'label':'cat_road',     'icon':Icons.construction_rounded,   'color':Color(0xFFF97316)},
    {'label':'cat_light',    'icon':Icons.lightbulb_outline,      'color':Color(0xFFFACC15)},
    {'label':'cat_garbage',  'icon':Icons.delete_outline_rounded, 'color':Color(0xFF22C55E)},
    {'label':'cat_water',    'icon':Icons.water_drop_outlined,    'color':Color(0xFF3B82F6)},
    {'label':'cat_traffic',  'icon':Icons.traffic_rounded,        'color':Color(0xFF8B5CF6)},
    {'label':'cat_encroach', 'icon':Icons.warning_amber_rounded,  'color':Color(0xFFEF4444)},
    {'label':'cat_tree',     'icon':Icons.park_outlined,          'color':Color(0xFF10B981)},
    {'label':'cat_other',    'icon':Icons.more_horiz_rounded,     'color':Color(0xFF64748B)},
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
        begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _pageCtrl.forward();
    _loadUser();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _wardCtrl.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final a = AuthService();
    final ward = await a.getSavedWard();
    final name = await a.getSavedName();
    if (mounted) {
      setState(() {
        _wardNo = ward;
        _userName = name;
        _wardCtrl.text = ward ?? '';
      });
    }
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await _picker.pickImage(
          source: src, imageQuality: 75, maxWidth: 1280, maxHeight: 1280);
      if (x != null && mounted) setState(() => _image = File(x.path));
    } catch (_) {
      _snack('Could not access ${src == ImageSource.camera ? "camera" : "gallery"}',
          err: true);
    }
  }

  void _pickerSheet() {
    final lang = context.read<LanguageService>();
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2))),
          Align(alignment: Alignment.centerLeft,
            child: Text(lang.translate('choose_photo'), style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700,
              color: cs.onSurface))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _PickTile(
              icon: Icons.camera_alt_rounded, label: lang.translate('camera'),
              color: cs.primary,
              onTap: () { Navigator.pop(context); _pick(ImageSource.camera); })),
            const SizedBox(width: 12),
            Expanded(child: _PickTile(
              icon: Icons.photo_library_rounded, label: lang.translate('gallery'),
              color: cs.secondary,
              onTap: () { Navigator.pop(context); _pick(ImageSource.gallery); })),
          ]),
        ]),
      ),
    );
  }

  Future<void> _getLocation() async {
    setState(() => _gettingLoc = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Location permission denied.', err: true);
        setState(() => _gettingLoc = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15));
      if (mounted) setState(() { _position = pos; _gettingLoc = false; });
      final lang = context.read<LanguageService>();
      _snack(lang.translate('location_captured'));
    } catch (e) {
      if (mounted) setState(() => _gettingLoc = false);
      _snack('Location failed: $e', err: true);
    }
  }

  // ── Voice Recording Logic ─────────────────────────────────
  Future<void> _toggleRecording() async {
    final lang = context.read<LanguageService>();
    try {
      if (_recording) {
        final path = await _audioRecorder.stop();
        setState(() { _recording = false; _audioPath = path; });
        _snack(lang.translate('voice_recorded'));
      } else {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getTemporaryDirectory();
          final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(RecordConfig(), path: path);
          setState(() { _recording = true; _audioPath = null; });
        } else {
          _snack('Microphone permission denied', err: true);
        }
      }
    } catch (e) {
      debugPrint('Recording error: $e');
      _snack('Recording failed: $e', err: true);
    }
  }

  Future<void> _playRecording() async {
    if (_audioPath == null) return;
    try {
      if (_playing) {
        await _audioPlayer.pause();
        setState(() => _playing = false);
      } else {
        await _audioPlayer.play(DeviceFileSource(_audioPath!));
        setState(() => _playing = true);
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playing = false);
        });
      }
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  void _deleteRecording() {
    setState(() { _audioPath = null; _playing = false; });
    _audioPlayer.stop();
  }

  Future<String?> _uploadVoice() async {
    return null; 
  }

  // ── Upload image to Cloudinary ────────────────────────────
  Future<String?> _uploadImage(String docId) async {
    if (_image == null) {
      debugPrint("No image selected.");
      return null;
    }

    setState(() {
      _uploading = true;
      _uploadPct = 0.5;
    });

    try {
      final imageUrl = await ImageUploadService.uploadImage(
        file: _image!,
        name: "issue_$docId",
        onProgress: (p) {
          if (mounted) setState(() => _uploadPct = p);
        },
      );

      if (imageUrl != null) {
        debugPrint("Upload successful: $imageUrl");
        return imageUrl;
      } else {
        _snack('Image upload failed', err: true);
        return null;
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      _snack('Image upload failed: $e', err: true);
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadPct = 0;
        });
      }
    }
  }

  String _trackId() {
    final n = DateTime.now();
    return 'BMC'
        '${n.year}'
        '${n.month.toString().padLeft(2, '0')}'
        '${n.day.toString().padLeft(2, '0')}'
        '${n.hour.toString().padLeft(2, '0')}'
        '${n.minute.toString().padLeft(2, '0')}';
  }

  String _getDepartmentForCategory(String cat) {
    switch (cat.toLowerCase().trim()) {
      case 'cat_road':
      case 'road damage':
      case 'pothole':
        return 'Road Department';
      case 'cat_light':
      case 'streetlight':
      case 'broken streetlight':
        return 'Electric Department';
      case 'cat_garbage':
      case 'garbage':
      case 'garbage & waste':
      case 'overflowing bin':
        return 'Sanitation Department';
      case 'cat_water':
      case 'water supply':
      case 'drainage issue':
      case 'water leak':
        return 'Water Supply';
      case 'cat_traffic':
      case 'traffic & signals':
      case 'traffic control':
        return 'Traffic Control';
      case 'cat_tree':
      case 'fallen trees / branches':
      case 'tree':
        return 'Tree Authority';
      case 'cat_encroach':
      case 'encroachment':
      case 'cat_other':
      case 'other issue':
      default:
        return 'General Administration';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Please log in again', err: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      final trackId = _trackId();

      // ✅ Reserve doc ID FIRST, upload image & voice, THEN write full doc
      final docRef   = FirebaseFirestore.instance.collection('issues').doc();
      
      // Upload media
      final imageUrl = await _uploadImage(docRef.id);
      final voiceUrl = await _uploadVoice();

      final ward = _wardCtrl.text.trim().isEmpty ? (_wardNo ?? 'Unknown') : _wardCtrl.text.trim();
      final autoDept = _getDepartmentForCategory(_category);

      await docRef.set({
        'trackId':      trackId,
        'title':        _titleCtrl.text.trim(),
        'description':  _descCtrl.text.trim(),
        'category':     _category,
        'assignedTo':   autoDept,
        'wardNo':       ward,
        'manualAddress': _addressCtrl.text.trim(),
        'status':       'assigned',
        'userId':       user.uid,
        'userName':     _userName ?? '',
        'userEmail':    user.email ?? '',
        'latitude':     _position?.latitude,
        'longitude':    _position?.longitude,
        'imageUrl':     imageUrl,
        'voiceUrl':     voiceUrl,
        'timeline':     [
          {
            'step': 'Reported',
            'time': DateTime.now().toUtc().toIso8601String(),
            'by':   'citizen',
          },
          {
            'step': 'Forwarded',
            'time': DateTime.now().toUtc().toIso8601String(),
            'by':   'System (Auto-Routed to $autoDept)',
          }
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 📄 Generate Confirmation PDF
      if (mounted) _snack('Generating confirmation report...', err: false);
      final pdfData = {
        'trackId': trackId,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category,
        'wardNo': ward,
        'manualAddress': _addressCtrl.text.trim(),
        'userName': _userName ?? '',
        'userEmail': user.email ?? '',
        'latitude': _position?.latitude,
        'longitude': _position?.longitude,
        'imageUrl': imageUrl,
        'localImagePath': _image?.path, // Fallback for PDF generation
      };

      final pdfFile = await PdfService.generateComplaintReport(pdfData);

      // 📧 Send Email
      if (mounted) _snack('Sending confirmation email...', err: false);
      await EmailService.sendComplaintConfirmation(
        pdfFile,
        user.email ?? '',
        trackId,
      );


      if (!mounted) return;

      setState(() => _submitting = false);
      _showSuccess(trackId);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack('Submission failed: $e', err: true);
      }
    }
  }

  void _showSuccess(String trackId) {
    final cs = Theme.of(context).colorScheme;
    final ls = context.read<LanguageService>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: cs.tertiary.withOpacity(0.12),
              shape: BoxShape.circle),
            child: Icon(Icons.check_circle_rounded,
                color: cs.tertiary, size: 50)),
          const SizedBox(height: 16),
          Text(ls.translate('submitted_title'), style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: cs.onSurface)),
          const SizedBox(height: 10),
          Text(ls.translate('track_id'), 
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(trackId, style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: cs.primary,
              letterSpacing: 1.5, fontFamily: 'monospace')),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: trackId));
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ls.translate('copied'))));
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(ls.translate('copy_id'), style: const TextStyle(fontWeight: FontWeight.w700))),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0),
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Go back home
              },
              child: Text(ls.translate('done'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ),
        ]),
      ),
    );
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: err ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lang = context.watch<LanguageService>();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(lang.translate('report_issue')),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
      ),

      body: FadeTransition(
        opacity: _pageFade,
        child: SlideTransition(
          position: _pageSlide,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Ward banner
                  if (_wardNo != null && _wardNo!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: cs.primary.withOpacity(0.2))),
                      child: Row(children: [
                        Icon(Icons.location_city_rounded, color: cs.primary, size: 20),
                        const SizedBox(width: 10),
                        Text('${lang.translate('ward_reporting')} $_wardNo',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                                fontSize: 14)),
                      ])),

                  // ── Category ─────────────────────────────
                  _Lbl(label: lang.translate('issue_category'), icon: Icons.grid_view_rounded),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 105,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _cats.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final cat = _cats[i];
                        final sel = _category == cat['label'];
                        final col = cat['color'] as Color;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _category = cat['label'] as String);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 88,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: sel ? col : cs.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel ? col : cs.outlineVariant,
                                  width: sel ? 2 : 1),
                              boxShadow: [BoxShadow(
                                color: sel
                                    ? col.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4))]),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? Colors.white.withOpacity(0.2)
                                        : col.withOpacity(0.1),
                                    shape: BoxShape.circle),
                                  child: Icon(cat['icon'] as IconData,
                                      color: sel ? Colors.white : col,
                                      size: 24)),
                                const SizedBox(height: 7),
                                Text(lang.translate(cat['label'] as String),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: sel
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: sel
                                            ? Colors.white
                                            : cs.onSurfaceVariant)),
                              ]),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Title + Description ───────────────────
                   _Lbl(label: lang.translate('issue_details'),
                      icon: Icons.description_rounded),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _dec(lang.translate('title_hint')),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? lang.translate('error_title_req') : null),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _dec(lang.translate('desc_hint')),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? lang.translate('error_desc_req') : null),
                  const SizedBox(height: 28),

                  const SizedBox(height: 28),
                  
                  // ── Voice Message ────────────────────────
                  _Lbl(label: lang.translate('voice_msg'), 
                      icon: Icons.mic_rounded),
                  const SizedBox(height: 12),
                  _VoiceRecorderUI(
                    recording: _recording,
                    audioPath: _audioPath,
                    playing:   _playing,
                    onToggle:  _toggleRecording,
                    onPlay:    _playRecording,
                    onDelete:  _deleteRecording,
                    cs:        cs,
                  ),

                  const SizedBox(height: 28),

                  // ── Photo ─────────────────────────────────
                  _Lbl(label: lang.translate('photo_evidence'),
                      icon: Icons.camera_enhance_rounded),
                  const SizedBox(height: 12),

                  if (_uploading)
                    _UploadProgress(pct: _uploadPct, cs: cs)
                  else if (_image == null)
                    _PhotoPicker(onTap: _pickerSheet, cs: cs)
                  else
                    _PhotoPreview(
                        image: _image!,
                        onRemove: () => setState(() => _image = null),
                        onChange: _pickerSheet),

                  const SizedBox(height: 28),

                  // ── Location & Ward ──────────────────────
                  _Lbl(label: lang.translate('location_ward'),
                      icon: Icons.location_on_rounded),
                  const SizedBox(height: 12),
                  
                  // GPS Card
                  _LocationCard(
                    position: _position,
                    loading: _gettingLoc,
                    cs: cs,
                    onGetLocation: _getLocation),
                  
                  const SizedBox(height: 12),

                  // Manual Address
                  TextFormField(
                    controller: _addressCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _dec(lang.translate('manual_address')),
                    maxLines: 2,
                  ),
                  
                  const SizedBox(height: 12),

                  // Manual Ward Selection
                  TextFormField(
                    controller: _wardCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dec(lang.translate('ward_confirm')),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return lang.translate('error_ward_req');
                      final ward = int.tryParse(v);
                      if (ward == null || ward < 1 || ward > 227) return lang.translate('error_ward_invalid');
                      return null;
                    },
                  ),

                  const SizedBox(height: 40),

                  // ── Submit button ─────────────────────────
                  _SubmitButton(
                    submitting: _submitting,
                    uploading: _uploading,
                    cs: cs,
                    onSubmit: _submit),
                  const SizedBox(height: 12),
                  Center(child: Text(
                    lang.translate('smart_civic_system'),
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withOpacity(0.5),
                        fontWeight: FontWeight.w500))),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String h) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: h,
      hintStyle: TextStyle(color: cs.outline, fontSize: 13),
      filled: true, fillColor: cs.surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12));
  }
}

// ═══════════════════════════════════════════════════════════
//  SUB-WIDGETS
// ═══════════════════════════════════════════════════════════

class _Lbl extends StatelessWidget {
  final String label; final IconData icon;
  const _Lbl({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(icon, size: 17, color: cs.primary),
      const SizedBox(width: 7),
      Text(label, style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 14,
          color: cs.onSurface)),
    ]);
  }
}

class _PickTile extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final VoidCallback onTap;
  const _PickTile({required this.icon, required this.label,
    required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25))),
      child: Column(children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(
            fontWeight: FontWeight.w700, color: color, fontSize: 14)),
      ])));
}

class _UploadProgress extends StatelessWidget {
  final double pct; final ColorScheme cs;
  const _UploadProgress({required this.pct, required this.cs});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: cs.outlineVariant)),
    child: Row(children: [
      Icon(Icons.cloud_upload_rounded, color: cs.primary, size: 24),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.read<LanguageService>().translate('uploading'), style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: cs.outlineVariant.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation(cs.primary),
              minHeight: 6)),
        ])),
      const SizedBox(width: 14),
      Text('${(pct * 100).round()}%', style: TextStyle(
          fontWeight: FontWeight.w900, color: cs.primary, fontSize: 14)),
    ]));
}

class _PhotoPicker extends StatelessWidget {
  final VoidCallback onTap; final ColorScheme cs;
  const _PhotoPicker({required this.onTap, required this.cs});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 160, width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant, width: 1.5)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.10), shape: BoxShape.circle),
          child: Icon(Icons.add_a_photo_rounded, size: 32, color: cs.primary)),
        const SizedBox(height: 12),
        Text(context.read<LanguageService>().translate('add_photo_evidence'),
            style: TextStyle(color: cs.onSurface, fontSize: 14,
                fontWeight: FontWeight.w700)),
        Text('${context.read<LanguageService>().translate('camera')} or ${context.read<LanguageService>().translate('gallery')}',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      ])));
}

class _PhotoPreview extends StatelessWidget {
  final File image; final VoidCallback onRemove, onChange;
  const _PhotoPreview({required this.image,
    required this.onRemove, required this.onChange});
  @override
  Widget build(BuildContext context) => Stack(children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.file(image,
          width: double.infinity, height: 200, fit: BoxFit.cover)),
    Positioned(top: 12, right: 12,
      child: GestureDetector(
        onTap: onRemove,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
              color: Colors.black54, shape: BoxShape.circle),
          child: const Icon(Icons.close_rounded,
              color: Colors.white, size: 20)))),
    Positioned(bottom: 12, right: 12,
      child: GestureDetector(
        onTap: onChange,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(context.read<LanguageService>().translate('change_photo'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ])))),
  ]);
}

class _LocationCard extends StatelessWidget {
  final Position? position;
  final bool loading;
  final ColorScheme cs;
  final VoidCallback onGetLocation;
  const _LocationCard({required this.position, required this.loading,
    required this.cs, required this.onGetLocation});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: cs.outlineVariant, width: 1.5)),
    child: Row(children: [
      Expanded(child: position != null
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: cs.tertiary, size: 18),
              const SizedBox(width: 8),
              Text('Location Captured', style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14,
                  color: cs.tertiary)),
            ]),
            const SizedBox(height: 6),
            Text(
              'Lat: ${position!.latitude.toStringAsFixed(6)}\n'
              'Lng: ${position!.longitude.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500, height: 1.4)),
          ])
        : Text('Capture GPS to pin this issue on the map',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600))),
      const SizedBox(width: 12),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: position != null ? cs.tertiary : cs.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12)),
        onPressed: loading ? null : onGetLocation,
        icon: loading
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Icon(position != null
                ? Icons.refresh_rounded
                : Icons.my_location_rounded, size: 20),
        label: Text(position != null ? 'Redo' : 'Locate',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800))),
    ]));
}

class _SubmitButton extends StatelessWidget {
  final bool submitting, uploading;
  final ColorScheme cs;
  final VoidCallback onSubmit;
  const _SubmitButton({required this.submitting, required this.uploading,
    required this.cs, required this.onSubmit});
  @override
  Widget build(BuildContext context) {
    final ls = Provider.of<LanguageService>(context);
    return SizedBox(
      width: double.infinity, height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: cs.primary.withOpacity(0.4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20))),
        onPressed: (submitting || uploading) ? null : onSubmit,
        child: submitting
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3)),
              const SizedBox(width: 14),
              Text(ls.translate('sending_to_bmc'), style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800))])
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.send_rounded, size: 22),
              const SizedBox(width: 12),
              Text(ls.translate('submit_complaint'), style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900))])));
  }
}

class _VoiceRecorderUI extends StatelessWidget {
  final bool recording, playing;
  final String? audioPath;
  final VoidCallback onToggle, onPlay, onDelete;
  final ColorScheme cs;

  const _VoiceRecorderUI({
    required this.recording,
    required this.playing,
    required this.audioPath,
    required this.onToggle,
    required this.onPlay,
    required this.onDelete,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final ls = Provider.of<LanguageService>(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant, width: 1.5),
      ),
      child: Row(
        children: [
          // Record Button
          GestureDetector(
            onLongPress: onToggle, // Alternate option if wanted
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: recording ? Colors.red.shade100 : cs.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: recording ? Colors.red : cs.primary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  recording ? ls.translate('recording') : (audioPath != null ? ls.translate('voice_recorded') : ls.translate('tap_to_record')),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: recording ? Colors.red : cs.onSurface,
                  ),
                ),
                if (recording)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (audioPath != null && !recording)
                  Text(
                    ls.translate('preview_hint'),
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          
          if (audioPath != null && !recording) ...[
            IconButton(
              icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, 
                  color: cs.tertiary, size: 32),
              onPressed: onPlay,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}