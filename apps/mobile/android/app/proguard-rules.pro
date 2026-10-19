# shared_preferences calls Kotlin suspend functions through JNI.
# R8 must keep these names or getAll/setBool disappear and settings cannot be saved.
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn kotlin.coroutines.**
