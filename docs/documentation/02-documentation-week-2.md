# Velo: Your Canvas Co-pilot - Documentation

## 1. Overview
Velo is a distraction-free, local-first mobile client for the Canvas LMS designed to help university students manage heavy project workloads. 
It consolidates active tasks across all subjects into a single, chronologically sorted mobile feed and features a conversational AI Assistant for querying syllabus details and planning tasks in natural language.

## 2. Setup and installation
Every step to get the app running from nothing, in order:

- The Flutter and Dart versions you built with: Flutter >=3.44.0, Dart >=3.12.0.
- How to get the code (clone):
  `git clone <your-repository-url>`
  `cd velo-better-canvas`
- `flutter pub get` and dependencies:
  Run `flutter pub get` to download the required dependencies. Based on current features, the app relies on:
  - `provider`: Global state management.
  - `shared_preferences`: Local-first offline caching and storage.
  - `go_router`: Persistent global navigation and routing.
  - `google_generative_ai`: Gemini AI Assistant integration.
  - `flutter_dotenv`: Environment variable management.
  - `http`: REST API communication with Canvas LMS.
  - `intl`: Date formatting.
  - `url_launcher`: Opening external Canvas links.
  - `flutter_widget_from_html`: Rich HTML rendering for Canvas announcements and modules.
  - `flutter_local_notifications`: Push notifications.
  - `file_picker`: Attachment selection for assignment submissions.
  - `device_preview`: Web-based device testing.
  - `cupertino_icons`: Default UI icons.
- Configuration:
  Create a `.env` file in the root directory based on `.env.example`. Populate it with your API keys (never commit these):
  ```env
  GEMINI_API_KEY=
  CANVAS_BASE_URL=
  CANVAS_API_TOKEN=
  ```

## 3. How to run it
To run the app under development and avoid CORS issues while testing, use the following command:
```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```
Once running, you will see the application launch in a Chrome window with web security disabled. 
This bypasses browser CORS restrictions, allowing seamless testing with the Canvas REST API before the app is fully published.

## 4. Features and usage
- Authentication (Login Screen): The initial screen presents a "Log in with Canvas" button that simulates a secure OAuth 2.0 handshake to authenticate without storing raw passwords.
- Global Navigation (App Shell): A persistent top app bar and borderless BottomNav allow users to seamlessly switch between the Dashboard, AI Assistant, and Courses tabs.
- Dashboard (My Tasks): A central hub for viewing pending tasks and active assignments across all courses, featuring dynamic filtering and sorting.
- Courses & Modules: A dedicated course hub allowing users to drill down into specific Modules, Assignments, Grades, and Announcements, as well as submit work.
- Inbox: Users can view threaded conversations from Canvas and compose new messages (with file attachments) to instructors or peers.
- AI Assistant: A conversational chat interface powered by Gemini to ask about course deadlines, summarize announcements, and help manage workloads.

## 5. Project structure
```text
Velo-A-better-canvas/
├── docs/
│   ├── assets/
│   ├── documentation/
│   ├── journal/
│   ├── 01-proposal.md
│   ├── 02-mockup.md
│   ├── 03-design-system.md
│   ├── 04-weekly-reports.md
│   ├── 05-demo-video.md
│   ├── 06-security-and-privacy.md
│   └── README.md
├── lib/
│   ├── components/
│   │   ├── app_shell.dart
│   │   ├── bottom_nav.dart
│   │   ├── chat_bubble.dart
│   │   ├── error_dialog.dart
│   │   ├── offline_banner.dart
│   │   ├── side_drawer.dart
│   │   └── task_card.dart
│   ├── data/
│   ├── models/
│   │   ├── course.dart
│   │   └── task.dart
│   ├── screens/
│   │   ├── account_screen.dart
│   │   ├── ai_assistant_screen.dart
│   │   ├── compose_message_screen.dart
│   │   ├── conversation_detail_screen.dart
│   │   ├── course_announcements_screen.dart
│   │   ├── course_assignments_screen.dart
│   │   ├── course_detail_screen.dart
│   │   ├── course_grades_screen.dart
│   │   ├── course_modules_screen.dart
│   │   ├── courses_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── inbox_screen.dart
│   │   ├── login_screen.dart
│   │   ├── module_item_detail_screen.dart
│   │   └── task_detail_screen.dart
│   ├── services/
│   │   └── canvas_service.dart
│   ├── state/
│   │   └── app_state.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── main.dart
├── test/
│   └── widget_test.dart
├── web/
│   ├── index.html
│   └── manifest.json
├── .env
├── .env.example
├── .flutter-plugins-dependencies
├── .gitignore
├── AI-USAGE.md
├── analysis_options.yaml
├── LICENSE
├── pubspec.lock
├── pubspec.yaml
├── README.md
├── REPORT.md
└── START-HERE.md
```

## 6. Screenshots

| Courses | Dashboard | AI Assistant |
| --- | --- | --- |
| <img src="/docs/assets/courses_w2.png" alt="Courses" width="250"> | <img src="/docs/assets/dashboard_w2.png" alt="Dashboard" width="250"> | <img src="/docs/assets/ai_w2.png" alt="AI Assistant" width="250"> |
 
| Side Drawer | Inbox | Announcements |
| --- | --- | --- |
| <img src="/docs/assets/sidedrawer_w2.png" alt="Side Drawer" width="250"> | <img src="/docs/assets/inbox_w2.png" alt="Inbox" width="250"> | <img src="/docs/assets/announcement_w2.png" alt="Announcements" width="250"> |
 
| Modules | Grades | Assignments |
| --- | --- | --- |
| <img src="/docs/assets/modules_w2.png" alt="Modules" width="250"> | <img src="/docs/assets/grades_w2.png" alt="Grades" width="250"> | <img src="/docs/assets/assignments_w2.png" alt="Assignments" width="250"> |

## 7. Known issues and next steps
**Known Issues:**
- The Master Dashboard UI is currently in progress and being actively refined.
- The interactive Planner hub has not yet been built.
- While the AI Assistant and Canvas API are both integrated, the AI responses need deeper contextual integration with the local data state to provide highly tailored schedule auto-planning.

**Next Steps:**
- Finish the Dashboard screen and complete any remaining secondary UI elements.
- Deeply integrate the AI into the app's data layer so that chat responses are accurately tailored to the user's specific courses, tasks, and deadlines.
- Build the Planner hub and wire up the AI to automatically schedule and plan tasks for the user.
- Finalize the codebase for web deployment, as next week will be the deployment week.

## AI usage
This repository includes an `AI-USAGE.md` file detailing the prompt engineering, generative models used, and implementation context utilized during the development of this application.
