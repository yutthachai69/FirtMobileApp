import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/auth/auth_controller.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.auth});
  final AuthController auth;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  late final AnimationController _entrance;
  late final AnimationController _modeMotion;
  late final AnimationController _modeSweep;
  late final AnimationController _signalMotion;
  late final AnimationController _submitPulse;
  bool _register = false;
  bool _sweepToRegister = true;
  bool _obscure = true;
  double _signalDestination = .06;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _modeMotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      value: 1,
    );
    _modeSweep = AnimationController(vsync: this, value: 1);
    _signalMotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: .06,
    );
    _submitPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: .96,
      upperBound: 1,
      value: 1,
    );
    _nameFocus.addListener(_refreshFormState);
    _emailFocus.addListener(_refreshFormState);
    _passwordFocus.addListener(_refreshFormState);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _modeMotion.dispose();
    _modeSweep.dispose();
    _signalMotion.dispose();
    _submitPulse.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _playSubmitPulse();
    _moveSignalTo(1);
    await widget.auth.authenticate(
      _email.text,
      _password.text,
      name: _register ? _name.text : null,
    );
    if (widget.auth.phase == SessionPhase.signedIn) {
      TextInput.finishAutofillContext();
    }
  }

  void _playSubmitPulse() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _submitPulse
      ..animateTo(.96, duration: const Duration(milliseconds: 70))
      ..forward(from: .96);
  }

  void _refreshFormState([String? _]) {
    if (!mounted) return;
    final emailValid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
        .hasMatch(_email.text.trim());
    final passwordLength = utf8.encode(_password.text).length;
    final complete =
        emailValid &&
        (_register
            ? _name.text.trim().isNotEmpty && passwordLength >= 8
            : _password.text.isNotEmpty);

    final target = complete
        ? .93
        : _nameFocus.hasFocus
        ? .12
        : _emailFocus.hasFocus
        ? (_register ? .34 : .18)
        : _passwordFocus.hasFocus
        ? .62
        : .06;
    _moveSignalTo(target);
  }

  void _onPasswordChanged(String _) {
    if (_register) setState(() {});
    _refreshFormState();
  }

  void _moveSignalTo(double target) {
    if ((_signalDestination - target).abs() < .001) return;
    _signalDestination = target;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _signalMotion.value = target;
      return;
    }
    final distance = (_signalMotion.value - target).abs();
    _signalMotion.animateTo(
      target,
      duration: Duration(milliseconds: 190 + (distance * 180).round()),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _toggleMode() async {
    if (_modeSweep.isAnimating) return;
    if (MediaQuery.of(context).disableAnimations) {
      _applyModeToggle();
      _modeMotion.value = 1;
      return;
    }

    _sweepToRegister = !_register;
    _modeSweep.value = 0;
    await _modeSweep.animateTo(
      .42,
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeInCubic,
    );
    if (!mounted) return;
    _applyModeToggle();
    _modeMotion.forward(from: 0);
    await _modeSweep.animateTo(
      1,
      duration: const Duration(milliseconds: 270),
      curve: Curves.easeOutCubic,
    );
  }

  void _applyModeToggle() {
    setState(() {
      _register = !_register;
      widget.auth.error = null;
      _password.clear();
      _signalDestination = .06;
      _signalMotion.value = .06;
      _form.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, _) {
      final auth = widget.auth;
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _AmbientPainter(
                    primary: context.t.primary,
                    border: context.t.border,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg,
                    vertical: Spacing.xl,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entrance,
                        curve: Curves.easeOut,
                      ),
                      child: SlideTransition(
                        position:
                            Tween(
                              begin: const Offset(0, .02),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _entrance,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: AutofillGroup(
                          child: Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _AnimatedBrand(
                                  animation: _modeSweep,
                                  toRegister: _sweepToRegister,
                                ),
                                const SizedBox(height: Spacing.lg),
                                _AuthWelcome(register: _register),
                                const SizedBox(height: Spacing.lg),
                                _AuthModeSwitch(
                                  register: _register,
                                  onChanged: auth.busy
                                      ? null
                                      : (register) {
                                          if (register != _register) {
                                            _toggleMode();
                                          }
                                        },
                                ),
                                const SizedBox(height: Spacing.lg),
                                FadeTransition(
                                  opacity: CurvedAnimation(
                                    parent: _modeMotion,
                                    curve: const Interval(
                                      .12,
                                      1,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                                  child: ScaleTransition(
                                    alignment: Alignment.topCenter,
                                    scale: Tween(begin: .99, end: 1.0).animate(
                                      CurvedAnimation(
                                        parent: _modeMotion,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    ),
                                    child: SlideTransition(
                                      position:
                                          Tween(
                                            begin: Offset(
                                              _register ? .055 : -.055,
                                              0,
                                            ),
                                            end: Offset.zero,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: _modeMotion,
                                              curve: Curves.easeOutCubic,
                                            ),
                                          ),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: -18,
                                            top: 2,
                                            bottom: 2,
                                            width: 12,
                                            child: IgnorePointer(
                                              child: RepaintBoundary(
                                                child: AnimatedBuilder(
                                                  animation: _signalMotion,
                                                  builder: (context, _) =>
                                                      CustomPaint(
                                                        painter:
                                                            _SignalTrailPainter(
                                                              progress:
                                                                  _signalMotion
                                                                      .value,
                                                              color: context
                                                                  .t
                                                                  .primary,
                                                            ),
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _ModeReveal(
                                                animation: _modeMotion,
                                                index: 0,
                                                forward: _register,
                                                child: AnimatedSize(
                                                  duration: const Duration(
                                                    milliseconds: 260,
                                                  ),
                                                  curve: Curves.easeOutCubic,
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child: _register
                                                      ? Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                bottom:
                                                                    Spacing.md,
                                                              ),
                                                          child: TextFormField(
                                                            key: const Key(
                                                              'display-name',
                                                            ),
                                                            controller: _name,
                                                            focusNode:
                                                                _nameFocus,
                                                            enabled: !auth.busy,
                                                            decoration:
                                                                const InputDecoration(
                                                                  labelText: 'ชื่อที่ใช้แสดง',
                                                                  prefixIcon: Icon(
                                                                    Icons
                                                                        .person_outline_rounded,
                                                                  ),
                                                                  counterText:
                                                                      '',
                                                                ),
                                                            autofillHints:
                                                                const [
                                                                  AutofillHints
                                                                      .name,
                                                                ],
                                                            textInputAction:
                                                                TextInputAction
                                                                    .next,
                                                            maxLength: 100,
                                                            onChanged:
                                                                _refreshFormState,
                                                            validator: (value) =>
                                                                value
                                                                        ?.trim()
                                                                        .isNotEmpty ==
                                                                    true
                                                                ? null
                                                                : 'กรุณากรอกชื่อที่ใช้แสดง',
                                                          ),
                                                        )
                                                      : const SizedBox.shrink(),
                                                ),
                                              ),
                                              _ModeReveal(
                                                animation: _modeMotion,
                                                index: 1,
                                                forward: _register,
                                                child: TextFormField(
                                                  key: const Key('email'),
                                                  controller: _email,
                                                  focusNode: _emailFocus,
                                                  enabled: !auth.busy,
                                                  decoration: const InputDecoration(
                                                    labelText: 'อีเมล',
                                                    prefixIcon: Icon(
                                                      Icons
                                                          .mail_outline_rounded,
                                                    ),
                                                  ),
                                                  keyboardType: TextInputType
                                                      .emailAddress,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  autofillHints: const [
                                                    AutofillHints.email,
                                                  ],
                                                  autocorrect: false,
                                                  onChanged: _refreshFormState,
                                                  validator: (value) =>
                                                      RegExp(
                                                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                                      ).hasMatch(
                                                        value?.trim() ?? '',
                                                      )
                                                      ? null
                                                      : 'กรุณากรอกอีเมลให้ถูกต้อง',
                                                ),
                                              ),
                                              const SizedBox(
                                                height: Spacing.md,
                                              ),
                                              _ModeReveal(
                                                animation: _modeMotion,
                                                index: 2,
                                                forward: _register,
                                                child: TextFormField(
                                                  key: const Key('password'),
                                                  controller: _password,
                                                  focusNode: _passwordFocus,
                                                  enabled: !auth.busy,
                                                  decoration: InputDecoration(
                                                    labelText: 'รหัสผ่าน',
                                                    prefixIcon: const Icon(
                                                      Icons
                                                          .lock_outline_rounded,
                                                    ),
                                                    suffixIcon: IconButton(
                                                      onPressed: auth.busy
                                                          ? null
                                                          : () => setState(
                                                              () => _obscure =
                                                                  !_obscure,
                                                            ),
                                                      tooltip: _obscure
                                                          ? 'แสดงรหัสผ่าน'
                                                          : 'ซ่อนรหัสผ่าน',
                                                      icon: Icon(
                                                        _obscure
                                                            ? Icons
                                                                  .visibility_outlined
                                                            : Icons
                                                                  .visibility_off_outlined,
                                                      ),
                                                    ),
                                                  ),
                                                  obscureText: _obscure,
                                                  autocorrect: false,
                                                  enableSuggestions: false,
                                                  autofillHints: [
                                                    _register
                                                        ? AutofillHints
                                                              .newPassword
                                                        : AutofillHints
                                                              .password,
                                                  ],
                                                  textInputAction:
                                                      TextInputAction.done,
                                                  onChanged: _onPasswordChanged,
                                                  onFieldSubmitted: (_) {
                                                    if (!auth.busy) _submit();
                                                  },
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      return 'กรุณากรอกรหัสผ่าน';
                                                    }
                                                    if (_register &&
                                                        utf8
                                                                .encode(value)
                                                                .length <
                                                            8) {
                                                      return 'รหัสผ่านต้องยาวอย่างน้อย 8 ตัวอักษร';
                                                    }
                                                    if (_register &&
                                                        utf8
                                                                .encode(value)
                                                                .length >
                                                            72) {
                                                      return 'รหัสผ่านยาวเกินไป กรุณาลดจำนวนตัวอักษร';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                              _ModeReveal(
                                                animation: _modeMotion,
                                                index: 3,
                                                forward: _register,
                                                child: _register
                                                    ? _PasswordChecks(
                                                        value: _password.text,
                                                      )
                                                    : Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: TextButton(
                                                          key: const Key(
                                                            'forgot-password',
                                                          ),
                                                          onPressed: auth.busy
                                                              ? null
                                                              : _showForgotPassword,
                                                          child: const Text(
                                                            'ลืมรหัสผ่าน?',
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                              AnimatedSize(
                                                duration: const Duration(
                                                  milliseconds: 220,
                                                ),
                                                child: auth.error == null
                                                    ? const SizedBox.shrink()
                                                    : Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: Spacing.md,
                                                            ),
                                                        child: _ErrorNotice(
                                                          auth.error!,
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(
                                                height: Spacing.lg,
                                              ),
                                              _ModeReveal(
                                                animation: _modeMotion,
                                                index: 4,
                                                forward: _register,
                                                child: SizedBox(
                                                  height: 52,
                                                  width: double.infinity,
                                                  child: ScaleTransition(
                                                    scale: _submitPulse,
                                                    child: FilledButton(
                                                      key: const Key('submit'),
                                                      onPressed: auth.busy
                                                          ? null
                                                          : _submit,
                                                      child: AnimatedSwitcher(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 180,
                                                            ),
                                                        child: auth.busy
                                                            ? const Row(
                                                                key: ValueKey(
                                                                  'sending',
                                                                ),
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  SizedBox(
                                                                    width: 18,
                                                                    height: 18,
                                                                    child: CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    width:
                                                                        Spacing
                                                                            .sm,
                                                                  ),
                                                                  Text(
                                                                    'กำลังส่งต่อ…',
                                                                  ),
                                                                ],
                                                              )
                                                            : Row(
                                                                key:
                                                                    const ValueKey(
                                                                      'ready',
                                                                    ),
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Text(
                                                                    _register
                                                                        ? 'สร้างบัญชี'
                                                                        : 'เข้าสู่ระบบ',
                                                                  ),
                                                                  const SizedBox(
                                                                    width:
                                                                        Spacing
                                                                            .sm,
                                                                  ),
                                                                  _RelayArrow(
                                                                    animation:
                                                                        _modeMotion,
                                                                    size: 19,
                                                                  ),
                                                                ],
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (MediaQuery.sizeOf(context)
                                                          .height >
                                                      700 &&
                                                  MediaQuery.viewInsetsOf(
                                                        context,
                                                      ).bottom ==
                                                      0) ...[
                                                const SizedBox(
                                                  height: Spacing.lg,
                                                ),
                                                Center(
                                                  child: Text(
                                                    'สร้าง  •  ตั้งเวลา  •  เผยแพร่',
                                                    style: TextStyle(
                                                      color: context
                                                          .t
                                                          .textSecondary,
                                                      fontSize: 12,
                                                      letterSpacing: .4,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _modeSweep,
                    builder: (context, _) => CustomPaint(
                      painter: _AuthModeSweepPainter(
                        progress: _modeSweep.value,
                        toRegister: _sweepToRegister,
                        color: context.t.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _showForgotPassword() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ForgotPasswordSheet(initialEmail: _email.text),
  );
}

class _ModeReveal extends StatelessWidget {
  const _ModeReveal({
    required this.animation,
    required this.index,
    required this.forward,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final bool forward;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final start = index * .085;
        final end = math.min(1.0, .64 + index * .085);
        final raw = ((animation.value - start) / (end - start)).clamp(0.0, 1.0);
        final progress = Curves.easeOutCubic.transform(raw);
        final direction = forward ? 1.0 : -1.0;

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(
              direction * (1 - progress) * (12 + index * 2.5),
              (1 - progress) * 3,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _RelayArrow extends StatelessWidget {
  const _RelayArrow({required this.animation, required this.size});

  final Animation<double> animation;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Icon(Icons.arrow_forward_rounded, size: size);
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final raw = ((animation.value - .66) / .34).clamp(0.0, 1.0);
        final handoff = math.sin(math.pi * raw);
        return Transform.translate(
          offset: Offset(5 * handoff, 0),
          child: Icon(Icons.arrow_forward_rounded, size: size),
        );
      },
    );
  }
}

class _AuthWelcome extends StatelessWidget {
  const _AuthWelcome({required this.register});

  final bool register;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 280),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: Offset(register ? .06 : -.06, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: Column(
      key: ValueKey(register),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          register ? 'สร้างบัญชีของคุณ' : 'ยินดีต้อนรับกลับ',
          style: const TextStyle(
            fontSize: 28,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          register
              ? 'เริ่มจัดการและวางแผนคอนเทนต์ได้ในที่เดียว'
              : 'เข้าสู่ระบบเพื่อจัดการคอนเทนต์ของคุณ',
          style: TextStyle(
            color: context.t.textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    ),
  );
}

class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({required this.register, required this.onChanged});

  final bool register;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.t;
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 340);

    return Semantics(
      label: 'เลือกเข้าสู่ระบบหรือสมัครสมาชิก',
      child: Container(
        key: const Key('auth-mode-switch'),
        height: 52,
        padding: const EdgeInsets.all(Spacing.xs),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tokens.surfaceContainer,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: tokens.border),
        ),
        child: Stack(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: register ? 1 : 0),
              duration: duration,
              curve: Curves.easeInOutCubic,
              builder: (context, progress, _) => CustomPaint(
                painter: _AuthModeIndicatorPainter(
                  progress: progress,
                  color: tokens.primary,
                  glow: tokens.primary.withValues(alpha: .18),
                ),
                child: const SizedBox.expand(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _ModeTab(
                    key: const Key('auth-login-tab'),
                    icon: Icons.login_rounded,
                    label: 'เข้าสู่ระบบ',
                    selected: !register,
                    onTap: onChanged == null ? null : () => onChanged!(false),
                  ),
                ),
                Expanded(
                  child: _ModeTab(
                    key: const Key('auth-register-tab'),
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'สมัครสมาชิก',
                    selected: register,
                    onTap: onChanged == null ? null : () => onChanged!(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Center(
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          scale: selected ? 1 : .96,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            style: TextStyle(
              color: selected ? context.t.onPrimary : context.t.textSecondary,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              fontWeight: FontWeight.w600,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconTheme(
                    data: IconThemeData(
                      color: selected
                          ? context.t.onPrimary
                          : context.t.textSecondary,
                      size: 17,
                    ),
                    child: Icon(icon),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text(label),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AuthModeIndicatorPainter extends CustomPainter {
  const _AuthModeIndicatorPainter({
    required this.progress,
    required this.color,
    required this.glow,
  });

  final double progress;
  final Color color;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    double x(double from, double to) =>
        size.width * (from + (to - from) * progress);

    final path = Path()
      ..moveTo(x(0, .52), 0)
      ..lineTo(x(.56, 1), 0)
      ..lineTo(x(.48, 1), size.height)
      ..lineTo(x(0, .44), size.height)
      ..close();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
    );
    canvas.drawShadow(path, glow, 8, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AuthModeIndicatorPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.glow != glow;
}

class _SignalTrailPainter extends CustomPainter {
  const _SignalTrailPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final top = 3.0;
    final bottom = size.height - 3;
    final y = top + (bottom - top) * progress;

    canvas.drawLine(
      Offset(x, top),
      Offset(x, bottom),
      Paint()
        ..color = color.withValues(alpha: .18)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(x, top),
      Offset(x, y),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .12), color.withValues(alpha: .86)],
        ).createShader(Rect.fromLTRB(0, top, size.width, math.max(top + 1, y)))
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(x, y),
      10,
      Paint()..color = color.withValues(alpha: .14),
    );
    canvas.drawCircle(Offset(x, y), 3.1, Paint()..color = color);
    canvas.drawCircle(
      Offset(x, y),
      5.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: .56),
    );
  }

  @override
  bool shouldRepaint(_SignalTrailPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _AuthModeSweepPainter extends CustomPainter {
  const _AuthModeSweepPainter({
    required this.progress,
    required this.toRegister,
    required this.color,
  });

  final double progress;
  final bool toRegister;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= .999) return;

    final forwardCenter = progress <= .42
        ? -.45 + .95 * (progress / .42)
        : .5 + (progress - .42) / .58;
    final center =
        size.width * (toRegister ? forwardCenter : 1 - forwardCenter);
    final halfBand = size.width * .36;
    final slant = math.min(size.width * .32, size.height * .14);
    final path = Path()
      ..moveTo(center - halfBand - slant, 0)
      ..lineTo(center + halfBand - slant, 0)
      ..lineTo(center + halfBand + slant, size.height)
      ..lineTo(center - halfBand + slant, size.height)
      ..close();
    final strength = math.sin(math.pi * progress);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: .025 * strength),
          color.withValues(alpha: .19 * strength),
          color.withValues(alpha: .055 * strength),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);

    canvas.drawLine(
      Offset(center - slant, 0),
      Offset(center + slant, size.height),
      Paint()
        ..color = color.withValues(alpha: .32 * strength)
        ..strokeWidth = 1.5,
    );

    final packet = Offset(center, size.height * .5);
    canvas.drawCircle(
      packet,
      18,
      Paint()..color = color.withValues(alpha: .12 * strength),
    );
    canvas.drawCircle(
      packet,
      5,
      Paint()..color = color.withValues(alpha: .72 * strength),
    );
    final trail = Offset(center + (toRegister ? -34 : 34), size.height * .5);
    canvas.drawCircle(
      trail,
      10,
      Paint()..color = color.withValues(alpha: .08 * strength),
    );
    canvas.drawCircle(
      trail,
      2.5,
      Paint()..color = color.withValues(alpha: .42 * strength),
    );
  }

  @override
  bool shouldRepaint(_AuthModeSweepPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.toRegister != toRegister ||
      oldDelegate.color != color;
}

class _PasswordChecks extends StatelessWidget {
  const _PasswordChecks({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final longEnough = utf8.encode(value).length >= 8;
    final hasNumber = RegExp(r'\d').hasMatch(value);
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        children: [
          _Check(text: 'อย่างน้อย 8 ตัว', passed: longEnough),
          const SizedBox(width: 12),
          _Check(text: 'มีตัวเลข', passed: hasNumber),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.text, required this.passed});
  final String text;
  final bool passed;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        passed ? Icons.check_circle_rounded : Icons.circle_outlined,
        size: 15,
        color: passed ? context.t.success : context.t.textSecondary,
      ),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: passed ? context.t.success : context.t.textSecondary,
        ),
      ),
    ],
  );
}

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet({required this.initialEmail});
  final String initialEmail;

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final TextEditingController email = TextEditingController(
    text: widget.initialEmail,
  );
  String? error;
  bool sent = false;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      Spacing.lg,
      0,
      Spacing.lg,
      MediaQuery.viewInsetsOf(context).bottom + Spacing.lg,
    ),
    child: sent
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                size: 54,
                color: context.t.success,
              ),
              const SizedBox(height: 12),
              const Text(
                'ส่งลิงก์เรียบร้อย',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'ตรวจกล่องข้อความของ ${email.text.trim()}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('กลับไปเข้าสู่ระบบ'),
                ),
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ตั้งรหัสผ่านใหม่',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                'เราจะส่งลิงก์ตั้งรหัสผ่านใหม่ไปยังอีเมลของคุณ',
                style: TextStyle(color: context.t.textSecondary),
              ),
              const SizedBox(height: Spacing.lg),
              TextField(
                key: const Key('reset-email'),
                controller: email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'อีเมล',
                  errorText: error,
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: Spacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('send-reset'),
                  onPressed: () {
                    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(email.text.trim());
                    if (!valid) {
                      setState(() => error = 'กรุณากรอกอีเมลให้ถูกต้อง');
                    } else {
                      FocusScope.of(context).unfocus();
                      setState(() => sent = true);
                    }
                  },
                  child: const Text('ส่งลิงก์ตั้งรหัสผ่าน'),
                ),
              ),
            ],
          ),
  );
}

class _AnimatedBrand extends StatelessWidget {
  const _AnimatedBrand({required this.animation, required this.toRegister});

  final Animation<double> animation;
  final bool toRegister;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: const _Brand(),
    builder: (context, child) {
      final pulse = math.sin(math.pi * animation.value);
      final direction = toRegister ? 1.0 : -1.0;
      return Transform.translate(
        offset: Offset(direction * 5 * pulse, 0),
        child: Transform.rotate(
          angle: direction * .055 * pulse,
          child: Transform.scale(scale: 1 + .035 * pulse, child: child),
        ),
      );
    },
  );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: context.t.primary,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: context.t.primary.withValues(alpha: .22),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: CustomPaint(painter: _RelayLogoPainter(context.t.onPrimary)),
      ),
      const SizedBox(width: 12),
      const Text(
        'RelayContent',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.t.error.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: context.t.error.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: context.t.error, size: 20),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.t.error, height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RelayLogoPainter extends CustomPainter {
  const _RelayLogoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(12, 16)
      ..lineTo(23, 10)
      ..lineTo(34, 16)
      ..lineTo(23, 22)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
      Path()
        ..moveTo(12, 23)
        ..lineTo(23, 29)
        ..lineTo(34, 23),
      paint,
    );
    canvas.drawCircle(const Offset(12, 23), 2.2, Paint()..color = color);
    canvas.drawCircle(const Offset(34, 23), 2.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RelayLogoPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({required this.primary, required this.border});
  final Color primary;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              primary.withValues(alpha: .1),
              primary.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .82, size.height * .1),
              radius: math.min(size.width, 520) * .6,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);

    final dot = Paint()..color = border.withValues(alpha: .45);
    for (double y = 54; y < size.height; y += 38) {
      for (double x = 18; x < size.width; x += 38) {
        if (x > size.width * .56 && y < size.height * .28) {
          canvas.drawCircle(Offset(x, y), 1, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) =>
      primary != oldDelegate.primary || border != oldDelegate.border;
}
