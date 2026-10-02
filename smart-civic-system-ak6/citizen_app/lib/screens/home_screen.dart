import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import 'package:provider/provider.dart';
import 'report_issue_screen.dart';
import 'track_screen.dart';
import 'map_screen.dart';
import 'my_issues_screen.dart';

// ═══════════════════════════════════════════════════════════
//  HOME SCREEN
// ═══════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final _auth = AuthService();

  String _userName  = '';
  String _userPhone = '';
  String _userEmail = '';
  String _userWard  = '';
  int    _open      = 0;
  int    _resolved  = 0;
  bool   _loadingStats = true;

  // Animation controllers
  late final AnimationController _headerCtrl;
  late final AnimationController _cardsCtrl;
  late final AnimationController _contentCtrl;

  late final Animation<double>   _headerFade;
  late final Animation<Offset>   _headerSlide;
  late final Animation<double>   _cardsFade;
  late final Animation<Offset>   _cardsSlide;
  late final Animation<double>   _contentFade;
  late final Animation<Offset>   _contentSlide;

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(vsync:this, duration:const Duration(milliseconds:700));
    _cardsCtrl  = AnimationController(vsync:this, duration:const Duration(milliseconds:600));
    _contentCtrl= AnimationController(vsync:this, duration:const Duration(milliseconds:500));

    _headerFade  = CurvedAnimation(parent:_headerCtrl,  curve:Curves.easeOut);
    _headerSlide = Tween<Offset>(begin:const Offset(0,-0.08), end:Offset.zero)
        .animate(CurvedAnimation(parent:_headerCtrl, curve:Curves.easeOutCubic));

    _cardsFade   = CurvedAnimation(parent:_cardsCtrl,   curve:Curves.easeOut);
    _cardsSlide  = Tween<Offset>(begin:const Offset(0,0.06), end:Offset.zero)
        .animate(CurvedAnimation(parent:_cardsCtrl, curve:Curves.easeOutCubic));

    _contentFade = CurvedAnimation(parent:_contentCtrl, curve:Curves.easeOut);
    _contentSlide= Tween<Offset>(begin:const Offset(0,0.06), end:Offset.zero)
        .animate(CurvedAnimation(parent:_contentCtrl, curve:Curves.easeOutCubic));

    _loadUserData();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _cardsCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    debugPrint('DEBUG: _loadUserData - getting Firestore data');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snap = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (snap.exists && mounted) {
          final d = snap.data()!;
          debugPrint('DEBUG: User doc data: $d');
          setState(() {
            _userName  = d['name']   as String? ?? '';
            _userPhone = d['phone']  as String? ?? '';
            _userEmail = d['email']  as String? ?? user.email ?? '';
            _userWard  = d['wardNo'] as String? ?? '';
          });
          await _loadCounts(user.uid);
          _startAnimations();
          return;
        } else {
          debugPrint('DEBUG: User doc doesnt exist for SID: ${user.uid}');
        }
      }
    } catch (e) {
      debugPrint('DEBUG: Firestore error: $e');
    }

    debugPrint('DEBUG: Falling back to SharedPreferences');
    final name  = await _auth.getSavedName();
    final phone = await _auth.getSavedPhone();
    final ward  = await _auth.getSavedWard();
    if (mounted) {
      setState(() {
        _userName  = name  ?? '';
        _userPhone = phone ?? '';
        _userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        _userWard  = ward  ?? '';
        _loadingStats = false;
      });
      _startAnimations();
    }
  }

  void _startAnimations() {
    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds:180), () {
      if (mounted) _cardsCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds:320), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  Future<void> _loadCounts(String uid) async {
    try {
      final o = await FirebaseFirestore.instance.collection('issues')
          .where('userId', isEqualTo:uid).where('status', isEqualTo:'open').get();
      final r = await FirebaseFirestore.instance.collection('issues')
          .where('userId', isEqualTo:uid).where('status', isEqualTo:'resolved').get();
      if (mounted) setState(() {
        _open = o.docs.length; _resolved = r.docs.length; _loadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  String get _greeting {
    final lang = context.read<LanguageService>();
    final h = DateTime.now().hour;
    if (h < 12) return lang.translate('greeting_morning');
    if (h < 17) return lang.translate('greeting_afternoon');
    return lang.translate('greeting_evening');
  }

  String get _firstName =>
      _userName.trim().isEmpty ? 'Citizen' : _userName.trim().split(' ').first;

  void _openProfile() {
    showModalBottomSheet(
      context:context,
      isScrollControlled:true,
      backgroundColor:Colors.transparent,
      builder:(_) => _ProfileSheet(
        userName:_userName, userPhone:_userPhone,
        userEmail:_userEmail, userWard:_userWard,
        open:_open, resolved:_resolved,
        onLogout:(){ Navigator.pop(context); _logout(); },
        onSaved:(n,p,w) => setState((){_userName=n;_userPhone=p;_userWard=w;}),
      ),
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context:context,
      builder:(ctx) {
        final lang = ctx.read<LanguageService>();
        return AlertDialog(
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
          title:Text(lang.translate('sign_out'), style:const TextStyle(fontWeight:FontWeight.w800)),
          content:Text(lang.translate('sign_out_confirm')),
          actions:[
            TextButton(
              onPressed:()=>Navigator.pop(ctx,false),
              child:Text(lang.translate('cancel'),
                  style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant))),
            ElevatedButton(
              style:ElevatedButton.styleFrom(
                backgroundColor:Theme.of(context).colorScheme.error,
                foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              onPressed:()=>Navigator.pop(ctx,true),
              child:Text(lang.translate('sign_out'), style:const TextStyle(fontWeight:FontWeight.w700))),
          ],
        );
      },
    );
    if (ok==true) {
      await _auth.logout();
      if (mounted) Navigator.pushReplacementNamed(context,'/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor:cs.background,
      body:SafeArea(
        child:CustomScrollView(
          physics:const BouncingScrollPhysics(),
          slivers:[
            SliverToBoxAdapter(child: _Header(
              firstName:_firstName, greeting:_greeting,
              wardNo:_userWard, open:_open, resolved:_resolved,
              loadingStats:_loadingStats,
              onAvatarTap:_openProfile,
              onLogout:_logout,
            )),

            // Quick actions label
            SliverToBoxAdapter(child:FadeTransition(
              opacity:_cardsFade,
              child:SlideTransition(position:_cardsSlide,
                child:_SectionLabel(
                  title:context.watch<LanguageService>().translate('quick_actions'), 
                  trailing:context.watch<LanguageService>().translate('mumbai_services'))))),

            // Quick actions grid
            SliverPadding(
              padding:const EdgeInsets.symmetric(horizontal:16),
              sliver:SliverToBoxAdapter(child: _QuickActionsGrid(
                onReport:()=>Navigator.pushNamed(context,'/report'),
                onTrack: ()=>Navigator.pushNamed(context,'/track'),
                onMap:   ()=>Navigator.pushNamed(context,'/map'),
                onMyIssues:()=>Navigator.pushNamed(context,'/myIssues'),
              )),
            ),

            // Contacts label + list
            SliverToBoxAdapter(child: _SectionLabel(title:context.watch<LanguageService>().translate('helplines'))),
            SliverToBoxAdapter(child: const _ContactsList()),

            // Recent activity
            SliverToBoxAdapter(child: _RecentActivity(
              uid:FirebaseAuth.instance.currentUser?.uid ?? '')),

            const SliverToBoxAdapter(child:SizedBox(height:40)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  HEADER
// ═══════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final String firstName, greeting, wardNo;
  final int open, resolved;
  final bool loadingStats;
  final VoidCallback onAvatarTap, onLogout;
  const _Header({
    required this.firstName, required this.greeting,
    required this.wardNo, required this.open, required this.resolved,
    required this.loadingStats, required this.onAvatarTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lang = context.watch<LanguageService>();

    return Container(
      margin:const EdgeInsets.fromLTRB(16,12,16,0),
      decoration:BoxDecoration(
        gradient:LinearGradient(
          colors:[cs.primary, const Color(0xFFEA580C)], // Vibrant Deep Orange
          begin:Alignment.topLeft, end:Alignment.bottomRight),
        borderRadius:BorderRadius.circular(32),
        boxShadow:[BoxShadow(
          color:cs.primary.withOpacity(0.4),
          blurRadius:25, offset:const Offset(0,10))],
      ),
      child:Stack(children:[
        // Decorative circles
        Positioned(top:-30, right:-15,
          child:_Orb(140, 0.12)),
        Positioned(bottom:40, right:80,
          child:_Orb(60, 0.08)),
        Positioned(top:80, right:-10,
          child:_Orb(45, 0.05)),

        Padding(
          padding:const EdgeInsets.fromLTRB(24,24,24,28),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[

            // Top row
            Row(children:[
              GestureDetector(
                onTap:onAvatarTap,
                child:Hero(
                  tag:'user_avatar',
                  child:_AvatarCircle(name:firstName, size:54)),
              ),
              const SizedBox(width:14),
              Expanded(child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(greeting,
                      style:TextStyle(
                          color:Colors.white.withOpacity(0.8),
                          fontSize:13, fontWeight:FontWeight.w500, letterSpacing:0.5)),
                  Text(firstName,
                      style:const TextStyle(
                          color:Colors.white,
                          fontSize:22, fontWeight:FontWeight.w900,
                          letterSpacing:-0.7)),
                ],
              )),
              _HeaderBtn(icon:Icons.notifications_active_rounded, onTap:(){}),
              const SizedBox(width:10),
              // Language Toggle Button
              GestureDetector(
                onTap: () => context.read<LanguageService>().toggleLanguage(),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      context.watch<LanguageService>().currentLanguageCode.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(width:10),
              _HeaderBtn(icon:Icons.logout_rounded, onTap:onLogout),
            ]),

            const SizedBox(height:18),

            // Location line
            Row(children:[
              Icon(Icons.location_on_rounded,
                  color:Colors.white.withOpacity(0.7), size:14),
              const SizedBox(width:6),
              Text('${context.watch<LanguageService>().translate('app_title')} • ${context.watch<LanguageService>().translate('ward')} $wardNo',
                  style:TextStyle(
                      color:Colors.white.withOpacity(0.8),
                      fontSize:12, fontWeight:FontWeight.w600, letterSpacing:0.2)),
            ]),

            const SizedBox(height:20),

            // Stats strip
            ClipRRect(
              borderRadius:BorderRadius.circular(20),
              child:Container(
                padding:const EdgeInsets.symmetric(horizontal:20, vertical:16),
                decoration:BoxDecoration(
                  color:Colors.white.withOpacity(0.18),
                  borderRadius:BorderRadius.circular(20),
                  border:Border.all(color:Colors.white.withOpacity(0.25)),
                ),
                child:loadingStats
                  ? const Center(child:SizedBox(width:20, height:20,
                      child:CircularProgressIndicator(
                          color:Colors.white, strokeWidth:2.5)))
                  : Row(
                      mainAxisAlignment:MainAxisAlignment.spaceAround,
                      children:[
                        _StatChipW(label:lang.translate('ward'),
                            value:wardNo.isNotEmpty ? wardNo : '—'),
                        _VDivider(),
                        _StatChipW(label:lang.translate('open'), value:'$open',
                            valueColor:const Color(0xFFFFE5B4)),
                        _VDivider(),
                        _StatChipW(label:lang.translate('resolved'), value:'$resolved',
                            valueColor:const Color(0xFFC6F6D5)),
                      ],
                    ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size, opacity;
  const _Orb(this.size, this.opacity);
  @override
  Widget build(BuildContext ctx) => Container(
    width:size, height:size,
    decoration:BoxDecoration(
      shape:BoxShape.circle,
      color:Colors.white.withOpacity(opacity)),
  );
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap:onTap,
    child:Container(
      width:36, height:36,
      decoration:BoxDecoration(
        color:Colors.white.withOpacity(0.16),
        shape:BoxShape.circle),
      child:Icon(icon, color:Colors.white, size:19)),
  );
}

class _AvatarCircle extends StatelessWidget {
  final String name;
  final double size;
  const _AvatarCircle({required this.name, required this.size});
  @override
  Widget build(BuildContext ctx) {
    final initials = name.trim().isEmpty ? '?'
        : name.trim().split(' ')
            .map((w)=>w.isEmpty?'':w[0].toUpperCase()).take(2).join();
    return Container(
      width:size, height:size,
      decoration:BoxDecoration(
        shape:BoxShape.circle,
        color:Colors.white.withOpacity(0.22),
        border:Border.all(color:Colors.white.withOpacity(0.55), width:2)),
      child:Center(child:Text(initials,
          style:TextStyle(color:Colors.white,
              fontWeight:FontWeight.w800,
              fontSize:size*0.33, letterSpacing:0.5))),
    );
  }
}

class _StatChipW extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _StatChipW({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext ctx) => Column(mainAxisSize:MainAxisSize.min, children:[
    Text(value, style:TextStyle(
        color:valueColor??Colors.white,
        fontWeight:FontWeight.w800, fontSize:18, letterSpacing:-0.3)),
    const SizedBox(height:2),
    Text(label, style:TextStyle(
        color:Colors.white.withOpacity(0.65),
        fontSize:10, letterSpacing:0.3)),
  ]);
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) => Container(
    width:1, height:34, color:Colors.white.withOpacity(0.22));
}

// ═══════════════════════════════════════════════════════════
//  SECTION LABEL
// ═══════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionLabel({required this.title, this.trailing});
  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return Padding(
      padding:const EdgeInsets.fromLTRB(20,24,20,12),
      child:Row(children:[
        Text(title, style:TextStyle(fontSize:17,
            fontWeight:FontWeight.w800,
            color:cs.onBackground, letterSpacing:-0.2)),
        const Spacer(),
        if (trailing!=null)
          Text(trailing!, style:TextStyle(
              fontSize:11, color:cs.outline,
              fontStyle:FontStyle.italic)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  QUICK ACTIONS GRID — each card animates in independently
// ═══════════════════════════════════════════════════════════
class _QuickActionsGrid extends StatefulWidget {
  final VoidCallback onReport, onTrack, onMap, onMyIssues;
  const _QuickActionsGrid({
    required this.onReport, required this.onTrack,
    required this.onMap,    required this.onMyIssues});
  @override
  State<_QuickActionsGrid> createState() => _QuickActionsGridState();
}

class _QuickActionsGridState extends State<_QuickActionsGrid>
    with TickerProviderStateMixin {
  final List<AnimationController> _ctrls = [];
  final List<Animation<double>>   _fades = [];
  final List<Animation<Offset>>   _slides= [];

  static const _delays = [0, 80, 160, 240];

  @override
  void initState() {
    super.initState();
    for (int i=0;i<4;i++) {
      final c = AnimationController(vsync:this,
          duration:const Duration(milliseconds:450));
      _ctrls.add(c);
      _fades.add(CurvedAnimation(parent:c, curve:Curves.easeOut));
      _slides.add(Tween<Offset>(
          begin:const Offset(0,0.12), end:Offset.zero)
          .animate(CurvedAnimation(parent:c, curve:Curves.easeOutCubic)));
      Future.delayed(Duration(milliseconds:_delays[i]), (){
        if (mounted) c.forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    final lang = ctx.watch<LanguageService>();
    final items = [
      _ActionItem(lang.translate('report_issue'),   lang.translate('file_complaint'),
          Icons.report_problem_outlined, cs.primary,    widget.onReport),
      _ActionItem(lang.translate('track_complaint'), lang.translate('check_status'),
          Icons.manage_search_rounded,  cs.secondary,   widget.onTrack),
      _ActionItem(lang.translate('hotspot_map'),    lang.translate('view_areas'),
          Icons.map_outlined,           cs.tertiary,    widget.onMap),
      _ActionItem(lang.translate('my_issues'),      lang.translate('all_complaints'),
          Icons.list_alt_rounded,       const Color(0xFF7C3AED), widget.onMyIssues),
    ];
    return GridView.count(
      crossAxisCount:2,
      crossAxisSpacing:12, mainAxisSpacing:12,
      childAspectRatio:1.06,
      shrinkWrap:true,
      physics:const NeverScrollableScrollPhysics(),
      children:List.generate(4,(i)=>_ActionCard(item:items[i])),
    );
  }
}

class _ActionItem {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionItem(this.title,this.subtitle,this.icon,this.color,this.onTap);
}

class _ActionCard extends StatefulWidget {
  final _ActionItem item;
  const _ActionCard({required this.item});
  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync:this,
        duration:const Duration(milliseconds:120),
        reverseDuration:const Duration(milliseconds:200));
    _scale = Tween<double>(begin:1.0, end:0.94)
        .animate(CurvedAnimation(parent:_pressCtrl, curve:Curves.easeInOut));
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    final item = widget.item;
    return GestureDetector(
        onTap: () {
          Future.delayed(const Duration(milliseconds:20), item.onTap);
        },
        child:Container(
          padding:const EdgeInsets.all(18),
          decoration:BoxDecoration(
            color:cs.surface,
            borderRadius:BorderRadius.circular(22),
            border:Border.all(color:cs.outlineVariant.withOpacity(0.5)),
            boxShadow:[
              BoxShadow(
                  color:item.color.withOpacity(0.14),
                  blurRadius:16, offset:const Offset(0,4)),
            ],
          ),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Container(
              width:50, height:50,
              decoration:BoxDecoration(
                gradient:LinearGradient(
                  colors:[item.color, item.color.withOpacity(0.75)],
                  begin:Alignment.topLeft, end:Alignment.bottomRight),
                borderRadius:BorderRadius.circular(15),
              ),
              child:Icon(item.icon, color:Colors.white, size:24),
            ),
            const Spacer(),
            Text(item.title, style:TextStyle(
                fontSize:14, fontWeight:FontWeight.w800,
                color:cs.onSurface, letterSpacing:-0.2)),
            const SizedBox(height:2),
            Text(item.subtitle, style:TextStyle(
                fontSize:11, color:cs.onSurfaceVariant)),
          ]),
        ),
      );
  }
}

// ═══════════════════════════════════════════════════════════
//  CONTACTS LIST
// ═══════════════════════════════════════════════════════════
class _ContactsList extends StatelessWidget {
  const _ContactsList();

  static const _contacts = [
    _ContactData(Icons.emergency_share_rounded,'BMC Emergency Helpline',
        '24×7 Control Room','1916',true,Color(0xFFDC2626)),
    _ContactData(Icons.support_agent_rounded,'Civic Grievance Officer',
        'Ward-level Support','+91 22 2262 0251',true,Color(0xFF2563EB)),
    _ContactData(Icons.alternate_email_rounded,'Email Administration',
        'Complaints & Feedback','complaints@mcgm.gov.in',false,Color(0xFF16A34A)),
    _ContactData(Icons.language_rounded,'BMC Official Portal',
        'Forms, Notices & Updates','mcgm.gov.in',false,Color(0xFF7C3AED)),
  ];

  @override
  Widget build(BuildContext ctx) => Padding(
    padding:const EdgeInsets.symmetric(horizontal:16),
    child:Column(children:List.generate(_contacts.length,(i)=>Padding(
      padding:EdgeInsets.only(bottom:i<_contacts.length-1?10:0),
      child:_ContactCard(data:_contacts[i])))));
}

class _ContactData {
  final IconData icon;
  final String title, subtitle, value;
  final bool isPhone;
  final Color color;
  const _ContactData(this.icon,this.title,this.subtitle,this.value,this.isPhone,this.color);
}

class _ContactCard extends StatefulWidget {
  final _ContactData data;
  const _ContactCard({required this.data});
  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync:this,
        duration:const Duration(milliseconds:100),
        reverseDuration:const Duration(milliseconds:180));
    _scale = Tween<double>(begin:1.0, end:0.97)
        .animate(CurvedAnimation(parent:_ctrl, curve:Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    final cs  = Theme.of(ctx).colorScheme;
    final d   = widget.data;
    return ScaleTransition(
      scale:_scale,
      child:GestureDetector(
        onTapDown:(_){ _ctrl.forward(); },
        onTapUp:(_){
          _ctrl.reverse();
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content:Text(d.isPhone?'Calling ${d.value}…':'Opening ${d.value}…'),
            backgroundColor:d.color,
            behavior:SnackBarBehavior.floating,
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
            duration:const Duration(seconds:2),
          ));
        },
        onTapCancel:(){ _ctrl.reverse(); },
        child:Container(
          padding:const EdgeInsets.all(14),
          decoration:BoxDecoration(
            color:cs.surface,
            borderRadius:BorderRadius.circular(16),
            border:Border.all(color:cs.outlineVariant.withOpacity(0.6)),
            boxShadow:[BoxShadow(
                color:Colors.black.withOpacity(0.04),
                blurRadius:8, offset:const Offset(0,2))],
          ),
          child:Row(children:[
            Container(
              width:46, height:46,
              decoration:BoxDecoration(
                color:d.color.withOpacity(0.09),
                borderRadius:BorderRadius.circular(13)),
              child:Icon(d.icon, color:d.color, size:22)),
            const SizedBox(width:14),
            Expanded(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text(d.title, style:TextStyle(fontSize:13,
                    fontWeight:FontWeight.w700, color:cs.onSurface)),
                Text(d.subtitle, style:TextStyle(fontSize:11,
                    color:cs.onSurfaceVariant)),
                const SizedBox(height:3),
                Text(d.value, style:TextStyle(fontSize:13,
                    fontWeight:FontWeight.w600, color:d.color)),
              ],
            )),
            Container(
              width:34, height:34,
              decoration:BoxDecoration(
                color:d.color.withOpacity(0.09),
                borderRadius:BorderRadius.circular(10)),
              child:Icon(
                d.isPhone?Icons.call_rounded:Icons.open_in_new_rounded,
                color:d.color, size:16)),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  RECENT ACTIVITY
// ═══════════════════════════════════════════════════════════
class _RecentActivity extends StatelessWidget {
  final String uid;
  const _RecentActivity({required this.uid});

  @override
  Widget build(BuildContext ctx) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _SectionLabel(title:ctx.watch<LanguageService>().translate('recent_activity')),
      Padding(
        padding:const EdgeInsets.symmetric(horizontal:16),
        child:StreamBuilder<QuerySnapshot>(
          stream:FirebaseFirestore.instance
              .collection('issues')
              .where('userId', isEqualTo:uid)
              .snapshots(),
          builder:(ctx,snap){
            if (snap.connectionState==ConnectionState.waiting) {
              return Padding(
                padding:const EdgeInsets.symmetric(vertical:24),
                child:Center(child:CircularProgressIndicator(
                    color:Theme.of(ctx).colorScheme.primary, strokeWidth:2)));
            }
            // Sort client-side to avoid index error
            final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? [])
              ..sort((a, b) {
                final at = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                final bt = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                if (at == null && bt == null) return 0;
                if (at == null) return 1;
                if (bt == null) return -1;
                return bt.compareTo(at);
              });
            // Limit to 3
            final recent = docs.take(3).toList();

            if (recent.isEmpty) {
              return _EmptyActivity(
                  onReport:()=>Navigator.pushNamed(ctx,'/report'));
            }
            return Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                ...List.generate(docs.length,(i)=>
                    _ActivityRow(
                      data:docs[i].data() as Map<String,dynamic>,
                      index:i)),
                const SizedBox(height:4),
                Align(
                  alignment:Alignment.centerRight,
                  child:TextButton.icon(
                    onPressed:()=>Navigator.pushNamed(ctx,'/myIssues'),
                    icon:const Icon(Icons.arrow_forward_rounded,size:15),
                    label:Text(ctx.watch<LanguageService>().translate('view_all'),
                        style:const TextStyle(fontWeight:FontWeight.w700)),
                    style:TextButton.styleFrom(
                        foregroundColor:Theme.of(ctx).colorScheme.primary)),
                ),
              ],
            );
          },
        ),
      ),
    ]);
  }
}

class _ActivityRow extends StatefulWidget {
  final Map<String,dynamic> data;
  final int index;
  const _ActivityRow({required this.data, required this.index});
  @override
  State<_ActivityRow> createState() => _ActivityRowState();
}

class _ActivityRowState extends State<_ActivityRow>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync:this,
        duration:const Duration(milliseconds:400));
    _fade = CurvedAnimation(parent:_ctrl, curve:Curves.easeOut);
    _slide= Tween<Offset>(begin:const Offset(0.04,0), end:Offset.zero)
        .animate(CurvedAnimation(parent:_ctrl, curve:Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds:widget.index*80),(){
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color _sc(BuildContext ctx, String s) {
    final cs = Theme.of(ctx).colorScheme;
    switch(s){
      case 'resolved':    return cs.tertiary;
      case 'in_progress': return Colors.orange;
      case 'rejected':    return cs.error;
      default:            return cs.secondary;
    }
  }

  String _sl(String s){
    switch(s){
      case 'resolved':    return 'Resolved';
      case 'in_progress': return 'In Progress';
      case 'rejected':    return 'Rejected';
      default:            return 'Open';
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final status = (widget.data['status'] as String?) ?? 'open';
    final cs     = Theme.of(ctx).colorScheme;
    final sc     = _sc(ctx, status);
    final ts     = widget.data['createdAt'] as Timestamp?;
    final date   = ts!=null
        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
        : '—';

    return FadeTransition(
      opacity:_fade,
      child:SlideTransition(
        position:_slide,
        child:Container(
          margin:const EdgeInsets.only(bottom:9),
          padding:const EdgeInsets.all(14),
          decoration:BoxDecoration(
            color:cs.surface,
            borderRadius:BorderRadius.circular(14),
            border:Border.all(color:cs.outlineVariant.withOpacity(0.6)),
            boxShadow:[BoxShadow(
                color:Colors.black.withOpacity(0.04),
                blurRadius:6, offset:const Offset(0,2))],
          ),
          child:Row(children:[
            Container(
              width:8, height:8,
              margin:const EdgeInsets.only(right:12,top:2),
              decoration:BoxDecoration(color:sc,shape:BoxShape.circle)),
            Expanded(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text((widget.data['title'] as String?)??'—',
                    maxLines:1, overflow:TextOverflow.ellipsis,
                    style:TextStyle(fontWeight:FontWeight.w600,
                        fontSize:13,color:cs.onSurface)),
                Text((widget.data['category'] as String?)??'—',
                    style:TextStyle(fontSize:11,color:cs.onSurfaceVariant)),
              ],
            )),
            Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
              Container(
                padding:const EdgeInsets.symmetric(horizontal:9,vertical:3),
                decoration:BoxDecoration(
                  color:sc.withOpacity(0.10),
                  borderRadius:BorderRadius.circular(99)),
                child:Text(_sl(status), style:TextStyle(
                    color:sc, fontSize:10, fontWeight:FontWeight.w700))),
              const SizedBox(height:4),
              Text(date, style:TextStyle(
                  fontSize:10,color:cs.onSurfaceVariant)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  final VoidCallback onReport;
  const _EmptyActivity({required this.onReport});
  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      padding:const EdgeInsets.symmetric(vertical:28,horizontal:20),
      decoration:BoxDecoration(
        color:cs.surface,
        borderRadius:BorderRadius.circular(16),
        border:Border.all(color:cs.outlineVariant.withOpacity(0.6))),
      child:Column(children:[
        Container(
          width:56,height:56,
          decoration:BoxDecoration(
            color:cs.background, shape:BoxShape.circle,
            border:Border.all(color:cs.outlineVariant)),
          child:Icon(Icons.inbox_outlined, size:26, color:cs.outline)),
        const SizedBox(height:12),
        Text('No issues filed yet',style:TextStyle(
            fontSize:14,fontWeight:FontWeight.w600,color:cs.onSurface)),
        const SizedBox(height:4),
        Text('Report a civic issue to get started',
            style:TextStyle(fontSize:12,color:cs.onSurfaceVariant)),
        const SizedBox(height:18),
        ElevatedButton.icon(
          style:ElevatedButton.styleFrom(
            backgroundColor:cs.primary,
            foregroundColor:Colors.white, elevation:0,
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
            padding:const EdgeInsets.symmetric(horizontal:20,vertical:11)),
          onPressed:onReport,
          icon:const Icon(Icons.add_rounded,size:17),
          label:const Text('Report First Issue',
              style:TextStyle(fontWeight:FontWeight.w700))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  PROFILE BOTTOM SHEET
// ═══════════════════════════════════════════════════════════
class _ProfileSheet extends StatefulWidget {
  final String userName, userPhone, userEmail, userWard;
  final int open, resolved;
  final VoidCallback onLogout;
  final void Function(String,String,String) onSaved;
  const _ProfileSheet({
    required this.userName, required this.userPhone,
    required this.userEmail, required this.userWard,
    required this.open, required this.resolved,
    required this.onLogout, required this.onSaved});
  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  bool _editing=false, _saving=false;
  late final TextEditingController _nameCtrl, _phoneCtrl, _wardCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text:widget.userName);
    _phoneCtrl = TextEditingController(text:widget.userPhone);
    _wardCtrl  = TextEditingController(text:widget.userWard);
  }

  @override
  void dispose(){
    _nameCtrl.dispose();_phoneCtrl.dispose();_wardCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(()=>_saving=true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid!=null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'name':_nameCtrl.text.trim(),
          'phone':_phoneCtrl.text.trim(),
          'wardNo':_wardCtrl.text.trim(),
        });
        final a = AuthService();
        await a.saveUserName(_nameCtrl.text.trim());
        await a.saveUserPhone(_phoneCtrl.text.trim());
        await a.saveWard(_wardCtrl.text.trim());
      }
      widget.onSaved(_nameCtrl.text.trim(),_phoneCtrl.text.trim(),_wardCtrl.text.trim());
      setState((){_editing=false;_saving=false;});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:const Text('Profile updated'),
        backgroundColor:Theme.of(context).colorScheme.tertiary,
        behavior:SnackBarBehavior.floating));
    } catch(e) {
      setState(()=>_saving=false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('Failed: $e'),
        backgroundColor:Theme.of(context).colorScheme.error,
        behavior:SnackBarBehavior.floating));
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)));

  @override
  Widget build(BuildContext ctx) {
    final cs    = Theme.of(ctx).colorScheme;
    final total = widget.open + widget.resolved;
    return DraggableScrollableSheet(
      initialChildSize:0.78, minChildSize:0.5, maxChildSize:0.95,
      expand:false,
      builder:(ctx,scroll)=>Container(
        decoration:BoxDecoration(
          color:cs.background,
          borderRadius:const BorderRadius.vertical(top:Radius.circular(28))),
        child:ListView(
          controller:scroll,
          padding:const EdgeInsets.fromLTRB(24,0,24,36),
          children:[
            // Handle
            Center(child:Container(
              margin:const EdgeInsets.symmetric(vertical:12),
              width:40, height:4,
              decoration:BoxDecoration(
                  color:cs.outlineVariant,
                  borderRadius:BorderRadius.circular(2)))),

            // Avatar
            Center(child: Column(children: [
              Hero(
                tag: 'user_avatar',
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [cs.primary, const Color(0xFFEA580C)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    boxShadow: [BoxShadow(
                        color: cs.primary.withOpacity(0.35),
                        blurRadius: 20, offset: const Offset(0, 8))]),
                  child: Center(child: Text(
                    widget.userName.trim().isEmpty ? '?'
                        : widget.userName.trim().split(' ')
                            .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
                            .take(2).join(),
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w900, fontSize: 36,
                        letterSpacing: 0.5))))),
              const SizedBox(height: 16),
              Text(widget.userName.isNotEmpty ? widget.userName : 'Citizen Profile',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                      color: cs.onSurface, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(widget.userEmail,
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () { _snack('Refreshing profile...'); widget.onSaved(widget.userName, widget.userPhone, widget.userWard); },
                  icon: Icon(Icons.refresh_rounded, size: 18, color: cs.primary),
                  tooltip: 'Reload profile',
                ),
              ]),
            ])),
            const SizedBox(height: 24),

            // Stats
            Row(children: [
              _StatPill(value: '${widget.open}',     label: 'Open',     color: Colors.orange),
              const SizedBox(width: 12),
              _StatPill(value: '${widget.resolved}', label: 'Resolved', color: cs.tertiary),
              const SizedBox(width: 12),
              _StatPill(value: '$total',             label: 'Total',    color: cs.primary),
            ]),
            const SizedBox(height: 32),

            // Edit header
            Row(children: [
              Text('Profile Details',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface)),
              const Spacer(),
              if (!_editing)
                TextButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                        foregroundColor: cs.primary, padding: EdgeInsets.zero))
              else ...[
                TextButton(
                    onPressed: () => setState(() => _editing = false),
                    style: TextButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                        padding: EdgeInsets.zero),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: (_saving || _nameCtrl.text.trim().isEmpty) ? null : _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9)),
                    child: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Save',
                            style: TextStyle(fontWeight: FontWeight.w700))),
              ],
            ]),
            const SizedBox(height: 12),

            // Fields container
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
              ),
              child: Column(children: [
                _Field(
                    icon: Icons.person_outline_rounded,
                    label: 'Full Name',
                    ctrl: _nameCtrl,
                    editable: _editing,
                    keyboard: TextInputType.name),
                const _FieldDivider(),
                _FieldReadOnly(
                    icon: Icons.alternate_email_rounded,
                    label: 'Email',
                    value: widget.userEmail),
                const _FieldDivider(),
                _Field(
                    icon: Icons.phone_outlined,
                    label: 'Mobile',
                    ctrl: _phoneCtrl,
                    editable: _editing,
                    keyboard: TextInputType.phone,
                    prefix: '+91 '),
                const _FieldDivider(),
                _Field(
                    icon: Icons.location_city_outlined,
                    label: 'Ward No.',
                    ctrl: _wardCtrl,
                    editable: _editing,
                    keyboard: TextInputType.number),
              ]),
            ),
            const SizedBox(height: 14),

            // Email note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: cs.secondary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.secondary.withOpacity(0.2))),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: cs.secondary, size: 15),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Email cannot be changed. Contact admin to update.',
                        style: TextStyle(fontSize: 11, color: cs.secondary))),
              ]),
            ),
            const SizedBox(height: 22),

            // Logout
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: widget.onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatPill({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext ctx) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.15), width: 1.5),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color.withOpacity(0.7))),
          ]),
        ),
      );
}

class _Field extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController ctrl;
  final bool editable;
  final TextInputType? keyboard;
  final String? prefix;
  const _Field(
      {required this.icon,
      required this.label,
      required this.ctrl,
      required this.editable,
      this.keyboard,
      this.prefix});
  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(icon, color: cs.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
            child: TextField(
                controller: ctrl,
                enabled: editable,
                keyboardType: keyboard,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface),
                decoration: InputDecoration(
                    labelText: label,
                    prefixText: editable ? prefix : null,
                    labelStyle:
                        TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: cs.primary.withOpacity(0.5))),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12)))),
        if (editable)
          Icon(Icons.edit_rounded, size: 14, color: cs.primary.withOpacity(0.5)),
      ]),
    );
  }
}

class _FieldReadOnly extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _FieldReadOnly(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.05), shape: BoxShape.circle),
          child: Icon(icon, color: cs.primary.withOpacity(0.6), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withOpacity(0.7),
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withOpacity(0.8))),
            ])),
        Icon(Icons.lock_outline_rounded, size: 14, color: cs.outlineVariant),
      ]),
    );
  }
}

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();
  @override
  Widget build(BuildContext context) => Divider(
        height: 1, indent: 70, endIndent: 20, color: Colors.grey.shade100, thickness: 1.5);
}