# InterviewIQ for iPhone

Native SwiftUI app (iOS 17+) for InterviewIQ members. It uses the same Supabase project as the web portal.

## Run it on a Mac

1. Install Xcode 16 or later from the Mac App Store.
2. Install XcodeGen: `brew install xcodegen`
3. In this `ios` folder, run `xcodegen generate`, then open `InterviewIQ.xcodeproj`.
4. Select the **InterviewIQ** target → **Signing & Capabilities** → choose your Apple Developer team.
5. Pick an iPhone simulator (or your own iPhone) and press **Run** (⌘R).

The `.xcodeproj` is generated from `project.yml` and is not committed. Change `project.yml`, not the project file.

## Sign-in

Members sign in with the 6-digit code from the Supabase "Magic link or OTP" email. That email template must include `{{ .Token }}`.

## Layout

| Folder | Contents |
|---|---|
| `InterviewIQ/App` | App entry point, tab bar, config |
| `InterviewIQ/Design` | Brand colours and shared components (cards, score ring, buttons) |
| `InterviewIQ/Models` | Database row types |
| `InterviewIQ/Services` | Supabase client, data loading, auth state |
| `InterviewIQ/Features` | One folder per screen |
| `InterviewIQTests` | Unit tests |

CI (`.github/workflows/ios.yml`) builds the app and runs the tests on a macOS runner for every push that touches `ios/`.
