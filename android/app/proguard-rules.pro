# 디버깅과 매핑을 위한 설정
-printmapping mapping.txt
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Flutter specific ProGuard rules

# Flutter 웹뷰 관련 규칙
-keep class com.google.android.** { *; }
-keep class androidx.webkit.** { *; }

# Flutter 네이티브 코드 관련 규칙
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.engine.** { *; }

# 지연 컴포넌트 관련 규칙 (R8 오류 해결)
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
# -keep class com.google.android.play.core.** { *; }

# Hive 라이브러리 관련 규칙
-keep class hive.** { *; }
-keep class io.hive.** { *; }
-keep class **$$TypeAdapter { *; }

# URL Launcher 관련 규칙
-keep class com.android.webview.chromium.** { *; }

# Share Plus 관련 규칙
-keep class androidx.core.app.** { *; }
-keep class androidx.core.content.** { *; }

# JSON 직렬화 관련 규칙
-keepattributes Signature
-keepattributes *Annotation*

# 예외 정보 유지
-keepattributes SourceFile,LineNumberTable
-keepattributes Exceptions

# 기본 Android 컴포넌트 유지
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.view.View 

# Kotlin 관련 규칙
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keep class kotlin.reflect.** { *; }
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Crashlytics 관련 규칙
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }
-keepattributes *Annotation*

# Enum 유지
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# R8 전체 패키지 최적화 비활성화
-optimizations !class/unboxing/enum 

# 새로운 Play 라이브러리 규칙
-keep class com.google.android.play.core.appupdate.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.install.** { *; }
-keep class com.google.android.play.core.assetpacks.** { *; }
-keep class com.google.android.play.assetdelivery.** { *; }

# Flutter 지연 컴포넌트 관련 명시적 규칙
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn com.google.android.play.core.** 