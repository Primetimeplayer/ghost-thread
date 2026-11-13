// Picks the browser install prompt implementation at compile time.
export 'install_prompt_stub.dart'
    if (dart.library.js_interop) 'install_prompt_web.dart';
