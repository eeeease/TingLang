/// Installs [TinglangPlatform.instance] for the running OS.
library;

export 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';
export 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

export 'src/install.dart';
export 'src/shared/cloud_backends.dart' show CloudAsrSecrets, platformSecretStore;
export 'src/shared/model_downloader.dart';
export 'src/shared/model_store.dart';
