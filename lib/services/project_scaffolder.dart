import 'dart:io';

/// بيانات الإنشاء التي تجمعها شاشة "إنشاء مشروع جديد"
class NewProjectSpec {
  final String appName;
  final String packageName;
  final String flutterVersion;
  final String targetApi;
  final bool isPrivateRepo;
  final File? iconFile;

  NewProjectSpec({
    required this.appName,
    required this.packageName,
    required this.flutterVersion,
    required this.targetApi,
    required this.isPrivateRepo,
    this.iconFile,
  });
}

/// يبني هيكل مشروع Flutter قياسي من الصفر على الجهاز — بديل عن أمر
/// `flutter create` الذي لا يتوفر بدون Flutter SDK مثبت محليًا.
/// البنية الناتجة متوافقة تمامًا مع ما يتوقعه workflow البناء على GitHub
/// Actions (نفس ما يولّده `flutter create` فعليًا: pubspec.yaml، lib/main.dart،
/// ومجلد android/ بالحد الأدنى اللازم لتصريف APK).
class ProjectScaffolder {
  /// يُنشئ مجلد المشروع الكامل داخل appProjectsDir، ويرجع المسار النهائي.
  Future<Directory> createProject(Directory appProjectsDir, NewProjectSpec spec) async {
    final projectDir = Directory('${appProjectsDir.path}/${spec.appName}');
    if (await projectDir.exists()) {
      throw Exception('يوجد مشروع بنفس الاسم بالفعل');
    }
    await projectDir.create(recursive: true);

    await _writePubspec(projectDir, spec);
    await _writeMainDart(projectDir, spec);
    await _writeAnalysisOptions(projectDir);
    await _writeGitignore(projectDir);
    await _writeAndroidFiles(projectDir, spec);

    if (spec.iconFile != null) {
      await _copyIcon(projectDir, spec.iconFile!);
    }

    return projectDir;
  }

  Future<void> _writePubspec(Directory dir, NewProjectSpec spec) async {
    final content = '''
name: ${_toSnakeCase(spec.appName)}
description: ${spec.appName}
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
''';
    await File('${dir.path}/pubspec.yaml').writeAsString(content);
  }

  Future<void> _writeMainDart(Directory dir, NewProjectSpec spec) async {
    final libDir = Directory('${dir.path}/lib')..createSync();
    final content = '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${spec.appName}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('${spec.appName}')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('عدد الضغطات:'),
            Text('\$_counter', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _counter++),
        child: const Icon(Icons.add),
      ),
    );
  }
}
''';
    await File('${libDir.path}/main.dart').writeAsString(content);
  }

  Future<void> _writeAnalysisOptions(Directory dir) async {
    const content = '''
include: package:flutter_lints/flutter.yaml
''';
    await File('${dir.path}/analysis_options.yaml').writeAsString(content);
  }

  Future<void> _writeGitignore(Directory dir) async {
    const content = '''
.dart_tool/
.packages
build/
*.lock
''';
    await File('${dir.path}/.gitignore').writeAsString(content);
  }

  /// يكتب الحد الأدنى من ملفات android/ اللازمة لـ `flutter build apk` —
  /// AndroidManifest.xml وbuild.gradle وsettings.gradle، باستخدام اسم
  /// الحزمة وTarget API اللذين اختارهما المستخدم.
  Future<void> _writeAndroidFiles(Directory dir, NewProjectSpec spec) async {
    final appMainDir = Directory('${dir.path}/android/app/src/main')..createSync(recursive: true);
    final kotlinPackagePath = spec.packageName.replaceAll('.', '/');
    final kotlinDir = Directory('${dir.path}/android/app/src/main/kotlin/$kotlinPackagePath')
      ..createSync(recursive: true);

    await File('${appMainDir.path}/AndroidManifest.xml').writeAsString('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:label="${spec.appName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2"/>
    </application>
</manifest>
''');

    await File('${kotlinDir.path}/MainActivity.kt').writeAsString('''
package ${spec.packageName}

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
''');

    await File('${dir.path}/android/settings.gradle').writeAsString('''
pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        file("local.properties").withInputStream { properties.load(it) }
        def path = properties.getProperty("flutter.sdk")
        assert path != null, "flutter.sdk not set in local.properties"
        return path
    }()
    includeBuild("\$flutterSdkPath/packages/flutter_tools/gradle")
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.1.0" apply false
    id "org.jetbrains.kotlin.android" version "1.9.10" apply false
}

include ":app"
''');

    final targetApiNumber = RegExp(r'\\d+').firstMatch(spec.targetApi)?.group(0) ?? '34';

    await File('${dir.path}/android/app/build.gradle').writeAsString('''
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    namespace "${spec.packageName}"
    compileSdk $targetApiNumber

    defaultConfig {
        applicationId "${spec.packageName}"
        minSdk 21
        targetSdk $targetApiNumber
        versionCode 1
        versionName "1.0.0"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}

flutter {
    source "../.."
}
''');
  }

  Future<void> _copyIcon(Directory projectDir, File iconFile) async {
    final mipmapDir = Directory('${projectDir.path}/android/app/src/main/res/mipmap-xxxhdpi')
      ..createSync(recursive: true);
    await iconFile.copy('${mipmapDir.path}/ic_launcher.png');
  }

  String _toSnakeCase(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
