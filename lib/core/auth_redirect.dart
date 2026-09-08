/// Parked iOS bundle ID — do not rename until Spencer has an Apple team
/// and a real Firebase iOS app. Must match PRODUCT_BUNDLE_IDENTIFIER,
/// the supabase.auth.callback URL scheme in Info.plist, and the Redirect
/// URL listed in Supabase Authentication → URL Configuration.
const String kIosBundleId = 'com.example.codSquadApp';

/// Android applicationId / Gradle namespace. Must match
/// `android/app/build.gradle.kts`.
const String kAndroidBundleId = 'com.example.cod_squad_app';

/// Apple Developer Team ID. Matches `ios/export_options.plist` teamID.
const String kAppleTeamId = 'K4ZTXPQ8J9';

/// Peacock Lock widget extension bundle ID. Identity declaration only —
/// peacock lock behavior is unchanged.
const String kWidgetBundleId = 'com.example.codSquadApp.PeacockLockWidget';

/// OAuth / magic-link return URL. Register this exact value in Supabase.
const String kSupabaseAuthRedirect = '$kIosBundleId://auth-callback';
