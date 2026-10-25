/// Where an item in a synced folder (iCloud Drive) stands on this computer.
enum CloudItemState {
  /// An ordinary file, or the system knows nothing about it: read it.
  local,

  /// Downloaded and up to date.
  current,

  /// Downloaded, but a newer version exists in the cloud.
  outdated,

  /// Only in the cloud so far (a placeholder or an evicted file); reading it
  /// would wait for the download, so ask for it and come back later.
  notDownloaded,

  /// Not there at all.
  missing,
}

/// The parts of a cloud-synced folder that plain file access cannot see.
/// The folder itself is ordinary files; the operating system does the
/// syncing, so the app never talks to a server through this.
abstract interface class CloudDriveSupport {
  /// Download states of [paths] (absolute), in one call.
  Future<Map<String, CloudItemState>> itemStates(List<String> paths);

  /// Asks the system to download [paths] (the real names, not placeholder
  /// names). Returns at once; the download happens in the background.
  Future<void> download(List<String> paths);

  /// A stable identifier of this computer (not of the user), so a library
  /// copied to another computer can tell it is not the original; null when
  /// there is none. It never leaves the computer.
  Future<String?> machineId();
}
