 # 🚀 AURONEXIS Agent Suite
 
 **منظومة التحكم المتكاملة لوكلاء الذكاء الاصطناعي البرمجية (Claude Code, Codex, OpenCode, Hermes) من الهاتف وسطح المكتب مع دعم أصيل للواجهة العربية (Arabic AI Interface).**
 
 ---
 
 ## ✨ المميزات الرئيسية (Key Features)
 
 - 🌐 **Arabic AI Interface:** واجهة تفاعلية كاملة تدعم اللغة العربية مع خط Cairo المريح للعين مع الحفاظ الدقيق على المصطلحات التقنية.
 - 📱 **Native Mobile Companion:** تطبيق هاتف متكامل يتيح لك إدارة ومراقبة الوكلاء عن بُعد عبر شبكة Wi-Fi بنقرة واحدة.
 - ⚡ **Universal CLI Orchestration:** دعم كامل لأدوات:
   - **Anthropic Claude Code**
   - **OpenAI Codex CLI**
   - **OpenCode & Hermes Agent**
   - بالإضافة إلى دعم تشغيل أي CLI مخصص (Custom CLI).
 - 📂 **Workspace & Live Git Inspector:** استعراض شجرة ملفات المشروع، قراءة الأكواد، وفحص حالة Git والـ Diffs اللحظية مباشرة من هاتفك.
 - 🛑 **Real-Time Control:** إيقاف فوري لتوليد الأكواد (Abort Generation)، وتتبع استهلاك الـ Tokens وسجل الجلسات.
 
 ---
 
 ## 🛠️ هيكل المشروع (Project Architecture)
 
 - `server_auronexis/` : محرك السيرفر المتكامل (Node.js + Express + WebSocket + React WebUI تحت هوية AURONEXIS).
 - `app_flutter/` : تطبيق الهاتف الذكي (Flutter + Material 3 + Iconsax + Mobile Scanner).
 - `server/` : محرك الجسر الخفيف البديل (Lightweight Host Bridge).
 
 ---
 
 ## 🚀 البدء السريع (Quick Start)
 
### 1. تشغيل السيرفر المكتبي (Desktop Server)
```bash
cd server_auronexis
npm install
npm run server:dev
```
 سيعمل السيرفر فوراً على:
 👉 `http://localhost:8088` (أو عبر عنوان IP المحلي على شبكة Wi-Fi).
 
 ### 2. تثبيت تطبيق الهاتف (Mobile App)
 يمكنك تحميل ملف **APK** الجاهز مباشرة من قسم **[Releases](https://github.com/AmmarNineveh/auronexis-agent-suite/releases)** وتثبيته على جهاز الأندرويد، أو تشغيله عبر Flutter:
 ```bash
 cd app_flutter
 flutter run
 ```
 
 ---
 
 ## 📜 License
 Distributed under the **GNU AGPLv3 License**.  
 Developed with ❤️ by **AURONEXIS Team**.
