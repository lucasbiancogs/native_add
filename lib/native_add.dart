import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'dart:isolate';

final DynamicLibrary nativeAddLib = Platform.isAndroid
    ? DynamicLibrary.open("libnative_add.so")
    : DynamicLibrary.process();

final int Function(int x, int y) nativeAdd = nativeAddLib
    .lookup<NativeFunction<Int32 Function(Int32, Int32)>>("native_add")
    .asFunction();

final Future<SendPort> Function() initIsolate = _initIsolate;

Future<SendPort> _initIsolate() async {
  // O completer é algo para ser completado no futuro
  Completer completerSendPort = new Completer<SendPort>();

  // Isso é uma porta que iremos ouvir o isolate
  // Por isso isolate -> mainStream
  ReceivePort isolateToMainStream = ReceivePort();

  final isolate = await Isolate.spawn(myIsolate, isolateToMainStream.sendPort);

  isolateToMainStream.listen(
    // Aqui inscrevemos um listen na porta

    (message) {
      if (message is SendPort) {
        SendPort mainToIsolateStream = message;

        completerSendPort.complete(mainToIsolateStream);
      } else if (message == 'stop') {
        if (isolate != null) {
          isolate.kill();
        }
      } else {
        print('[isolateToMainStream] $message');
      }
    },
  );

  return completerSendPort.future;
}

void myIsolate(SendPort isolateToMainStream) {
  int backgroundCounter = 0;
  int foregroundCounter = 0;

  void updateCounter() {
    backgroundCounter++;

    print('[isolate] backgroundCounter: $backgroundCounter');
    print('[isolate] foregroundCounter: $foregroundCounter');
  }

  Timer.periodic(Duration(seconds: 1), (timer) {
    updateCounter();
  });

  ReceivePort mainToIsolateStream = ReceivePort();

  isolateToMainStream.send(mainToIsolateStream.sendPort);

  mainToIsolateStream.listen((message) {
    if (message is int) {
      foregroundCounter = message;
    }

    if (message == 'stop') {
      isolateToMainStream.send(message);
    }

    print('[mainToIsolateStream] $message');
  });

  isolateToMainStream.send('This is from myIsolate');
}
