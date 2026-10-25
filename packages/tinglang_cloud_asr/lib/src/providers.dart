import 'provider.dart';
import 'providers/assemblyai.dart';
import 'providers/azure.dart';
import 'providers/dashscope.dart';
import 'providers/soniox.dart';
import 'providers/tencent.dart';
import 'providers/xfyun.dart';

/// Every cloud speech service Tinglang can use, in display order. Each is
/// registered as the `cloud.<id>` live and/or file backend.
abstract final class CloudAsrProviders {
  static final List<CloudAsrProvider> all = [
    // Mainland China services.
    TencentCloudAsr(),
    DashScopeAsr(),
    XfyunAsr(),
    // International services.
    SonioxProvider(),
    AssemblyAiProvider(),
    AzureSpeechProvider(),
  ];

  static CloudAsrProvider? byId(String id) {
    for (final p in all) {
      if (p.info.id == id) return p;
    }
    return null;
  }
}
