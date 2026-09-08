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

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  late final AnimationController _entrance;
  bool _register = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _emailFocus.addListener(_refreshJourney);
    _passwordFocus.addListener(_refreshJourney);
  }

  void _refreshJourney() => setState(() {});

  @override
  void dispose() {
    _entrance.dispose();
    _emailFocus
      ..removeListener(_refreshJourney)
      ..dispose();
    _passwordFocus
      ..removeListener(_refreshJourney)
      ..dispose();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await widget.auth.authenticate(
      _email.text,
      _password.text,
      name: _register ? _name.text : null,
    );
    if (widget.auth.phase == SessionPhase.signedIn) {
      TextInput.finishAutofillContext();
    }
  }

  double _journeyProgress(bool busy) {
    if (busy) return 1;
    if (_passwordFocus.hasFocus || _password.text.isNotEmpty) return .68;
    if (_emailFocus.hasFocus || _email.text.isNotEmpty) return .34;
    return .08;
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
                              begin: const Offset(0, .035),
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
                                const _Brand(),
                                const SizedBox(height: Spacing.lg),
                                if (MediaQuery.sizeOf(context).height >
                                    700) ...[
                                  _RelayJourney(
                                    progress: _journeyProgress(auth.busy),
                                    busy: auth.busy,
                                  ),
                                  const SizedBox(height: Spacing.lg),
                                ],
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 240),
                                  child: Column(
                                    key: ValueKey(_register),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _register
                                            ? 'เริ่มส่งต่อไอเดียของคุณ'
                                            : 'กลับมาส่งไอเดียต่อ',
                                        style: const TextStyle(
                                          fontSize: 29,
                                          fontWeight: FontWeight.w700,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: Spacing.sm),
                                      Text(
                                        _register
                                            ? 'สร้างบัญชี แล้วให้ทุกโพสต์เดินทางตรงเวลา'
                                            : 'งานที่ตั้งเวลาไว้ยังเดินหน้าต่อ แม้คุณปิดแอป',
                                        style: TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          color: context.t.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: Spacing.lg),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  child: _register
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: Spacing.md,
                                          ),
                                          child: TextFormField(
                                            key: const Key('display-name'),
                                            controller: _name,
                                            enabled: !auth.busy,
                                            decoration: const InputDecoration(
                                              labelText: 'ชื่อที่ใช้แสดง',
                                              prefixIcon: Icon(
                                                Icons.person_outline_rounded,
                                              ),
                                              counterText: '',
                                            ),
                                            autofillHints: const [
                                              AutofillHints.name,
                                            ],
                                            textInputAction:
                                                TextInputAction.next,
                                            maxLength: 100,
                                            validator: (value) =>
                                                value?.trim().isNotEmpty == true
                                                ? null
                                                : 'กรุณากรอกชื่อที่ใช้แสดง',
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                TextFormField(
                                  key: const Key('email'),
                                  controller: _email,
                                  focusNode: _emailFocus,
                                  enabled: !auth.busy,
                                  decoration: const InputDecoration(
                                    labelText: 'อีเมล',
                                    prefixIcon: Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  autocorrect: false,
                                  onChanged: (_) => setState(() {}),
                                  validator: (value) =>
                                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                          .hasMatch(value?.trim() ?? '')
                                      ? null
                                      : 'กรุณากรอกอีเมลให้ถูกต้อง',
                                ),
                                const SizedBox(height: Spacing.md),
                                TextFormField(
                                  key: const Key('password'),
                                  controller: _password,
                                  focusNode: _passwordFocus,
                                  enabled: !auth.busy,
                                  decoration: InputDecoration(
                                    labelText: 'รหัสผ่าน',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: auth.busy
                                          ? null
                                          : () => setState(
                                              () => _obscure = !_obscure,
                                            ),
                                      tooltip: _obscure
                                          ? 'แสดงรหัสผ่าน'
                                          : 'ซ่อนรหัสผ่าน',
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  obscureText: _obscure,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  autofillHints: [
                                    _register
                                        ? AutofillHints.newPassword
                                        : AutofillHints.password,
                                  ],
                                  textInputAction: TextInputAction.done,
                                  onChanged: (_) => setState(() {}),
                                  onFieldSubmitted: (_) {
                                    if (!auth.busy) _submit();
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'กรุณากรอกรหัสผ่าน';
                                    }
                                    if (_register &&
                                        utf8.encode(value).length < 8) {
                                      return 'รหัสผ่านต้องยาวอย่างน้อย 8 ตัวอักษร';
                                    }
                                    if (_register &&
                                        utf8.encode(value).length > 72) {
                                      return 'รหัสผ่านยาวเกินไป กรุณาลดจำนวนตัวอักษร';
                                    }
                                    return null;
                                  },
                                ),
                                if (_register)
                                  _PasswordChecks(value: _password.text)
                                else
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      key: const Key('forgot-password'),
                                      onPressed: auth.busy
                                          ? null
                                          : _showForgotPassword,
                                      child: const Text('ลืมรหัสผ่าน?'),
                                    ),
                                  ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 220),
                                  child: auth.error == null
                                      ? const SizedBox.shrink()
                                      : Padding(
                                          padding: const EdgeInsets.only(
                                            top: Spacing.md,
                                          ),
                                          child: _ErrorNotice(auth.error!),
                                        ),
                                ),
                                const SizedBox(height: Spacing.lg),
                                FilledButton(
                                  key: const Key('submit'),
                                  onPressed: auth.busy ? null : _submit,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: auth.busy
                                        ? const Row(
                                            key: ValueKey('sending'),
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                              SizedBox(width: Spacing.sm),
                                              Text('กำลังส่งต่อ…'),
                                            ],
                                          )
                                        : Row(
                                            key: const ValueKey('ready'),
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _register
                                                    ? 'สร้างบัญชี'
                                                    : 'เข้าสู่ระบบ',
                                              ),
                                              const SizedBox(width: Spacing.sm),
                                              const Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 19,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: Spacing.md),
                                Center(
                                  child: TextButton(
                                    onPressed: auth.busy
                                        ? null
                                        : () => setState(() {
                                            _register = !_register;
                                            widget.auth.error = null;
                                            _password.clear();
                                            _form.currentState?.reset();
                                          }),
                                    child: Text(
                                      _register
                                          ? 'มีบัญชีแล้ว? เข้าสู่ระบบ'
                                          : 'ยังไม่มีบัญชี? สมัครสมาชิก',
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

class _RelayJourney extends StatelessWidget {
  const _RelayJourney({required this.progress, required this.busy});
  final double progress;
  final bool busy;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'เส้นทางคอนเทนต์ จากไอเดียไปสู่การเผยแพร่',
    child: ExcludeSemantics(
      child: Container(
        height: 112,
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 12),
        decoration: BoxDecoration(
          color: context.t.surfaceContainer.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.t.border),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progress),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _JourneyPainter(
                          progress: value,
                          primary: context.t.primary,
                          border: context.t.border,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _JourneyNode(
                          icon: Icons.edit_rounded,
                          active: value >= 0,
                        ),
                        _JourneyNode(
                          icon: Icons.schedule_rounded,
                          active: value >= .48,
                        ),
                        _JourneyNode(
                          icon: busy
                              ? Icons.bolt_rounded
                              : Icons.rocket_launch_rounded,
                          active: value >= .9,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _JourneyLabel('ไอเดีย', active: true),
                  _JourneyLabel('ตั้งเวลา', active: progress >= .48),
                  _JourneyLabel('เผยแพร่', active: progress >= .9),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _JourneyNode extends StatelessWidget {
  const _JourneyNode({required this.icon, required this.active});
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 280),
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: active ? context.t.primary : context.t.surface,
      shape: BoxShape.circle,
      border: Border.all(
        color: active ? context.t.primary : context.t.border,
        width: 2,
      ),
      boxShadow: active
          ? [
              BoxShadow(
                color: context.t.primary.withValues(alpha: .2),
                blurRadius: 14,
              ),
            ]
          : null,
    ),
    child: Icon(
      icon,
      size: 18,
      color: active ? context.t.onPrimary : context.t.textSecondary,
    ),
  );
}

class _JourneyLabel extends StatelessWidget {
  const _JourneyLabel(this.text, {required this.active});
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedDefaultTextStyle(
    duration: const Duration(milliseconds: 280),
    style: TextStyle(
      color: active ? context.t.primary : context.t.textSecondary,
      fontSize: 11,
      fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
    ),
    child: Text(text),
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

class _JourneyPainter extends CustomPainter {
  const _JourneyPainter({
    required this.progress,
    required this.primary,
    required this.border,
  });
  final double progress;
  final Color primary;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 19.0;
    final y = size.height / 2;
    final start = Offset(inset, y);
    final end = Offset(size.width - inset, y);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = border
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      start,
      Offset(inset + (size.width - inset * 2) * progress, y),
      Paint()
        ..color = primary
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final packetX = inset + (size.width - inset * 2) * progress;
    canvas.drawCircle(
      Offset(packetX, y),
      6,
      Paint()..color = primary.withValues(alpha: .2),
    );
    canvas.drawCircle(Offset(packetX, y), 3, Paint()..color = primary);
  }

  @override
  bool shouldRepaint(_JourneyPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      primary != oldDelegate.primary ||
      border != oldDelegate.border;
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
