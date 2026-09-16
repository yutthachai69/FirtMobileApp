import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/tokens.dart';

/// การ์ดเชื่อมต่อแหล่ง AI แบบ "Synaptic Beam" — แทนที่ปุ่ม "เชื่อม" ธรรมดา
/// ด้วยแอนิเมชัน handshake จริง: packet วิ่งผ่านสเต็ป AUTH → TOKEN → VERIFY →
/// LINK แล้วรอ response กลับ ส่วนตอนตัดการเชื่อมจะวิ่งย้อน REVOKE → TOKEN →
/// SESSION → CLOSED เป็นภาพเดียวกับดีไซน์ที่ทีมออกแบบเลือกไว้
///
/// วิดเจ็ตนี้คุม state การ์ดเองทั้งหมด (เพื่อให้จังหวะแอนิเมชันต่อเนื่องไม่ถูก
/// rebuild จาก parent ตัดจบกลางทาง) แล้วค่อยเรียก [onConnect]/[onDisconnect]
/// เพื่ออัปเดตสถานะจริงใน controller หลังแอนิเมชันจบแต่ละฝั่ง
class SynapticBeamConnectTile extends StatefulWidget {
  const SynapticBeamConnectTile({
    super.key,
    required this.sourceId,
    required this.name,
    required this.icon,
    required this.isConnected,
    required this.onConnect,
    required this.onDisconnect,
    this.confirmDisconnect,
    this.constraintNote,
  });

  /// ใช้ประกอบ key ของปุ่ม action (`connect-source-$sourceId` /
  /// `disconnect-source-$sourceId`) ให้เทส/automation หาเจอ
  final String sourceId;
  final String name;
  final IconData icon;
  final bool isConnected;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;

  /// เรียกก่อนเริ่มแอนิเมชันตัดการเชื่อม — คืน false เพื่อยกเลิกโดยไม่แตะ UI
  final Future<bool> Function()? confirmDisconnect;

  /// ข้อความข้อจำกัดของแหล่งนี้ เช่น "ส่งออกเป็น 16:9 — ต้องครอปก่อนโพสต์"
  final String? constraintNote;

  @override
  State<SynapticBeamConnectTile> createState() =>
      _SynapticBeamConnectTileState();
}

enum _Phase { idle, connecting, responding, connected, disconnecting }

class _BeamStep {
  const _BeamStep(this.label, this.fraction, this.note, this.detail);
  final String label;
  final double fraction;
  final String note;
  final String detail;
}

const _connectSteps = [
  _BeamStep('AUTH', .18, 'กำลังยืนยันตัวตน…', 'Authorization request'),
  _BeamStep('TOKEN', .43, 'กำลังรับ access token…', 'Token exchange'),
  _BeamStep('VERIFY', .69, 'กำลังตรวจสอบสิทธิ์…', 'Scope verification'),
  _BeamStep('LINK', .90, 'กำลังสร้าง secure link…', 'Secure channel setup'),
];

const _disconnectSteps = [
  _BeamStep('REVOKE', .90, 'กำลังเพิกถอนสิทธิ์…', 'Revoking OAuth permission'),
  _BeamStep('TOKEN', .66, 'กำลังยกเลิก access token…', 'Releasing access token'),
  _BeamStep('SESSION', .40, 'กำลังปิด session…', 'Closing active session'),
  _BeamStep('CLOSED', .15, 'กำลังปิด secure link…', 'Closing secure channel'),
];

const _accent2 = Color(0xFF8A72FF); // จุดเน้นที่สองของแหวนหมุนรอบปุ่ม

class _SynapticBeamConnectTileState extends State<SynapticBeamConnectTile>
    with TickerProviderStateMixin {
  late _Phase _phase = widget.isConnected ? _Phase.connected : _Phase.idle;
  late String _note = widget.isConnected
      ? 'เชื่อมต่อสำเร็จ · พร้อมใช้งาน'
      : 'พร้อมเชื่อมต่อ';
  String _detail = 'กด "เชื่อม" เพื่อเริ่ม Synaptic Handshake';
  String _packetLabel = 'AUTH';
  late String _btnLabel = widget.isConnected ? 'ยกเลิกการเชื่อมต่อ' : 'เชื่อม →';
  bool _busy = false;
  int _token = 0;

  double _packetBegin = 0;
  double _packetEnd = 0;
  bool _packetVisible = false;
  bool _packetDanger = false;

  late final AnimationController _packetCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  // ring/dash/spark วิ่งเฉพาะตอน connecting/disconnecting เท่านั้น (ไม่ repeat
  // ตลอดเวลาแบบ CSS ต้นฉบับ) เพราะ AnimationController ที่ repeat() ค้างไว้
  // ทำให้ WidgetTester.pumpAndSettle ไม่มีวัน settle
  late final AnimationController _ringCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  late final AnimationController _dashCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _sparkCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  );
  late final AnimationController _burstCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final AnimationController _cutCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  @override
  void dispose() {
    _packetCtrl.dispose();
    _ringCtrl.dispose();
    _dashCtrl.dispose();
    _sparkCtrl.dispose();
    _burstCtrl.dispose();
    _cutCtrl.dispose();
    super.dispose();
  }

  double get _packetFraction {
    final t = Curves.easeOutCubic.transform(_packetCtrl.value);
    return _packetBegin + (_packetEnd - _packetBegin) * t;
  }

  Future<void> _movePacketTo(
    double target, {
    Duration duration = const Duration(milliseconds: 520),
  }) async {
    _packetBegin = _packetFraction;
    _packetEnd = target;
    _packetCtrl.duration = duration;
    await _packetCtrl.forward(from: 0);
  }

  Future<void> _handleTap() async {
    if (_busy) return;
    if (_phase == _Phase.connected) {
      if (widget.confirmDisconnect != null) {
        final proceed = await widget.confirmDisconnect!();
        if (!proceed) return;
      }
      await _disconnect();
    } else {
      await _connect();
    }
  }

  Future<void> _connect() async {
    _busy = true;
    final myToken = ++_token;
    HapticFeedback.selectionClick();

    setState(() {
      _phase = _Phase.connecting;
      _btnLabel = '•••';
      _detail = 'Handshake started';
      _packetVisible = true;
      _packetDanger = false;
    });
    _ringCtrl.repeat();
    _dashCtrl.repeat();
    _sparkCtrl.repeat();

    for (final step in _connectSteps) {
      if (!mounted || myToken != _token) return;
      setState(() {
        _packetLabel = step.label;
        _note = step.note;
        _detail = step.detail;
      });
      await _movePacketTo(step.fraction);
      if (!mounted || myToken != _token) return;
    }
    if (!mounted || myToken != _token) return;

    setState(() {
      _phase = _Phase.responding;
      _note = 'ปลายทางตอบกลับ…';
      _detail = '← 200 OK';
    });
    await Future<void>.delayed(const Duration(milliseconds: 720));
    if (!mounted || myToken != _token) return;

    setState(() {
      _phase = _Phase.connected;
      _note = 'เชื่อมต่อสำเร็จ · พร้อมใช้งาน';
      _detail = 'Secure link established';
      _btnLabel = 'ยกเลิกการเชื่อมต่อ';
      _packetVisible = false;
      _busy = false;
    });
    _ringCtrl.stop();
    _dashCtrl.stop();
    _sparkCtrl.stop();
    HapticFeedback.lightImpact();
    unawaited(widget.onConnect());
    unawaited(_burstCtrl.forward(from: 0));
  }

  Future<void> _disconnect() async {
    _busy = true;
    final myToken = ++_token;
    HapticFeedback.selectionClick();

    setState(() {
      _phase = _Phase.disconnecting;
      _btnLabel = 'กำลังยกเลิก';
      _detail = 'Closing secure channel';
      _packetVisible = true;
      _packetDanger = true;
    });
    _ringCtrl.repeat();
    _dashCtrl.repeat();
    _sparkCtrl.repeat();
    await _movePacketTo(0.92, duration: const Duration(milliseconds: 200));
    if (!mounted || myToken != _token) return;

    for (final step in _disconnectSteps) {
      if (!mounted || myToken != _token) return;
      setState(() {
        _packetLabel = step.label;
        _note = step.note;
        _detail = step.detail;
      });
      await _movePacketTo(step.fraction);
      if (!mounted || myToken != _token) return;
    }
    if (!mounted || myToken != _token) return;

    setState(() {
      _packetLabel = 'OFFLINE';
      _note = 'กำลังตัด secure link…';
      _detail = 'Closing transport channel';
    });
    unawaited(_cutCtrl.forward(from: 0));
    await Future<void>.delayed(const Duration(milliseconds: 480));
    if (!mounted || myToken != _token) return;

    setState(() {
      _phase = _Phase.idle;
      _note = 'พร้อมเชื่อมต่อ';
      _detail = 'กด "เชื่อมอีกครั้ง" เพื่อเริ่ม Synaptic Handshake';
      _btnLabel = 'เชื่อมอีกครั้ง';
      _packetVisible = false;
      _busy = false;
    });
    _ringCtrl.stop();
    _dashCtrl.stop();
    _sparkCtrl.stop();
    unawaited(widget.onDisconnect());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final active = _phase == _Phase.connecting || _phase == _Phase.responding;
    final connected = _phase == _Phase.connected;
    final disconnecting = _phase == _Phase.disconnecting;

    final glowColor = disconnecting ? t.error : t.primary;
    final glowOpacity = (active || connected || disconnecting) ? .16 : .0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ambient glow มุมขวาบน
          Positioned(
            right: -60,
            top: -40,
            child: AnimatedOpacity(
              opacity: glowOpacity,
              duration: const Duration(milliseconds: 450),
              child: Container(
                width: 180,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [glowColor, glowColor.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ServiceIcon(
                    icon: widget.icon,
                    active: active,
                    connected: connected,
                    danger: disconnecting,
                    ringController: _sparkCtrl,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            _note,
                            key: ValueKey(_note),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: disconnecting
                                  ? t.error
                                  : connected
                                  ? t.primary
                                  : t.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _BeamActionButton(
                    key: Key(
                      _phase == _Phase.connected || disconnecting
                          ? 'disconnect-source-${widget.sourceId}'
                          : 'connect-source-${widget.sourceId}',
                    ),
                    label: _btnLabel,
                    phase: _phase,
                    onTap: _handleTap,
                    ringController: _ringCtrl,
                    burstController: _burstCtrl,
                    primary: t.primary,
                    onPrimary: t.onPrimary,
                    error: t.error,
                    border: t.border,
                    surface: t.surfaceContainer,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                width: double.infinity,
                child: _Beam(
                  phase: _phase,
                  packetBegin: _packetBegin,
                  packetEnd: _packetEnd,
                  packetVisible: _packetVisible,
                  packetDanger: _packetDanger,
                  packetLabel: _packetLabel,
                  packetAnim: _packetCtrl,
                  dashAnim: _dashCtrl,
                  sparkAnim: _sparkCtrl,
                  cutAnim: _cutCtrl,
                  primary: t.primary,
                  danger: t.error,
                  border: t.border,
                  surface: t.surfaceContainer,
                  textColor: t.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        _detail,
                        key: ValueKey(_detail),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                          color: t.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: (connected || disconnecting) ? 1 : 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: disconnecting ? t.error : t.primary,
                          ),
                        ),
                        Text(
                          disconnecting ? 'CLOSING' : 'LIVE · OAuth Secure',
                          style: TextStyle(
                            fontFamily: 'Prompt',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .05,
                            color: disconnecting ? t.error : t.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.constraintNote != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.constraintNote!,
                  style: TextStyle(fontSize: 11, color: t.warning),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({
    required this.icon,
    required this.active,
    required this.connected,
    required this.danger,
    required this.ringController,
  });

  final IconData icon;
  final bool active;
  final bool connected;
  final bool danger;
  final AnimationController ringController;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final color = danger
        ? t.error
        : (active || connected)
        ? t.primary
        : t.textSecondary;

    return AnimatedBuilder(
      animation: ringController,
      builder: (context, _) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: active || connected || danger ? color : t.border),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(
                      alpha: .35 * (1 - (ringController.value % 1)),
                    ),
                    blurRadius: 14 * (ringController.value % 1) + 2,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

class _Beam extends StatelessWidget {
  const _Beam({
    required this.phase,
    required this.packetBegin,
    required this.packetEnd,
    required this.packetVisible,
    required this.packetDanger,
    required this.packetLabel,
    required this.packetAnim,
    required this.dashAnim,
    required this.sparkAnim,
    required this.cutAnim,
    required this.primary,
    required this.danger,
    required this.border,
    required this.surface,
    required this.textColor,
  });

  final _Phase phase;
  final double packetBegin;
  final double packetEnd;
  final bool packetVisible;
  final bool packetDanger;
  final String packetLabel;
  final Animation<double> packetAnim;
  final Animation<double> dashAnim;
  final Animation<double> sparkAnim;
  final Animation<double> cutAnim;
  final Color primary;
  final Color danger;
  final Color border;
  final Color surface;
  final Color textColor;

  static final _forwardPath = Path()
    ..moveTo(0, 31)
    ..cubicTo(100, 4, 180, 58, 270, 31)
    ..cubicTo(360, 4, 350, 13, 420, 31);

  Offset _pointAt(double t) {
    final metrics = _forwardPath.computeMetrics().toList();
    final metric = metrics.first;
    final tangent = metric.getTangentForOffset(metric.length * t.clamp(0, 1));
    return tangent?.position ?? const Offset(0, 31);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([packetAnim, dashAnim, sparkAnim, cutAnim]),
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final sx = constraints.maxWidth / 420;
            final sy = constraints.maxHeight / 62;
            final eased = Curves.easeOutCubic.transform(packetAnim.value);
            final fraction = packetBegin + (packetEnd - packetBegin) * eased;
            final rawPos = _pointAt(fraction);
            final pos = Offset(rawPos.dx * sx, rawPos.dy * sy);
            final packetColor = packetDanger ? danger : primary;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BeamPainter(
                      phase: phase,
                      dashOffset: dashAnim.value,
                      baseColor: border,
                      liveColor: primary,
                      returnColor: packetDanger ? danger : primary,
                    ),
                  ),
                ),
                // sparks
                for (final s in const [
                  (0.22, 0.31, 0.0),
                  (0.50, 0.64, 0.27),
                  (0.74, 0.39, 0.50),
                ])
                  if (phase == _Phase.connecting || phase == _Phase.disconnecting)
                    Positioned(
                      left: s.$1 * constraints.maxWidth - 2,
                      top: s.$2 * constraints.maxHeight - 2,
                      child: Builder(
                        builder: (context) {
                          final t = (sparkAnim.value + s.$3) % 1.0;
                          final env = t < .45
                              ? t / .45
                              : (1 - (t - .45) / .55).clamp(0.0, 1.0);
                          return Opacity(
                            opacity: env * .9,
                            child: Transform.scale(
                              scale: .4 + env * 1.2,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: packetDanger ? danger : primary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                // cut ring pulse near the start of the beam
                if (cutAnim.isAnimating || cutAnim.value > 0)
                  Positioned(
                    left: 0.15 * constraints.maxWidth - 6,
                    top: 0.5 * constraints.maxHeight - 6,
                    child: Opacity(
                      opacity: (1 - cutAnim.value).clamp(0.0, 1.0) * .85,
                      child: Transform.scale(
                        scale: .5 + cutAnim.value * 2.8,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: danger),
                          ),
                        ),
                      ),
                    ),
                  ),
                // packet
                if (packetVisible)
                  Positioned(
                    left: pos.dx - 4,
                    top: pos.dy - 4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: packetDanger
                                  ? danger.withValues(alpha: .5)
                                  : border,
                            ),
                          ),
                          child: Text(
                            packetLabel,
                            style: TextStyle(
                              fontFamily: 'Prompt',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .04,
                              color: packetDanger ? danger : textColor,
                            ),
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: packetColor,
                            boxShadow: [
                              BoxShadow(
                                color: packetColor.withValues(alpha: .55),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BeamPainter extends CustomPainter {
  _BeamPainter({
    required this.phase,
    required this.dashOffset,
    required this.baseColor,
    required this.liveColor,
    required this.returnColor,
  });

  final _Phase phase;
  final double dashOffset;
  final Color baseColor;
  final Color liveColor;
  final Color returnColor;

  static final _forwardPath = Path()
    ..moveTo(0, 31)
    ..cubicTo(100, 4, 180, 58, 270, 31)
    ..cubicTo(360, 4, 350, 13, 420, 31);

  static final _returnPath = Path()
    ..moveTo(420, 31)
    ..cubicTo(350, 13, 330, 48, 270, 31)
    ..cubicTo(210, 14, 100, 4, 0, 31);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 420, size.height / 62);

    final base = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _drawDashed(canvas, _forwardPath, base, const [2, 6], 0);

    switch (phase) {
      case _Phase.connecting:
        final live = Paint()
          ..color = liveColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.9
          ..strokeCap = StrokeCap.round;
        _drawDashed(canvas, _forwardPath, live, const [16, 92], -dashOffset * 108);
        break;
      case _Phase.responding:
      case _Phase.connected:
        final live = Paint()
          ..color = liveColor.withValues(alpha: .48)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.9
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(_forwardPath, live);
        if (phase == _Phase.responding) {
          final ret = Paint()
            ..color = liveColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.7
            ..strokeCap = StrokeCap.round;
          _drawDashed(canvas, _returnPath, ret, const [13, 90], -dashOffset * 104);
        }
        break;
      case _Phase.disconnecting:
        final live = Paint()
          ..color = returnColor.withValues(alpha: .18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.9
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(_forwardPath, live);
        final ret = Paint()
          ..color = returnColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..strokeCap = StrokeCap.round;
        _drawDashed(canvas, _returnPath, ret, const [13, 90], -dashOffset * 104);
        break;
      case _Phase.idle:
        break;
    }

    canvas.restore();
  }

  void _drawDashed(
    Canvas canvas,
    Path path,
    Paint paint,
    List<double> dashArray,
    double phase,
  ) {
    final cycle = dashArray[0] + dashArray[1];
    for (final metric in path.computeMetrics()) {
      var distance = phase % cycle;
      if (distance > 0) distance -= cycle;
      while (distance < metric.length) {
        final start = distance.clamp(0.0, metric.length);
        final end = (distance + dashArray[0]).clamp(0.0, metric.length);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), paint);
        }
        distance += cycle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BeamPainter old) =>
      old.phase != phase ||
      old.dashOffset != dashOffset ||
      old.baseColor != baseColor ||
      old.liveColor != liveColor ||
      old.returnColor != returnColor;
}

class _BeamActionButton extends StatelessWidget {
  const _BeamActionButton({
    super.key,
    required this.label,
    required this.phase,
    required this.onTap,
    required this.ringController,
    required this.burstController,
    required this.primary,
    required this.onPrimary,
    required this.error,
    required this.border,
    required this.surface,
  });

  final String label;
  final _Phase phase;
  final Future<void> Function() onTap;
  final AnimationController ringController;
  final AnimationController burstController;
  final Color primary;
  final Color onPrimary;
  final Color error;
  final Color border;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final connecting =
        phase == _Phase.connecting || phase == _Phase.responding;
    final connected = phase == _Phase.connected;
    final disconnecting = phase == _Phase.disconnecting;

    Color bg;
    Color fg;
    Color side;
    if (connecting) {
      bg = surface;
      fg = primary;
      side = border;
    } else if (connected) {
      bg = Colors.transparent;
      fg = primary;
      side = primary;
    } else if (disconnecting) {
      bg = Colors.transparent;
      fg = error;
      side = error.withValues(alpha: .5);
    } else {
      bg = primary;
      fg = onPrimary;
      side = Colors.transparent;
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // แหวนไล่สีหมุนรอบปุ่ม — ดีเทลที่โผล่ตลอดเวลา ไม่ผูกกับสถานะ
        AnimatedBuilder(
          animation: ringController,
          builder: (context, _) => CustomPaint(
            painter: _RingPainter(
              angle: ringController.value * 2 * math.pi,
              colorA: primary,
              colorB: _accent2,
            ),
            child: const SizedBox(width: 118, height: 46),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(
              minWidth: connected
                  ? 118
                  : disconnecting
                  ? 100
                  : 88,
            ),
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: side),
              boxShadow: connecting
                  ? [BoxShadow(color: primary.withValues(alpha: .25), blurRadius: 16)]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onTap(),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Text(
                        label,
                        key: ValueKey(label),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // success burst
        AnimatedBuilder(
          animation: burstController,
          builder: (context, _) {
            if (burstController.value == 0 || burstController.status == AnimationStatus.dismissed) {
              return const SizedBox.shrink();
            }
            return IgnorePointer(
              child: SizedBox(
                width: 118,
                height: 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                  for (final d in const [
                    Offset(28, -10),
                    Offset(20, 22),
                    Offset(-6, 30),
                    Offset(-27, 12),
                    Offset(-23, -18),
                    Offset(4, -30),
                  ])
                    Positioned(
                      left: 59 + d.dx * burstController.value,
                      top: 23 + d.dy * burstController.value,
                      child: Opacity(
                        opacity: (1 - burstController.value).clamp(0.0, 1.0),
                        child: Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.angle, required this.colorA, required this.colorB});

  final double angle;
  final Color colorA;
  final Color colorB;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(999));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = SweepGradient(
        transform: GradientRotation(angle),
        colors: [
          colorA.withValues(alpha: 0),
          colorA.withValues(alpha: .55),
          colorB.withValues(alpha: .55),
          colorA.withValues(alpha: 0),
        ],
        stops: const [0.0, .28, .64, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.angle != angle;
}
