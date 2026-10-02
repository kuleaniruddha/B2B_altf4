import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final _nameController     = TextEditingController();
  final _phoneController    = TextEditingController();
  final _emailController    = TextEditingController();
  final _wardController     = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  final _phoneFocus    = FocusNode();
  final _emailFocus    = FocusNode();
  final _wardFocus     = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus  = FocusNode();

  bool _isLoading   = false;
  bool _showPass    = false;
  bool _showConfirm = false;

  // ================= REGISTER =================
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final result = await _authService.register(
        name:     _nameController.text.trim(),
        phone:    _phoneController.text.trim(),
        email:    _emailController.text.trim(),
        wardNo:   _wardController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        _showSuccessDialog();
      } else {
        _snack(result['message'] ?? context.read<LanguageService>().translate('error_generic'), error: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack(context.read<LanguageService>().translate('error_generic'), error: true);
      debugPrint("Register exception: $e");
    }
  }

  void _showSuccessDialog() {
    final lang = context.read<LanguageService>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Green checkmark circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.green.shade600, size: 50),
            ),
            const SizedBox(height: 18),
            Text(
              lang.translate('account_created'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: "${lang.translate('account_success_msg')}\n\n"),
                  WidgetSpan(
                    child: Icon(LucideIcons.mail, size: 16, color: Theme.of(context).colorScheme.primary),
                    alignment: PlaceholderAlignment.middle,
                  ),
                  TextSpan(
                    text: " ${lang.translate('verification_sent_to')}\n"
                        "${_emailController.text.trim()}\n\n"
                        "${lang.translate('verify_before_login')}\n\n"
                        "${lang.translate('setup_mpin_desc')}",
                  ),
                ],
              ),
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacementNamed(context, '/mpin-setup');
                },
                child: Text(lang.translate('setup_mpin_btn'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, {required bool error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  InputDecoration _dec(String label, IconData icon,
      {Widget? suffix, String? prefixText}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        prefixText: prefixText,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade600, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      );

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _wardController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _wardFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(lang.translate('registration_title')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header ──────────────────────────────────────────
              Text(lang.translate('create_account'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                      color: Color(0xFFF97316))),
              const SizedBox(height: 4),
              Text(lang.translate('fill_details'),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 28),

              // ── Full Name ────────────────────────────────────────
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_phoneFocus),
                decoration: _dec(lang.translate('full_name'), Icons.person_outline),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return lang.translate('error_name_req');
                  if (v.trim().length < 2) return lang.translate('enter_valid_name');
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Mobile ──────────────────────────────────────────
              TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_emailFocus),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: _dec(lang.translate('mobile_number'), Icons.phone_outlined,
                    prefixText: "+91 "),
                validator: (v) {
                  if (v == null || v.isEmpty) return lang.translate('error_phone_req');
                  if (v.length != 10) return lang.translate('error_phone_invalid');
                  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v))
                    return lang.translate('error_phone_invalid');
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Email ────────────────────────────────────────────
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_wardFocus),
                decoration: _dec(lang.translate('email_address'), Icons.email_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return lang.translate('error_email_req');
                  if (!RegExp(r'^[\w\.\-]+@[\w\-]+\.\w{2,}$').hasMatch(v.trim()))
                    return lang.translate('error_email_invalid');
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Ward ─────────────────────────────────────────────
              TextFormField(
                controller: _wardController,
                focusNode: _wardFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_passwordFocus),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec(lang.translate('ward_number'), Icons.location_city_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return lang.translate('error_ward_req');
                  final ward = int.tryParse(v);
                  if (ward == null || ward < 1 || ward > 227)
                    return lang.translate('error_ward_invalid');
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Password ─────────────────────────────────────────
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: !_showPass,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_confirmFocus),
                decoration: _dec(lang.translate('password'), Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(_showPass
                          ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    )),
                validator: (v) {
                  if (v == null || v.isEmpty) return lang.translate('error_pass_req');
                  if (v.length < 6) return lang.translate('error_pass_too_short');
                  if (!RegExp(r'[A-Za-z]').hasMatch(v))
                    return lang.translate('error_pass_need_letter');
                  if (!RegExp(r'[0-9]').hasMatch(v))
                    return lang.translate('error_pass_need_number');
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Confirm Password ─────────────────────────────────
              TextFormField(
                controller: _confirmController,
                focusNode: _confirmFocus,
                obscureText: !_showConfirm,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _register(),
                decoration: _dec(lang.translate('confirm_password'), Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(_showConfirm
                          ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey),
                      onPressed: () =>
                          setState(() => _showConfirm = !_showConfirm),
                    )),
                validator: (v) {
                  if (v == null || v.isEmpty) return lang.translate('error_pass_confirm_req');
                  if (v != _passwordController.text) return lang.translate('error_pass_match');
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // ── Register Button ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            ),
                            const SizedBox(width: 12),
                            Text(lang.translate('creating_account'),
                                style: const TextStyle(fontSize: 15)),
                          ],
                        )
                      : Text(lang.translate('register_btn'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),

              // ── Login Link ───────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.pushReplacementNamed(context, '/login'),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: lang.translate('already_registered'),
                        style: const TextStyle(color: Colors.grey)),
                    TextSpan(text: lang.translate('login_btn'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700)),
                  ])),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}