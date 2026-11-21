# 🤖 الأمر البرمجي لأداة الذكاء الاصطناعي — نسخة `taraf01`

Flutter + Supabase · كود تأكيد 6 أرقام عند إنشاء الحساب · متوافق مع هيكل مشروع «مركز الشريف» الموجود

---

## ما تغيّر عن النسخة العامة (اقرأه قبل أي حاجة)

النسخة الأولى من الأمر كانت لمشروع فاضي، وكانت هتطلع شغل مكرر في مشروعك. دي الفروق:

| النسخة العامة | نسخة `taraf01` |
|---|---|
| `lib/screens/…` | `lib/features/auth/screens/…` (نفس تنظيم المشروع) |
| `lib/core/auth_service.dart` | `lib/features/auth/data/auth_service.dart` |
| نصوص عربي مكتوبة في الكود | مفاتيح في `assets/translations/ar.json` + `en.json` |
| ملف `lib/config/env.dart` بـ `--dart-define` | **مش مطلوب** — `Supabase.initialize` موجود بالفعل في `main.dart` |
| `home` حسب `currentSession` | `AppRoutes.home` + `SharedPreferences('current_user_id')` زي باقي الشاشات |
| بيعمل شاشة تسجيل جديدة | يعدّل `Signup` الموجودة **تعديل محدود** ويضيف شاشة الكود بس |
| كلمة المرور 8 حروف | 6 حروف — زي الفاليديشن الموجود في مشروعك |

### 3 حقائق عن مشروعك لازم الأداة تعرفها

1. **الترجمة بنمط «النص العربي هو المفتاح».** الملف مسطّح (flat) بدون أي تداخل:
   ```json
   // assets/translations/ar.json
   "دخول": "دخول",
   // assets/translations/en.json
   "دخول": "Login"
   ```
   أي مفتاح جديد لازم يتضاف **بنفس النص العربي** في الملفين، وإلا `.tr()` هترجع النص كما هو في الإنجليزية.

2. **`Supabase.initialize` في `main.dart` بالمفاتيح الحقيقية و`publishableKey`** (الـ API الجديد مش `anonKey`). ممنوع لمسه.

3. **`signUp` بيرسل `data: {name, phone, address}`** وبيعتمد على trigger في الداتابيز بيعمل صف في جدول المستخدمين. ممنوع تشيل الـ `data`.

---

## ⬇️ الأمر — انسخ من هنا لآخره

```text
You are a senior Flutter engineer working inside an EXISTING project.
Package name: al_sharif  (imports use package:al_sharif/...)
Flutter 3.x / Dart 3.x, Material 3, null safety.

=== GOAL ===
Add an email-OTP step to the existing signup flow, so that after signUp() the user
enters a 6-digit code sent by Supabase and is then logged in automatically.

=== HARD CONSTRAINTS — VIOLATING ANY OF THESE IS A FAILED TASK ===
1. Do NOT modify lib/main.dart. Supabase is already initialized there with
   Supabase.initialize(url: ..., publishableKey: ...). Do not introduce
   --dart-define, an Env class, or any new credential handling.
2. Do NOT rewrite or restyle lib/features/auth/screens/signin_screen.dart.
3. Do NOT touch any file outside lib/features/auth/, assets/translations/, and
   docs/ — except adding one dependency to pubspec.yaml.
4. Do NOT remove the `data:` map from signUp — a database trigger consumes
   { name, phone, address } to create the user row.
5. Do NOT add Firebase, magic links, deep links, or emailRedirectTo.
   Passing emailRedirectTo switches Supabase to link-based emails.
6. Do NOT add translations as nested JSON objects. This project uses FLAT maps
   where the Arabic text itself is the key (see TRANSLATIONS below).
7. Do NOT change the existing password rule: minimum 6 characters.

=== DEPENDENCY ===
Add to pubspec.yaml under dependencies, keeping alphabetical-ish grouping:
    pinput: ^5.0.0
Run `flutter pub get`. Do not upgrade or touch any existing dependency.

=== FILE 1 (NEW) — lib/features/auth/data/auth_service.dart ===
Singleton `AuthService.instance` over Supabase.instance.client.

  Future<void> signUp({required String email, required String password,
                       required String name, required String phone,
                       required String address})
    - client.auth.signUp(email: ..., password: ..., data: {'name':..,'phone':..,'address':..})
    - NEVER pass emailRedirectTo.
    - if res.user == null -> throw AuthException('تعذر إنشاء الحساب، حاول تاني')
    - if res.user!.identities != null && res.user!.identities!.isEmpty
         -> throw AuthException('هذا البريد الإلكتروني مسجل بالفعل')
    - return normally whether or not res.session is null. With "Confirm email" ON,
      session is null by design at this point — that is NOT an error.

  Future<AuthResponse> verifySignupOtp({required String email, required String code})
    - trim the code; if length < 6 -> throw AuthException('من فضلك اكتب الكود كامل')
    - client.auth.verifyOTP(type: OtpType.signup, email: email, token: code)
    - if res.session == null -> throw AuthException('الكود غير صحيح أو انتهت صلاحيته')
    - return res

  Future<void> resendSignupOtp({required String email})
    - client.auth.resend(type: OtpType.signup, email: email)

  Future<AuthResponse> signIn({required String email, required String password})
  Future<void> signOut()
  User? get currentUser
  Session? get currentSession

  static String errorKey(Object e)  // returns an ARABIC KEY, never a translated string
    - if e is not AuthException -> 'حصل خطأ، حاول تاني'
    - statusCode '429' or code 'over_email_send_rate_limit' or message has 'rate limit'
         -> 'بعت كتير، استنى دقيقة وجرب تاني'
    - code 'email_address_not_authorized' -> 'إعدادات الإيميل مش مظبوطة، تواصل مع الدعم'
    - message has 'expired' or 'invalid'  -> 'الكود غير صحيح أو انتهت صلاحيته'
    - message has 'already registered' / 'already exists' -> 'هذا البريد الإلكتروني مسجل بالفعل'
    - message has 'email not confirmed'   -> 'من فضلك أكد بريدك الإلكتروني أولاً'
    - message has 'weak'                  -> 'كلمة المرور ضعيفة، استخدم كلمة أقوى'
    - message has 'invalid login credentials' -> 'البريد الإلكتروني أو كلمة المرور غير صحيحة'
    - fallback -> 'حصل خطأ، حاول تاني'

  The strings above are the exact JSON keys listed in TRANSLATIONS: add every one
  of them to BOTH translation files, so .tr() resolves in Arabic and English.

=== FILE 2 (NEW) — lib/features/auth/screens/verify_otp_screen.dart ===
class VerifyOtpScreen extends StatefulWidget { final String email; }
Visual language MUST match the existing Signup screen so the flow does not jump:
  - same background gradient (Color(0xFF05857F) -> Color(0xFF0E1C4C)), same white
    Card with radius 20 and elevation 10, same _inputDecoration style (filled white,
    radius 14, no border side), same teal accents.
Behaviour:
  - Title 'تأكيد الحساب'.tr(), subtitle 'بعتنالك كود من 6 أرقام على بريدك'.tr(),
    then the email itself rendered LTR (Directionality + TextDirection.ltr).
  - Pinput(length: 6, keyboardType: TextInputType.number, autofocus on first frame).
    Wrap it in Directionality(textDirection: TextDirection.ltr) so digits fill
    left-to-right inside an RTL app.
  - onCompleted calls _verify automatically — no button press needed.
    Keep a manual 'تأكيد'.tr() button as a fallback for accessibility.
  - Verify success: save the id exactly like the other screens
    (SharedPreferences 'current_user_id' = user.id), then
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false,
        arguments: user.id) and show a teal SnackBar 'تم تأكيد حسابك بنجاح'.tr().
  - Verify failure: set forceErrorState on Pinput, clear it, refocus, and show
    AuthService.errorKey(e).tr() in red under the input (not only a SnackBar).
  - Resend: TextButton disabled while _secondsLeft > 0. Countdown starts at 60 in
    initState and restarts after each successful resend. Use ONE Timer.periodic
    and cancel it in dispose(). Label: 'إعادة إرسال الكود بعد {n} ثانية'
    .tr(namedArgs: {'n': '$seconds'}) while counting, 'إعادة إرسال الكود'.tr() when
    available. easy_localization uses namedArgs, not Dart interpolation.
  - Secondary TextButton 'البريد غلط؟ ارجع تعدله'.tr() -> Navigator.pop().
  - dispose() must release TextEditingController, FocusNode, Timer.
  - Every setState / ScaffoldMessenger / Navigator use after an await must be
    guarded by `if (!mounted) return;`.

=== FILE 3 (EDIT, MINIMAL) — lib/features/auth/screens/signup_screen.dart ===
Keep the widget name `Signup`, the six fields, the design, the validators, and the
existing _saveCurrentUserId helper. Change only the submit logic:

  - Replace the direct Supabase.instance.client.auth.signUp(...) call with
    AuthService.instance.signUp(email:..., password:..., name:..., phone:..., address:...)
  - Keep catching AuthException. Use AuthService.errorKey(e).tr() for the message.
  - Branch:
      if res.session != null  -> existing behaviour (it means Confirm email is OFF):
                                  save id, 'تم إنشاء الحساب بنجاح'.tr(), go to /home.
      else                    -> Navigator.push(MaterialPageRoute(
                                   builder: (_) => VerifyOtpScreen(email: email)))
                                  Do NOT pop and do NOT show the old
                                  "أكد بريدك ثم سجّل الدخول" message any more.
  - No other edit to this file. Do not reformat it, do not rename anything.

=== TRANSLATIONS (assets/translations/ar.json + en.json) ===
Both files are FLAT maps where the Arabic string IS the key. Append these keys
without reordering or reformatting the existing content. Arabic file: key == value.
English file: key == the English text below.

  key (Arabic)                                        | en.json value
  ----------------------------------------------------|--------------------------------------
  تأكيد الحساب                                         | Verify your account
  بعتنالك كود من 6 أرقام على بريدك                     | We sent a 6-digit code to your email
  تم تأكيد حسابك بنجاح                                 | Your account has been verified
  إعادة إرسال الكود                                    | Resend code
  إعادة إرسال الكود بعد {n} ثانية                      | Resend code in {n} seconds
  البريد غلط؟ ارجع تعدله                               | Wrong email? Go back and change it
  تأكيد                                                | Confirm
  من فضلك اكتب الكود كامل                              | Please enter the full code
  الكود غير صحيح أو انتهت صلاحيته                      | The code is wrong or has expired
  بعت كتير، استنى دقيقة وجرب تاني                      | Too many attempts, wait a minute and try again
  إعدادات الإيميل مش مظبوطة، تواصل مع الدعم            | Email settings are misconfigured, contact support
  هذا البريد الإلكتروني مسجل بالفعل                    | This email is already registered
  من فضلك أكد بريدك الإلكتروني أولاً                   | Please verify your email first
  كلمة المرور ضعيفة، استخدم كلمة أقوى                  | Password is too weak, use a stronger one
  تعذر إنشاء الحساب، حاول تاني                         | Could not create the account, try again
  البريد الإلكتروني أو كلمة المرور غير صحيحة           | Wrong email or password
  حصل خطأ، حاول تاني                                   | Something went wrong, please try again

  If a key already exists (e.g. 'حصل خطأ، حاول تاني'), do not duplicate it.
  Validate both files parse as JSON before finishing (python3 -m json.tool).

=== BACKEND DOC (docs/SUPABASE_SETUP.md) ===
Create this file in Arabic. It documents MANUAL dashboard steps only — the agent
must not attempt to change anything in Supabase:
  1) Authentication > Sign In/Providers > Email: "Enable Email provider" ON,
     "Confirm email" ON, OTP length 6, expiry 3600s.
  2) Authentication > Emails > Templates > "Confirm signup": replace the body with
     one that prints {{ .Token }} — explicitly NOT {{ .ConfirmationURL }}, or
     Supabase sends a link instead of a 6-digit code.
  3) Authentication > Emails > SMTP Settings (Gmail):
       Host smtp.gmail.com / Port 587 (465 also works)
       Username = the full Gmail address
       Password = 16-char Google App Password, no spaces (2-Step Verification
       required; the normal password fails with 535-5.7.8)
       Sender email = the same Gmail account or a verified "Send mail as" alias
       Limits: ~500 recipients/day personal, ~2000 Workspace.
  4) Authentication > Rate Limits: raise "Rate limit for sending emails"
     from 30/h after custom SMTP is set.
  5) Troubleshooting table: 535-5.7.8, 534-5.7.9, mail in Spam, daily cap,
     and the diagnostic that proves it is not a code bug — a user stuck at
     "Waiting for verification" in Authentication > Users means signUp worked
     and only delivery failed.

=== QUALITY BAR ===
- Run `flutter analyze`. The project already reports 21 info-level findings
  (withOpacity / activeColor deprecations). Zero NEW warnings or errors are
  allowed; do not "fix" pre-existing ones — that is out of scope.
- const constructors where possible, no unused imports, no print().
- Never log tokens, codes, passwords, or the session object.
- Handle double taps on submit/resend via the loading flag.

=== OUTPUT ===
Reply with:
  (a) the files you created/changed, as a tree, marking NEW vs EDITED,
  (b) a 5-line summary of each,
  (c) the exact diff of signup_screen.dart (it must be small),
  (d) the result of `flutter analyze` with the new-issue count, which must be 0.
```

---

## اللي لازم تعمله بإيدك بعد ما الأداة تخلص

هذه خطوات لوحة Supabase، مفيش أداة بتعملها:

1. **Authentication → Emails → Templates → Confirm signup** → بدّل `{{ .ConfirmationURL }}` بـ `{{ .Token }}`.
2. **Authentication → Sign In/Providers → Email** → `Confirm email` = ON، `OTP length` = 6.
3. **Authentication → Emails → SMTP Settings** → قيم Gmail من جدول الأمر.
4. **Authentication → Rate Limits** → ارفع `emails/h` من 30.

## للتشغيل

```bash
cd ~/AndroidStudioProjects/taraf01
flutter pub get
flutter analyze          # لازم يفضل 21 info ولا حاجة جديدة
flutter run
```

## نقطة مهمة قبل ما تلزق الأمر

المشروع ده متعدّل عندك محليًا في `pubspec.yaml` و`pubspec.lock` (تخفيض قيد الـ SDK من `^3.14.0-211.1.beta` لـ `^3.9.0`) عشان يشتغل على Flutter stable عندك. أي أداة هتقرأ `pubspec.yaml` هتشوف `^3.9.0` — سيبها زي ما هي، متخليهاش ترجّعها للنسخة القديمة.
