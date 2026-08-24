# R8 rules for the release build.
#
# Kept deliberately short. Every line here is a class R8 would otherwise
# remove or rename, and a rule that is not needed hides one that is.

# Flutter's embedding reaches these reflectively.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# `flutter_local_notifications` deserializes its scheduled-notification
# payloads with Gson, which is reflection over field NAMES — R8 renaming them
# turns every reminder armed before the update into a silent no-op after it.
-keep class com.dexterous.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-dontwarn com.dexterous.**

# Flutter's embedding references Play Core's deferred-components API from
# `FlutterPlayStoreSplitApplication` and `PlayStoreDeferredComponentManager`.
# This app declares no deferred components and never instantiates either, so
# the classes are genuinely absent and the references are unreachable.
#
# `-dontwarn`, deliberately NOT a dependency on `com.google.android.play:core`.
# Adding the library to silence R8 would ship a Play-services dependency for a
# feature nobody uses, in an app whose entire premise is that it talks to
# nothing.
#
# Found by the first release build ever run on this code — which is exactly
# what EPIC-15 task 9 says a release build is for.
-dontwarn com.google.android.play.core.**
