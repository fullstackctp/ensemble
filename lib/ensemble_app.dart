import 'dart:convert';
import 'dart:ui';
import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:ensemble/deep_link_manager.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/secrets.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/widget/error_screen.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/upload_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:workmanager/workmanager.dart';

import 'framework/theme/theme_loader.dart';

const String backgroundUploadTask = 'backgroundUploadTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case backgroundUploadTask:
        if (inputData == null) {
          throw LanguageError('Failed to parse data to upload');
        }
        try {
          final sendPort =
              IsolateNameServer.lookupPortByName(inputData['taskId']);
          final response = await UploadUtils.uploadFiles(
            fieldName: inputData['fieldName'] ?? 'file',
            files: (inputData['files'] as List)
                .map((e) => File.fromJson(json.decode(e)))
                .toList(),
            headers:
                Map<String, String>.from(json.decode(inputData['headers'])),
            method: inputData['method'],
            url: inputData['url'],
            fields: Map<String, String>.from(json.decode(inputData['fields'])),
            showNotification: inputData['showNotification'],
            progressCallback: (progress) {
              if (sendPort == null) return;
              sendPort.send({
                'progress': progress,
                'taskId': inputData['taskId'],
              });
            },
            onError: (error) {
              if (sendPort == null) return;
              sendPort.send(
                  {'error': error.toString(), 'taskId': inputData['taskId']});
            },
            taskId: inputData['taskId'],
          );

          if (sendPort == null || response == null) return response == null;

          sendPort.send({
            'responseBody': response.body,
            'taskId': inputData['taskId'],
            'responseHeaders': response.headers,
          });
        } catch (e) {
          throw LanguageError('Failed to process backgroud upload task');
        }
        break;
      default:
        throw LanguageError('Unknown background task: $task');
    }
    return Future.value(true);
  });
}

/// use this as the root widget for Ensemble
class EnsembleApp extends StatefulWidget {
  const EnsembleApp({
    super.key,
    this.screenPayload,
    this.ensembleConfig,
    this.isPreview = false,
    this.placeholderBackgroundColor,
  });

  final ScreenPayload? screenPayload;
  final EnsembleConfig? ensembleConfig;
  final bool isPreview;

  /// use this as the placeholder background while Ensemble is loading
  final Color? placeholderBackgroundColor;

  @override
  State<StatefulWidget> createState() => EnsembleAppState();
}

class EnsembleAppState extends State<EnsembleApp> {
  late Future<EnsembleConfig> config;

  @override
  void initState() {
    super.initState();
    config = initApp();
    DeepLinkManager().init();
    if (!kIsWeb) {
      Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    }
  }

  /// initialize our App with the the passed in config or
  /// read from our ensemble-config file.
  Future<EnsembleConfig> initApp() async {
    await Ensemble().initManagers();
    StorageManager().setIsPreview(widget.isPreview);

    // use the config if passed in
    if (widget.ensembleConfig != null) {
      // set the Ensemble config
      Ensemble().setEnsembleConfig(widget.ensembleConfig!);

      // if appBundle is not passed in, fetch it now
      if (widget.ensembleConfig!.appBundle == null) {
        return widget.ensembleConfig!.updateAppBundle();
      }
      return Future<EnsembleConfig>.value(widget.ensembleConfig);
    }
    // else init from config file
    else {
      return Ensemble().initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: config,
        builder: ((context, snapshot) {
          if (snapshot.hasError) {
            return _appPlaceholderWrapper(
                widget: ErrorScreen(LanguageError("Error loading configuration",
                    detailError: snapshot.error.toString())));
          }

          // at this point we don't yet have the theme. It's best to have
          // a blank screen to prevent any background color changing while
          // the app is loading
          if (!snapshot.hasData) {
            // blank loading screen
            return _appPlaceholderWrapper(
                placeholderBackgroundColor: widget.placeholderBackgroundColor);
          }

          return renderApp(snapshot.data as EnsembleConfig);
        }));
  }

  Widget renderApp(EnsembleConfig config) {
    //log("EnsembleApp build() - $hashCode");
    StorageManager().setIsPreview(widget.isPreview);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: Utils.globalAppKey,
      theme: config.getAppTheme(),
      localizationsDelegates: [
        config.getI18NDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      home: Scaffold(
        // this outer scaffold is where the background image would be (if
        // specified). We do not want it to resize on keyboard popping up.
        // The Page's Scaffold can handle the resizing.
        resizeToAvoidBottomInset: false,

        body: Builder(
          builder: (context) {
            Theme.of(context).extension<EnsembleThemeExtension>();

            return Screen(
              key: UniqueKey(),
              appProvider:
                  AppProvider(definitionProvider: config.definitionProvider),
              screenPayload: widget.screenPayload,
            );
          },
        ),
      ),
      useInheritedMediaQuery: widget.isPreview,
      locale: widget.isPreview ? DevicePreview.locale(context) : null,
      builder: widget.isPreview
          ? DevicePreview.appBuilder
          : FlutterI18n.rootAppBuilder(),
      // TODO: this case translation issue on hot loading. Address this for RTL support
      //builder: (context, widget) => FlutterI18n.rootAppBuilder().call(context, widget)
    );
  }

  /// we are at the root here. Error/Spinner widgets need
  /// to be wrapped inside MaterialApp
  Widget _appPlaceholderWrapper(
      {Widget? widget, Color? placeholderBackgroundColor}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(backgroundColor: placeholderBackgroundColor, body: widget),
    );

  }
}
