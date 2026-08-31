/// Parked iOS bundle ID — do not rename until Spencer has an Apple team
/// and a real Firebase iOS app. Must match PRODUCT_BUNDLE_IDENTIFIER,
/// the supabase.auth.callback URL scheme in Info.plist, and the Redirect
/// URL listed in Supabase Authentication → URL Configuration.
const String kIosBundleId = 'com.example.codSquadApp';

/// OAuth / magic-link return URL. Register this exact value in Supabase.
const String kSupabaseAuthRedirect = '$kIosBundleId://auth-callback';
