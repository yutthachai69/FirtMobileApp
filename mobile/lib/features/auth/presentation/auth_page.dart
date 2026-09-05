import 'dart:convert';

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

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _obscure = true;
  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, _) {
      final auth = widget.auth;
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: context.t.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.layers_rounded,
                                color: context.t.onPrimary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'RelayContent',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Text(
                          _register
                              ? 'เริ่มต้นบัญชีของคุณ'
                              : 'ยินดีต้อนรับกลับ',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _register
                              ? 'สร้างบัญชีเพื่อเริ่มจัดการคอนเทนต์ของคุณ'
                              : 'เข้าสู่ระบบเพื่อกลับมาทำงานต่อ',
                          style: TextStyle(
                            fontSize: 16,
                            color: context.t.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (_register) ...[
                          TextFormField(
                            controller: _name,
                            enabled: !auth.busy,
                            decoration: const InputDecoration(
                              labelText: 'ชื่อที่ใช้แสดง',
                            ),
                            autofillHints: const [AutofillHints.name],
                            textInputAction: TextInputAction.next,
                            maxLength: 100,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          key: const Key('email'),
                          controller: _email,
                          enabled: !auth.busy,
                          decoration: const InputDecoration(
                            labelText: 'อีเมล',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          validator: (value) =>
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value?.trim() ?? '')
                              ? null
                              : 'กรุณากรอกอีเมลให้ถูกต้อง',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('password'),
                          controller: _password,
                          enabled: !auth.busy,
                          decoration: InputDecoration(
                            labelText: 'รหัสผ่าน',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
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
                          onFieldSubmitted: (_) {
                            if (!auth.busy) _submit();
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'กรุณากรอกรหัสผ่าน';
                            }
                            if (_register && utf8.encode(value).length < 8) {
                              return 'รหัสผ่านต้องยาวอย่างน้อย 8 ตัวอักษร';
                            }
                            if (_register && utf8.encode(value).length > 72) {
                              return 'รหัสผ่านยาวเกินไป กรุณาลดจำนวนตัวอักษร';
                            }
                            return null;
                          },
                        ),
                        if (auth.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                auth.error!,
                                style: TextStyle(color: context.t.error),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const Key('submit'),
                          onPressed: auth.busy ? null : _submit,
                          child: auth.busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_register ? 'สร้างบัญชี' : 'เข้าสู่ระบบ'),
                        ),
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            'บัญชีเดียว พร้อมใช้กับทุกอุปกรณ์',
                            style: TextStyle(
                              color: context.t.textSecondary,
                              fontSize: 13,
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
      );
    },
  );
}
