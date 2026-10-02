import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Mumbai news articles data
const List<Map<String, dynamic>> _mumbaiNews = [
  {
    'tag': 'infrastructure',
    'title': 'news_coastal_road',
    'desc': 'news_coastal_desc',
    'icon': LucideIcons.map,
    'color': '0xFF1565C0',
  },
  {
    'tag': 'environment',
    'title': 'news_trees',
    'desc': 'news_trees_desc',
    'icon': LucideIcons.trees,
    'color': '0xFF2E7D32',
  },
  {
    'tag': 'transport',
    'title': 'news_metro',
    'desc': 'news_metro_desc',
    'icon': LucideIcons.train,
    'color': '0xFF6A1B9A',
  },
  {
    'tag': 'civic',
    'title': 'news_dustbins',
    'desc': 'news_dustbins_desc',
    'icon': LucideIcons.trash2,
    'color': '0xFF00695C',
  },
  {
    'tag': 'safety',
    'title': 'news_cctv',
    'desc': 'news_cctv_desc',
    'icon': LucideIcons.video,
    'color': '0xFFB71C1C',
  },
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _scrollController   = ScrollController();
  final _pageController     = PageController(viewportFraction: 0.88);

  bool _showPassword       = false;
  bool _isCheckingSession  = true;
  bool _isLoggingIn        = false;
  int  _currentNewsPage    = 0;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _fadeAnim = CurvedAnimation(
        parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _slideController, curve: Curves.easeOutCubic));

    _checkSession();
  }

  Future<void> _checkSession() async {
    final loggedIn = await _authService.isLoggedIn();
    if (!mounted) return;
    if (loggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }
    setState(() => _isCheckingSession = false);
  }

  Future<void> _login() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    final lang = context.read<LanguageService>();
    if (email.isEmpty) { _snack(lang.translate('error_email_req'), error: true); return; }
    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _snack(lang.translate('error_email_invalid'), error: true); return;
    }
    if (password.isEmpty) { _snack(lang.translate('error_pass_req'), error: true); return; }

    setState(() => _isLoggingIn = true);
    final result = await _authService.login(email: email, password: password);
    setState(() => _isLoggingIn = false);
    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      final message = result['message'] as String;
      if (message.contains('not verified')) {
        _showVerificationDialog(email, password);
      } else {
        _snack(message, error: true);
      }
    }
  }
  void _showVerificationDialog(String email, String password) {
    final lang = context.read<LanguageService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang.translate('email_not_verified')),
        content: Text(lang.translate('check_inbox_desc')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.translate('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              final sent = await _authService.resendVerificationEmail(email, password);
              if (!mounted) return;
              _snack(sent ? lang.translate('email_resent') : lang.translate('resend_failed'),
                  error: !sent);
            },
            child: Text(lang.translate('resend_email')),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final lang = context.read<LanguageService>();
    final resetController = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang.translate('reset_password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lang.translate('reset_desc')),
            const SizedBox(height: 16),
            TextField(
              controller: resetController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: lang.translate('email_address'),
                prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).colorScheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.translate('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              final e = resetController.text.trim();
              Navigator.pop(ctx);
              if (e.isEmpty) { _snack(lang.translate('error_email_req'), error: true); return; }
              final sent = await _authService.sendPasswordResetEmail(e);
              if (!mounted) return;
              _snack(sent ? lang.translate('reset_sent') : lang.translate('reset_failed'),
                  error: !sent);
            },
            child: Text(lang.translate('send_link')),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // ── News Card ────────────────────────────────────────────────────
  Widget _newsCard(Map<String, dynamic> item, int index) {
    final color = Color(int.parse(item['color']!));
    return Container(
      margin: const EdgeInsets.only(right: 4, bottom: 4, top: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Accent bar
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(width: 5, color: color),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Icon(item['icon'] as IconData, color: color, size: 20),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                        child: Text(context.watch<LanguageService>().translate(item['tag']!),
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(context.watch<LanguageService>().translate(item['title']!),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.3)),
                  const SizedBox(height: 6),
                  Text(context.watch<LanguageService>().translate(item['desc']!),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Input field ──────────────────────────────────────────────────
  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction inputAction = TextInputAction.next,
    VoidCallback? onSubmit,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: inputAction,
        onSubmitted: onSubmit != null ? (_) => onSubmit() : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 14),
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          suffixIcon: suffix,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    if (_isCheckingSession) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
            child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
            controller: _scrollController,
            slivers: [

              // ── Hero Header ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    // Gradient background
                    Container(
                      height: 260,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(36),
                          bottomRight: Radius.circular(36),
                        ),
                      ),
                    ),

                    // Decorative circles
                    Positioned(
                      top: -40, right: -30,
                      child: Container(
                        width: 160, height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.07),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 60, right: 40,
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20, left: -20,
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo row
                          Row(children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.35),
                                    width: 1.5),
                              ),
                              child: const Icon(Icons.location_city_rounded,
                                  color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Smart Civic Mumbai",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3)),
                                Text("स्मार्ट सिविक मुंबई",
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.75),
                                        fontSize: 11)),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3)),
                              ),
                              child: const Text("BMC",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1)),
                            ),
                          ]),

                          const SizedBox(height: 28),

                          Row(
                            children: [
                              Text(context.watch<LanguageService>().translate('welcome_back'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                      letterSpacing: 0.2)),
                              const SizedBox(width: 12),
                              Icon(LucideIcons.sparkles,
                                  color: Colors.white.withOpacity(0.9), size: 28),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(context.watch<LanguageService>().translate('login_subtitle'),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Login Form Card ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.watch<LanguageService>().translate('login_btn'),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFF97316))),
                        const SizedBox(height: 4),
                        Text(context.watch<LanguageService>().translate('enter_credentials'),
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500)),
                        const SizedBox(height: 20),

                        // Email
                        _inputField(
                          controller: _emailController,
                          label: context.watch<LanguageService>().translate('email_address'),
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          inputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),

                        // Password
                        _inputField(
                          controller: _passwordController,
                          label: context.watch<LanguageService>().translate('password'),
                          icon: Icons.lock_outline,
                          obscure: !_showPassword,
                          inputAction: TextInputAction.done,
                          onSubmit: _login,
                          suffix: IconButton(
                            icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey.shade400,
                                size: 20),
                            onPressed: () => setState(
                                () => _showPassword = !_showPassword),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            child: Text(context.watch<LanguageService>().translate('forgot_pass'),
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: _isLoggingIn ? null : _login,
                            child: _isLoggingIn
                                ? Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 20, width: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(context.watch<LanguageService>().translate('signing_in'),
                                          style: const TextStyle(fontSize: 15)),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(context.watch<LanguageService>().translate('login_btn'),
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded,
                                          size: 18),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Register link
                        Center(
                          child: TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/signup'),
                            child: Text.rich(TextSpan(children: [
                              TextSpan(
                                  text: context.watch<LanguageService>().translate('new_citizen'),
                                  style: const TextStyle(color: Colors.grey)),
                              TextSpan(
                                  text: context.watch<LanguageService>().translate('register_here'),
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w700)),
                            ])),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Mumbai News Section ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 4, height: 20,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(context.watch<LanguageService>().translate('mumbai_today'),
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E))),
                      const Spacer(),
                      Text(context.watch<LanguageService>().translate('mumbai_news'),
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ),

              // News cards PageView
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 175,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _mumbaiNews.length,
                    onPageChanged: (i) =>
                        setState(() => _currentNewsPage = i),
                    itemBuilder: (ctx, i) =>
                        _newsCard(_mumbaiNews[i], i),
                    padEnds: false,
                  ),
                ),
              ),

              // Page dots
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_mumbaiNews.length, (i) {
                      final active = i == _currentNewsPage;
                      return Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // ── Quick Stats Strip ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(children:[
                    _statPill(LucideIcons.building2, "24", context.watch<LanguageService>().translate('wards')),
                    const SizedBox(width: 10),
                    _statPill(LucideIcons.clipboardCheck, "12K+", context.watch<LanguageService>().translate('issues_resolved')),
                    const SizedBox(width: 10),
                    _statPill(LucideIcons.zap, "48h", context.watch<LanguageService>().translate('avg_response')),
                  ]),
                ),
              ),

              // ── Footer ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Center(
                    child: Text(
                      context.watch<LanguageService>().translate('bmc_footer'),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _statPill(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    height: 1.3)),
          ],
        ),
      ),
    );
  }
}