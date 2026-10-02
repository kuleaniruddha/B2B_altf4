import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';

class MpinSetupScreen extends StatefulWidget {
  const MpinSetupScreen({super.key});

  @override
  State<MpinSetupScreen> createState() => _MpinSetupScreenState();
}

class _MpinSetupScreenState extends State<MpinSetupScreen> {
  final AuthService _authService = AuthService();

  final List<String> _pin     = [];
  final List<String> _confirm = [];
  bool _isConfirmStep = false;
  bool _isSaving      = false;
  String? _errorText;

  void _onKeyTap(String val) {
    // Guard: ignore empty string (placeholder key)
    if (val.isEmpty) return;

    setState(() {
      _errorText = null;
      final current = _isConfirmStep ? _confirm : _pin;

      if (current.length < 4) {
        current.add(val);
      }

      // Auto-proceed to confirm step after 4 digits
      if (!_isConfirmStep && _pin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _isConfirmStep = true);
        });
        return;
      }

      // Auto-submit after confirm step has 4 digits
      if (_isConfirmStep && _confirm.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _submitMpin();
        });
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _errorText = null;
      if (_isConfirmStep) {
        if (_confirm.isNotEmpty) _confirm.removeLast();
      } else {
        if (_pin.isNotEmpty) _pin.removeLast();
      }
    });
  }

  void _resetToFirst() {
    setState(() {
      _pin.clear();
      _confirm.clear();
      _isConfirmStep = false;
      _errorText = null;
    });
  }

  Future<void> _submitMpin() async {
    if (_pin.length != 4 || _confirm.length != 4) return;

    if (_pin.join() != _confirm.join()) {
      setState(() {
        _errorText = "PINs don't match. Please try again.";
        _confirm.clear();
        // Stay on confirm step so user retries confirm only
      });
      return;
    }

    setState(() => _isSaving = true);
    await _authService.saveMPIN(_pin.join());
    setState(() => _isSaving = false);

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: 16),
            Text(
              "All Done!",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            Text(
              "Your MPIN has been set successfully.\n\n"
              "Please verify your email before logging in.",
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
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text("Go to Login",
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dot indicators ───────────────────────────────────────────────
  Widget _buildDots(List<String> pin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Theme.of(context).colorScheme.primary : Colors.transparent,
            border: Border.all(
              color: filled
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  // ── Number key ───────────────────────────────────────────────────
  Widget _numKey(String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onKeyTap(label),
        child: Container(
          margin: const EdgeInsets.all(6),
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface)),
          ),
        ),
      ),
    );
  }

  // ── Backspace key ────────────────────────────────────────────────
  Widget _backspaceKey() {
    return Expanded(
      child: GestureDetector(
        onTap: _onBackspace,
        child: Container(
          margin: const EdgeInsets.all(6),
          height: 64,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(Icons.backspace_outlined,
                color: Theme.of(context).colorScheme.primary, size: 22),
          ),
        ),
      ),
    );
  }

  // ── Empty placeholder (no tap) ───────────────────────────────────
  Widget _emptyKey() {
    return const Expanded(child: SizedBox(height: 64));
  }

  @override
  Widget build(BuildContext context) {
    final current = _isConfirmStep ? _confirm : _pin;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text("Set MPIN"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [

            // ── Step chips ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stepChip("1. Create PIN", !_isConfirmStep),
                const SizedBox(width: 12),
                _stepChip("2. Confirm PIN", _isConfirmStep),
              ],
            ),
            const SizedBox(height: 40),

            // ── Title ───────────────────────────────────────────────
            Text(
              _isConfirmStep ? "Confirm your MPIN" : "Create your MPIN",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              _isConfirmStep
                  ? "Re-enter the 4-digit PIN you just set"
                  : "This PIN will be used for quick login",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // ── Dots ────────────────────────────────────────────────
            _buildDots(current),
            const SizedBox(height: 20),

            // ── Error message ───────────────────────────────────────
            if (_errorText != null) ...[
              Text(
                _errorText!,
                style: TextStyle(
                    color: Colors.red.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _resetToFirst,
                child: Text("Start over",
                    style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              ),
            ],

            const Spacer(),

            // ── Keypad ──────────────────────────────────────────────
            if (_isSaving)
              CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)
            else ...[
              Row(children: [
                _numKey('1'), _numKey('2'), _numKey('3'),
              ]),
              Row(children: [
                _numKey('4'), _numKey('5'), _numKey('6'),
              ]),
              Row(children: [
                _numKey('7'), _numKey('8'), _numKey('9'),
              ]),
              Row(children: [
                _emptyKey(),   // ← proper empty widget, no onTap
                _numKey('0'),
                _backspaceKey(),
              ]),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _stepChip(String label, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: active ? Colors.white : Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}