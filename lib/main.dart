import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:http/http.dart' as http;

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();
  String _log = 'output:\n';
  final _apiKey = TextEditingController();
  final _cluster = TextEditingController();
  final _channelName = TextEditingController();
  final _eventName = TextEditingController();
  final _channelFormKey = GlobalKey<FormState>();
  final _eventFormKey = GlobalKey<FormState>();
  final _listViewController = ScrollController();
  final _data = TextEditingController();

  void log(String text) {
    print("LOG: $text");
    setState(() {
      _log += text + "\n";
      Timer(
          const Duration(milliseconds: 100),
          () => _listViewController
              .jumpTo(_listViewController.position.maxScrollExtent));
    });
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  void onConnectPressed() async {
    if (!_channelFormKey.currentState!.validate()) {
      return;
    }
    // Remove keyboard
    FocusScope.of(context).requestFocus(FocusNode());
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("apiKey", _apiKey.text);
    prefs.setString("cluster", _cluster.text);
    prefs.setString("channelName", _channelName.text);

    try {
      await pusher.init(
          apiKey: _apiKey.text,
          cluster: _cluster.text,
          onConnectionStateChange: onConnectionStateChange,
          onError: onError,
          onSubscriptionSucceeded: onSubscriptionSucceeded,
          onSubscriptionError: onSubscriptionError,
          onDecryptionFailure: onDecryptionFailure,
          onMemberAdded: onMemberAdded,
          onMemberRemoved: onMemberRemoved,
          onAuthorizer: onAuthorizer);
      await pusher.subscribe(channelName: _channelName.text);
      await pusher.subscribe(
        channelName: 'private-pazo.call.30', // 30 is te current auth user id
        onEvent: (event) {
          // print(event.eventName == "App\\Events\\StartZoomEvent");
          // print(event.eventName == "App\\Events\\EndZoomEvent");
          // print(event.eventName == "App\\Events\\AnswerZoomEvent");

          if (event.eventName == "App\\Events\\StartZoomEvent") {
            print("onEvent: ${event.data.zoomId}"); // zoom id
            print("onEvent: ${event.data.room}"); // zoom room
            print("onEvent: ${event.data.recipientId}"); // zoom recipient id
            print(
                "onEvent: ${event.data.recipientToken}"); // zoom recipient token
            print("onEvent: ${event.data.callerId}"); // zoom caller id
            print("onEvent: ${event.data.callerName}"); // zoom caller name
            print("onEvent: ${event.data.isVideo}"); // zoom is video
            print("onEvent: ${event.data.startAt}"); // zoom start at

            // Here, you've a call entry, so make an API call to the backend to answer the call : /api/zoom/answer

          }
          if (event.eventName == "App\\Events\\EndZoomEvent") {
            print("onEvent: ${event.data.id}"); // zoom id
            print("onEvent: ${event.data.room}"); // zoom room
            print("onEvent: ${event.data.startAt}"); // zoom start at
            print("onEvent: ${event.data.endAt}"); // zoom end at

            // You've noticed that the call has ended, so make an API call to the backend to end the call : /api/zoom/end
          }
          if (event.eventName == "App\\Events\\AnswerZoomEvent") {
            // Join the Zoom room
            print("onEvent: ${event.data.id}"); // zoom id
            print("onEvent: ${event.data.room}"); // zoom room
            print("onEvent: ${event.data.startAt}"); // zoom start at
            print("onEvent: ${event.data.endAt}"); // zoom end at

          }
        },
      );
      await pusher.connect();
    } catch (e) {
      log("ERROR: $e");
    }
  }

  void onConnectionStateChange(dynamic currentState, dynamic previousState) {
    log("Connection: $currentState");
  }

  void onError(String message, int? code, dynamic e) {
    log("onError: $message code: $code exception: $e");
  }

  void onEvent(PusherEvent event) {
    log("onEvent:  ${event.eventName} => ${event.data}");
    // check if event name is App\Events\StartZoomEvent

    if (event.eventName == "App\Events\UserOnlinePresenceEvent") {
      // look data return from this event
      log('User is online');
    }

    if (event.eventName == "App\Events\UserOfflinePresenceEvent") {
      // look data return from this event
      log('User is offline');
    }
  }

  void onSubscriptionSucceeded(String channelName, dynamic data) {
    log("onSubscriptionSucceeded: $channelName data: $data");
    final me = pusher.getChannel(channelName)?.me;
    log("Me: $me");
  }

  void onSubscriptionError(String message, dynamic e) {
    log("onSubscriptionError: $message Exception: ${e.toString()}");
  }

  void onDecryptionFailure(String event, String reason) {
    log("onDecryptionFailure: $event reason: $reason");
  }

  void onMemberAdded(String channelName, PusherMember member) {
    log("onMemberAdded: $channelName user: $member");
  }

  void onMemberRemoved(String channelName, PusherMember member) {
    log("onMemberRemoved: $channelName user: $member");
  }

  dynamic onAuthorizer(
      String channelName, String socketId, dynamic options) async {
    var authUrl = 'https://192.168.1.171:8000/api/broadcasting/auth';
    var result = await http.post(
      Uri.parse(authUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Bearer 1|0WfsyAMsBdZDJIVUxpqsHclIP2wZAKtrBWCwD7W6',
      },
      body: 'socket_id=$socketId&channel_name=$channelName',
    );

    try {
      var json = jsonDecode(result.body);
      return json;
    } catch (e) {
      log("onAuthorizer: $e");
    }
  }

  void onTriggerEventPressed() async {
    var eventFormValidated = _eventFormKey.currentState!.validate();

    if (!eventFormValidated) {
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("eventName", _eventName.text);
    prefs.setString("data", _data.text);
    pusher.trigger(PusherEvent(
        channelName: _channelName.text,
        eventName: _eventName.text,
        data: _data.text));
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey.text = prefs.getString("apiKey") ?? 'be33aa1f988ab2d44db6';
      _cluster.text = prefs.getString("cluster") ?? 'mt1';
      _channelName.text =
          prefs.getString("channelName") ?? 'presence-user.presence';
      _eventName.text = prefs.getString("eventName") ?? 'client-event';
      _data.text = prefs.getString("data") ?? 'test';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(pusher.connectionState == 'DISCONNECTED'
              ? 'Pusher Channels Example'
              : _channelName.text),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListView(
              controller: _listViewController,
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              children: <Widget>[
                if (pusher.connectionState != 'CONNECTED')
                  Form(
                      key: _channelFormKey,
                      child: Column(children: <Widget>[
                        TextFormField(
                          controller: _apiKey,
                          validator: (String? value) {
                            return (value != null && value.isEmpty)
                                ? 'Please enter your API key.'
                                : null;
                          },
                          decoration:
                              const InputDecoration(labelText: 'API Key'),
                        ),
                        TextFormField(
                          controller: _cluster,
                          validator: (String? value) {
                            return (value != null && value.isEmpty)
                                ? 'Please enter your cluster.'
                                : null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Cluster',
                          ),
                        ),
                        TextFormField(
                          controller: _channelName,
                          validator: (String? value) {
                            return (value != null && value.isEmpty)
                                ? 'Please enter your channel name.'
                                : null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Channel',
                          ),
                        ),
                        ElevatedButton(
                          onPressed: onConnectPressed,
                          child: const Text('Connect'),
                        )
                      ])),
                SingleChildScrollView(
                    scrollDirection: Axis.vertical, child: Text(_log)),
              ]),
        ),
      ),
    );
  }
}
