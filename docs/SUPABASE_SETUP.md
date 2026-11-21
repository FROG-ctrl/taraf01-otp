# إعداد Supabase لكود تأكيد الحساب (6 أرقام)

هذا الملف يوثّق خطوات **لوحة Supabase** اليدوية. الكود في التطبيق جاهز بالفعل،
لكن بدون هذه الخطوات ستصلك رسالة فيها **لينك** بدل الكود، أو لن تصلك رسالة أصلًا.

المسار الكامل داخل التطبيق:

```
شاشة التسجيل  →  AuthService.signUp()  →  Supabase ترسل كود 6 أرقام
      →  شاشة الكود  →  AuthService.verifySignupOtp()  →  المستخدم مسجل الدخول
```

---

## 1) تفعيل مزوّد البريد وتأكيد البريد

**Authentication → Sign In / Providers → Email**

| الإعداد | القيمة |
|---|---|
| Enable Email provider | **مفعّل** |
| Confirm email | **مفعّل** — بدونه لا يُرسَل كود أصلًا |
| Email OTP length | **6** |
| Email OTP expiry | **3600** ثانية (ساعة) |

> لو أطفأت `Confirm email` مؤقتًا للتطوير، فإن `signUp` يرجع جلسة فورًا
> وتتحول الشاشة إلى `/home` مباشرة — السطر مكتوب في `signup_screen.dart`.

---

## 2) تغيير قالب الإيميل من لينك إلى كود — أهم خطوة

**Authentication → Emails → Templates → Confirm signup**

القالب الافتراضي يحتوي:

```html
<a href="{{ .ConfirmationURL }}">Confirm your email</a>
```

استبدل المحتوى بالكامل بـ:

```html
<h2>كود تفعيل حسابك</h2>
<p>كودك هو:</p>
<h1 style="font-size:32px; letter-spacing:8px;">{{ .Token }}</h1>
<p>الكود صالح لمدة ساعة. لو لم تقم بإنشاء الحساب، تجاهل هذه الرسالة.</p>
```

**لا تستخدم `{{ .ConfirmationURL }}` في هذا القالب.** وجوده يعني أن التطبيق
سيستقبل «لا يوجد كود» بينما الرسالة تحتوي رابطًا فقط.

---

## 3) ضبط SMTP على Gmail

**Authentication → Emails → SMTP Settings → Enable Custom SMTP**

| الخانة | القيمة |
|---|---|
| Host | `smtp.gmail.com` |
| Port | `587` (STARTTLS — و`465` يعمل بـ SSL) |
| Username | البريد كاملًا `yourapp@gmail.com` |
| Password | **App Password** من 16 حرفًا بدون مسافات |
| Sender email | نفس البريد، أو alias مُتحقَّق في «Send mail as» |
| Sender name | اسم التطبيق |
| Minimum interval | 60 ثانية |

### توليد App Password

1. `myaccount.google.com/security` → تفعيل **2-Step Verification** (بدونها الصفحة لا تظهر).
2. `myaccount.google.com/apppasswords` → الاسم `Supabase SMTP` → **Create**.
3. انسخ الـ 16 حرفًا مرة واحدة، بدون مسافات.

كلمة مرور Gmail العادية لن تعمل وستُرجع `535-5.7.8 Username and Password not accepted`.

> جوجل تعيد كتابة خانة `From`، لذا يجب أن يكون `Sender email` هو نفس الحساب
> المُصادَق عليه أو alias مسموحًا به، وإلا فشل الإرسال أو رجع إلى صندوقك.

### الحدود

| البند | Gmail شخصي | Google Workspace |
|---|---|---|
| مستقبلون في اليوم | ~500 | ~2000 |
| مناسب للإنتاج | لا | نسبيًا |

---

## 4) رفع حدود الإرسال

**Authentication → Rate Limits**

| الحد | القيمة الافتراضية |
|---|---|
| Rate limit for sending emails | 2/ساعة قبل SMTP مخصص، **30/ساعة** بعده |
| Interval between requests per user | 60 ثانية |

الخطوة الرابعة ضرورية: إضافة SMTP وحدها لا ترفع الحد تلقائيًا.

---

## 5) تشخيص الأخطاء

| الرسالة / الحالة | المعنى | الحل |
|---|---|---|
| `535-5.7.8 Username and Password not accepted` | كلمة مرور عادية أو App Password بمسافات | أنشئ App Password جديدًا وتأكد من 2FA |
| `534-5.7.9 Application-specific password required` | ما زال يستخدم كلمة مرور الحساب | App Password إلزامي |
| `email_address_not_authorized` | خدمة الإرسال الافتراضية تسمح لأعضاء الفريق فقط | أضف SMTP مخصصًا |
| 429 / `over_email_send_rate_limit` | تجاوزت الحد | انتظر دقيقة، والعداد 60 ثانية في الشاشة يحمي من هذا |
| الرسالة في Spam | سمعة Gmail الشخصي ضعيفة | طبيعي للتطوير؛ للإنتاج استخدم Resend/Brevo |
| **لا تصل رسالة أصلًا** | ليست مشكلة كود | **Authentication → Users**: لو المستخدم بحالة `Waiting for verification` فالحساب أُنشئ بنجاح والإرسال وحده فشل. راجع **Logs → Auth Logs** لرسالة SMTP الحقيقية |

---

## 6) ملاحظات مرتبطة بكود المشروع

- `AuthService.signUp` يرسل `data: {name, phone, address}` — هناك **trigger** في قاعدة
  البيانات يستهلكها لإنشاء صف المستخدم. لا تحذف هذه الخريطة.
- بعد `verifyOTP` تُحفظ الجلسة تلقائيًا، وتُكتب قيمة `current_user_id` في
  `SharedPreferences` مثل باقي شاشات المشروع.
- `AuthService.errorKey` ترجع **مفتاح ترجمة** (نص عربي) وتتولى الشاشة استدعاء `.tr()`.
  أي تعديل على النصوص يجب أن يضاف إلى `assets/translations/ar.json` و`en.json`
  بنفس النص العربي كمفتاح (الملفان مسطّحان بدون تداخل).
