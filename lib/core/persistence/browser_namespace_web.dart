import 'dart:js_interop';

@JS('document.baseURI')
external JSString get _documentBaseUri;

String browserNamespace() {
  final value = Uri.parse(_documentBaseUri.toDart).resolve('.');
  return Uri(
    scheme: value.scheme,
    host: value.host,
    port: value.hasPort ? value.port : null,
    path: value.path,
  ).toString();
}
