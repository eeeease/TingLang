#include "include/tinglang_native_windows/tinglang_native_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "tinglang_native_windows_plugin.h"

void TinglangNativeWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  tinglang_native_windows::TinglangNativeWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
