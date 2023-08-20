library flutter_client_sse;

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

part 'sse_event_model.dart';

class SSEClient {
  static http.Client _client = http.Client();

  ///def: Subscribes to SSE
  ///param:
  ///[url]->URl of the SSE api
  ///[header]->Map<String,String>, key value pair of the request header
  static Stream<SSEModel> subscribeToSSE({
    required String url,
    required Map<String, String> header,
  }) {
    final lineRegex = RegExp(r'^([^:]*)(?::)?(?: )?(.*)?$');
    var currentSSEModel = SSEModel(data: '', id: '', event: '');
    // ignore: close_sinks
    final streamController = StreamController<SSEModel>();
    log('--SUBSCRIBING TO SSE---');
    while (true) {
      try {
        _client = http.Client();
        final request = http.Request('GET', Uri.parse(url));

        ///Adding headers to the request
        header.forEach((key, value) {
          request.headers[key] = value;
        });

        final response = _client.send(request);

        ///Listening to the response as a stream
        response.asStream().listen(
          (data) {
            ///Applying transforms and listening to it
            data.stream
                .transform(const Utf8Decoder())
                .transform(const LineSplitter())
                .listen(
              (dataLine) {
                if (dataLine.isEmpty) {
                  ///This means that the complete event set has been read.
                  ///We then add the event to the stream
                  streamController.add(currentSSEModel);
                  currentSSEModel = SSEModel(data: '', id: '', event: '');
                  return;
                }

                ///Get the match of each line through the regex
                final Match match = lineRegex.firstMatch(dataLine)!;
                final field = match.group(1);
                if (field!.isEmpty) {
                  return;
                }
                var value = '';
                if (field == 'data') {
                  //If the field is data, we get the data through the substring
                  value = dataLine.substring(
                    5,
                  );
                } else {
                  value = match.group(2) ?? '';
                }
                switch (field) {
                  case 'event':
                    currentSSEModel.event = value;
                  case 'data':
                    currentSSEModel.data =
                        '${currentSSEModel.data ?? ''}$value\n';
                  case 'id':
                    currentSSEModel.id = value;
                  case 'retry':
                    break;
                }
              },
              onError: (e, s) {
                log('---ERROR---');
                log(e);
                streamController.addError(e, s);
              },
            );
          },
          onError: (e, s) {
            log('---ERROR---');
            log(e);
            streamController.addError(e, s);
          },
        );
      } catch (e, s) {
        log('---ERROR---');
        log(e.toString());
        streamController.addError(e, s);
      }

      Future.delayed(const Duration(seconds: 1), () {});
      return streamController.stream;
    }
  }

  static void unsubscribeFromSSE() {
    _client.close();
  }
}
