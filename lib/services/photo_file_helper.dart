/// Profile/account photo file operations, isolated behind a conditional
/// import so the mobile screens that use them (`home_screen`, `profile_screen`)
/// still compile for web — the demo web build boots the sodero UI, and a
/// direct `import 'dart:io'` would break `flutter build web`.
///
/// On native these touch `dart:io` + `path_provider`; on web they are no-ops
/// and the avatar falls back to the cloud URL / placeholder icon (profile
/// edits are demo-gated anyway). Mirrors `platform_file_helper.dart`'s split.
library;

export 'photo_file_helper_web.dart';
