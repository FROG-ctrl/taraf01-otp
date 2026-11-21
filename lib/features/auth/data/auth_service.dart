import 'package:supabase_flutter/supabase_flutter.dart';

/// كل منطق المصادقة في مكان واحد.
///
/// الشاشات لا تتحدث مع Supabase مباشرة، بل تستدعي [AuthService.instance].
/// الدوال ترجع **مفاتيح ترجمة** (النص العربي نفسه) وليست رسائل جاهزة،
/// حتى تتولى الشاشة استدعاء `.tr()` وتظهر الرسالة باللغة الحالية.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  SupabaseClient get _auth => Supabase.instance.client;

  User? get currentUser => _auth.auth.currentUser;

  Session? get currentSession => _auth.auth.currentSession;

  // ─────────────────────────────────────────────────────────────
  // 1) إنشاء الحساب
  //    Supabase تبعت كود من 6 أرقام على البريد (لو Confirm email مفعّل).
  //    في هذه الحالة currentSession تبقى null — وده سلوك طبيعي مش خطأ.
  // ─────────────────────────────────────────────────────────────
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String address,
  }) async {
    final res = await _auth.auth.signUp(
      email: email.trim(),
      password: password,
      // بيانات إضافية يستهلكها trigger في قاعدة البيانات لإنشاء صف المستخدم.
      // لا تحذف هذه الخريطة.
      data: {
        'name': name.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
      },
    );

    final user = res.user;
    if (user == null) {
      throw const AuthException('تعذر إنشاء الحساب، حاول تاني');
    }

    // Supabase لا ترجع خطأ لو البريد مستخدم (حماية من تسريب البيانات)،
    // لكن ترجع قائمة identities فارغة.
    if (user.identities != null && user.identities!.isEmpty) {
      throw const AuthException('هذا البريد الإلكتروني مسجل بالفعل');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2) التحقق من الكود — يرجع جلسة، أي أن المستخدم صار مسجلًا للدخول.
  // ─────────────────────────────────────────────────────────────
  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String code,
  }) async {
    final cleanCode = code.trim();
    if (cleanCode.length < 6) {
      throw const AuthException('من فضلك اكتب الكود كامل');
    }

    final res = await _auth.auth.verifyOTP(
      type: OtpType.signup,
      email: email.trim(),
      token: cleanCode,
    );

    if (res.session == null) {
      throw const AuthException('الكود غير صحيح أو انتهت صلاحيته');
    }
    return res;
  }

  // ─────────────────────────────────────────────────────────────
  // 3) إعادة إرسال الكود
  // ─────────────────────────────────────────────────────────────
  Future<void> resendSignupOtp({required String email}) async {
    await _auth.auth.resend(type: OtpType.signup, email: email.trim());
  }

  // ─────────────────────────────────────────────────────────────
  // 4) تسجيل الدخول والخروج
  // ─────────────────────────────────────────────────────────────
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _auth.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.auth.signOut();

  // ─────────────────────────────────────────────────────────────
  // تحويل أي خطأ إلى مفتاح ترجمة عربي (غير مترجم)
  // ─────────────────────────────────────────────────────────────
  static String errorKey(Object e) {
    const fallback = 'حصل خطأ، حاول تاني';
    if (e is! AuthException) return fallback;

    final msg = e.message.toLowerCase();
    final code = (e.code ?? '').toLowerCase();

    if (e.statusCode == '429' ||
        code.contains('rate_limit') ||
        msg.contains('rate limit') ||
        code.contains('over_email_send')) {
      return 'بعت كتير، استنى دقيقة وجرب تاني';
    }
    if (code.contains('email_address_not_authorized')) {
      return 'إعدادات الإيميل مش مظبوطة، تواصل مع الدعم';
    }
    if (msg.contains('expired') || msg.contains('invalid')) {
      return 'الكود غير صحيح أو انتهت صلاحيته';
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'هذا البريد الإلكتروني مسجل بالفعل';
    }
    if (msg.contains('email not confirmed')) {
      return 'من فضلك أكد بريدك الإلكتروني أولاً';
    }
    if (msg.contains('weak')) {
      return 'كلمة المرور ضعيفة، استخدم كلمة أقوى';
    }
    if (msg.contains('invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    return fallback;
  }
}
