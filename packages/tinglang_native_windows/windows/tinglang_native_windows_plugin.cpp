#include "tinglang_native_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <memory>

namespace tinglang_native_windows {

// static
void TinglangNativeWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  registrar->AddPlugin(std::make_unique<TinglangNativeWindowsPlugin>());
}

TinglangNativeWindowsPlugin::TinglangNativeWindowsPlugin() {}

TinglangNativeWindowsPlugin::~TinglangNativeWindowsPlugin() {}

}  // namespace tinglang_native_windows
