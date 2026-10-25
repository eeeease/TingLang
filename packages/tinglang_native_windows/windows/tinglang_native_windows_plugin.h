#ifndef FLUTTER_PLUGIN_TINGLANG_NATIVE_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_TINGLANG_NATIVE_WINDOWS_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

namespace tinglang_native_windows {

// M1 skeleton. M8 adds a Pigeon C++ host API (probe, WASAPI process/endpoint
// loopback, microphone, Media Foundation decoding, layered DirectWrite
// caption window, RegisterHotKey). Until then the Dart side probes with
// dart:io and registers no native backends.
class TinglangNativeWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  TinglangNativeWindowsPlugin();
  virtual ~TinglangNativeWindowsPlugin();

  TinglangNativeWindowsPlugin(const TinglangNativeWindowsPlugin &) = delete;
  TinglangNativeWindowsPlugin &operator=(const TinglangNativeWindowsPlugin &) =
      delete;
};

}  // namespace tinglang_native_windows

#endif  // FLUTTER_PLUGIN_TINGLANG_NATIVE_WINDOWS_PLUGIN_H_
