// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '听浪';

  @override
  String get navLibrary => '素材库';

  @override
  String get navSettings => '设置';

  @override
  String get exitBlockedRecording => '请先停止并保存录音，再退出听浪。';

  @override
  String get exitBlockedSaveError => '仍有保存错误，请先处理本地存储问题。';

  @override
  String get lockPendingAttempt => '录音已停止，但记录尚未保存。请点击下方重试。';

  @override
  String get lockRecording => '录音进行中。请停止并保存后再切换页面。';

  @override
  String persistenceFailed(String error) {
    return '本地保存失败：$error';
  }

  @override
  String get retrySave => '重试保存';

  @override
  String get showDataLocation => '查看资料位置';

  @override
  String get cancel => '取消';

  @override
  String get startupFailedTitle => '听浪未能完成启动';

  @override
  String get startupFailedNotice => '资料库没有被重置。请保持资料目录原样；需要求助时，复制下面的错误详情。';

  @override
  String get copyErrorDetails => '复制错误详情';

  @override
  String get areaNba => 'NBA';

  @override
  String get areaGaming => '游戏';

  @override
  String get areaCinema => '电影';

  @override
  String get areaLife => '生活 Vlog';

  @override
  String get areaPodcasts => '播客';

  @override
  String get areaPersonal => '我的声音';

  @override
  String get discoverEmptyTitle => '精选播客与频道即将加入';

  @override
  String get discoverEmptyBody => '按主题整理的精选播客和频道，供你精听。';

  @override
  String get discoverImportInstead => '导入自己的素材';

  @override
  String get importMaterial => '导入素材';

  @override
  String get searchHint => '搜索课程或来源…';

  @override
  String get allScenes => '全部场景';

  @override
  String get libraryEmptyTitle => '从一段你真正感兴趣的内容开始。';

  @override
  String get libraryEmptyBody => '导入你感兴趣的视频或音频，或者先试试示例。';

  @override
  String get loadDemo => '加载示例课程';

  @override
  String get demoLoaded => '示例已加入「NBA」。';

  @override
  String courseScenes(int count) {
    return '$count 个场景';
  }

  @override
  String get mediaPending => '待关联媒体';

  @override
  String get mediaLocal => '本地媒体';

  @override
  String percentDone(int percent) {
    return '已完成 $percent%';
  }

  @override
  String get importTitle => '导入你的场景';

  @override
  String get importSubtitle => '本地视频或音频，有字幕可以一起导入。';

  @override
  String get importAreaLabel => '兴趣领域';

  @override
  String get pickMedia => '选择本地视频 / 音频';

  @override
  String get pickSubtitles => '选择 SRT / VTT 字幕（可选）';

  @override
  String get courseNameLabel => '课程名称';

  @override
  String get untitledScene => '未命名场景';

  @override
  String get importNeedMedia => '请选择媒体文件。';

  @override
  String get updateCourseTitle => '更新已有课程？';

  @override
  String get updateCourseBody => '课程 ID 已存在。内容会更新，原有练习记录、录音、收藏和已完成状态会保留。';

  @override
  String get updateContent => '更新内容';

  @override
  String get importing => '正在复制和校验…';

  @override
  String get importToLibrary => '导入到资料库';

  @override
  String get attachMediaPrompt => '课程内容已就绪，关联原始媒体即可播放。';

  @override
  String get attachMedia => '关联完整视频 / 音频';

  @override
  String get pause => '暂停';

  @override
  String get playClip => '播放片段';

  @override
  String get backToClipStart => '回到片段开头';

  @override
  String get abLoop => 'A–B 循环';

  @override
  String clipRange(String start, String end) {
    return '片段 $start — $end';
  }

  @override
  String get clipEnd => '结尾';

  @override
  String get mediaBoundsMismatch => '课程时间超出媒体时长。请关联同一来源的完整原媒体，勿使用已经截取的片段。';

  @override
  String get transcript => '原文';

  @override
  String get hideTranscript => '隐藏原文';

  @override
  String get showTranscript => '展开原文';

  @override
  String get noSubtitles => '尚无字幕。可在导入同一媒体时配上 SRT/VTT 文件。';

  @override
  String get listenFirst => '先听一遍，让字幕晚一点出现。';

  @override
  String get wordsTitle => '值得留下的词';

  @override
  String get phrasesTitle => '可以复用的表达';

  @override
  String get sentencesTitle => '用来说自己的句型';

  @override
  String get noItems => '这段没有预制的词汇或句型，仍然可以听原声、跟读和录音。';

  @override
  String get saveToReview => '保存到复习';

  @override
  String get savedToReview => '已加入复习。';

  @override
  String inThisScene(String text) {
    return '原片中\n$text';
  }

  @override
  String makeItYours(String text) {
    return '换成你的话\n$text';
  }

  @override
  String frameLabel(String frame) {
    return '句型：$frame';
  }

  @override
  String get blindTitle => '先听，再看';

  @override
  String get noBlanks => '没有预制挖空题。隐藏原文，先听完整片段，再说说你听到了什么。';

  @override
  String get checkAnswers => '检查我的答案';

  @override
  String get hideAnswers => '隐藏答案';

  @override
  String get showAnswers => '展开答案';

  @override
  String get shadowTitle => '借用原声的节奏';

  @override
  String get retellTitle => '现在，说成你自己的';

  @override
  String get shadowFallback => '播放原声，暂停后录下你的跟读。';

  @override
  String get focusOn => '重点';

  @override
  String get needHint => '需要一点提示？';

  @override
  String get stepWords => '单词';

  @override
  String get stepPhrases => '短语';

  @override
  String get stepSentences => '句子';

  @override
  String get stepBlind => '盲听';

  @override
  String get stepShadow => '跟读';

  @override
  String get stepRetell => '复述';

  @override
  String get stepDone => '这一步我已完成';

  @override
  String get backToLibrary => '回到资料库';

  @override
  String get changeMedia => '更换媒体';

  @override
  String get practiceHint => '写几个提示词，或记录你刚才想说的话…\n原话会保留，不会被自动改写。';

  @override
  String get draftSaved => '草稿已保存在本机';

  @override
  String get draftSaving => '正在保存草稿…';

  @override
  String stopAndSave(String time) {
    return '停止并保存 · $time';
  }

  @override
  String get recordYourself => '录下自己的表达';

  @override
  String get saveTextOnly => '只保存文字练习';

  @override
  String get recordingBadge => '● 录音中';

  @override
  String get practiceNotice => '戴上耳机对比原声。';

  @override
  String get practiceSaved => '练习已保存在本机。';

  @override
  String get practiceEmpty => '先写下你的表达，或录一段自己的声音。';

  @override
  String get recentPractice => '最近保存的练习';

  @override
  String get clipPractice => '这段内容的练习记录';

  @override
  String get playRecording => '回放自己的录音';

  @override
  String get showAllSaved => '查看全部收藏';

  @override
  String get reviewEmptyNone => '还没有要复习的表达';

  @override
  String get reviewEmptyDone => '这一轮复习完成了';

  @override
  String get recallPrompt => '回想你在这个片段中保存的表达。';

  @override
  String nextReview(String date) {
    return '下次复习：$date';
  }

  @override
  String get reveal => '展开原文';

  @override
  String get recallAgain => '没想起';

  @override
  String get recallHard => '有点难';

  @override
  String get recallGood => '记得';

  @override
  String get recallEasy => '轻松';

  @override
  String get backToScene => '回到原场景';

  @override
  String get clipMissing => '原片段不在当前课程版本中，收藏和练习仍然保留。';

  @override
  String get speakQuestion => 'What is one thing you are working on right now?';

  @override
  String get speakHelp => '可以聊训练、游戏、学习，或今天的一件小事。也可以完全换一个话题。';

  @override
  String appVersionLine(String version) {
    return '版本 $version';
  }

  @override
  String get uiLanguage => '界面语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get learningLanguage => '正在学习的语言';

  @override
  String get nativeLanguage => '你的母语（用于翻译）';

  @override
  String get appearance => '外观';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get exportMarkdown => '导出 Markdown 练习记录';

  @override
  String get exportDialogTitle => '导出练习文字';

  @override
  String get exported => '文字记录已导出。录音仍保存在本机资料目录。';

  @override
  String get copyDataFolder => '复制资料目录';

  @override
  String get dataFolderCopied => '资料目录路径已复制。';

  @override
  String get openInFinder => '在 Finder 中打开';

  @override
  String finderFailed(String error) {
    return '无法打开 Finder：$error';
  }

  @override
  String get openSourceBody => '以 AGPL-3.0 开源；如需商业授权，请联系作者。';

  @override
  String get viewLicenses => '查看完整开源许可';

  @override
  String get legalese => 'Copyright 2026 eeeease and Tinglang contributors.';

  @override
  String get exportHeading => '# 听浪 — 我的英语练习';

  @override
  String exportedAt(String date) {
    return '导出时间：$date';
  }

  @override
  String get exportTextOnly => '本导出只包含文字。原始录音和媒体保留在应用资料目录。';

  @override
  String get exportAudioOnly => '_仅录音练习。_';

  @override
  String get exportRecordingSaved => '录音：已保存在本机';

  @override
  String get exportRecordingNone => '录音：无';

  @override
  String get exportExpressions => '## 收藏的表达';

  @override
  String get liveSourceSystem => '系统声音';

  @override
  String get liveSourceMic => '麦克风';

  @override
  String get liveStop => '停止';

  @override
  String get liveStopping => '正在保存…';

  @override
  String liveLanguagePair(String source, String target) {
    return '$source → $target';
  }

  @override
  String liveUnavailable(String reason) {
    return '这台 Mac 暂时无法使用实时字幕：$reason';
  }

  @override
  String liveNeedSpeechModel(String language) {
    return '识别$language需要先下载语音模型。';
  }

  @override
  String liveNeedTranslationPack(String pair) {
    return '翻译 $pair 需要先下载语言包。';
  }

  @override
  String get liveDownload => '下载';

  @override
  String get liveIssueSilentTap => '系统声音采集到的是静音，已切换为屏幕录制方式采集。如果 macOS 询问，请在“系统设置 → 隐私与安全性”中允许听浪。';

  @override
  String get liveIssueFallback => '正在通过屏幕录制采集声音。';

  @override
  String get liveTranslating => '翻译中…';

  @override
  String liveSessionTitle(String date) {
    return '字幕 · $date';
  }

  @override
  String get liveSessionInterrupted => '已中断';

  @override
  String get liveSearchHint => '搜索全部字幕';

  @override
  String get liveNoMatches => '没有匹配的字幕。';

  @override
  String get liveExport => '导出…';

  @override
  String get liveDelete => '删除';

  @override
  String get liveDeleteConfirm => '删除这个会话及其全部字幕？';

  @override
  String get liveExportBilingual => '双语';

  @override
  String get liveExportSource => '仅原文';

  @override
  String get liveExportTranslation => '仅译文';

  @override
  String get liveTimesNote => '时间从开始字幕时算起。';

  @override
  String liveSaveFailed(String error) {
    return '字幕保存失败：$error';
  }

  @override
  String get sessionTranscript => '文本';

  @override
  String get sessionDictation => '听写';

  @override
  String get sessionNoMedia => '这个会话没有保存音频，无法播放。如需保留，请在设置中打开“同时保存系统声音”。';

  @override
  String get playerBack5 => '后退 5 秒';

  @override
  String get playerForward5 => '前进 5 秒';

  @override
  String get playerSpeed => '语速';

  @override
  String get playerVolume => '音量';

  @override
  String get playerMute => '静音';

  @override
  String get playerUnmute => '取消静音';

  @override
  String get playerSetA => '设为 A';

  @override
  String get playerSetB => '设为 B';

  @override
  String get playerClearLoop => '取消循环';

  @override
  String get playerLoopSentence => '循环这句';

  @override
  String get dictationPrompt => '听一听，把听到的内容打出来。';

  @override
  String get dictationPlay => '播放这句';

  @override
  String get dictationHint => '输入这句话…（⌘↩ 检查，⌘R 重播）';

  @override
  String get dictationCheck => '检查';

  @override
  String get dictationPrevious => '上一句';

  @override
  String get dictationNext => '下一句';

  @override
  String get dictationReveal => '显示答案';

  @override
  String get dictationCorrect => '完全正确';

  @override
  String get dictationClose => '基本正确';

  @override
  String get dictationIncorrect => '还不对';

  @override
  String dictationProgress(int done, int total) {
    return '已答对 $done/$total 句';
  }

  @override
  String get dictationEmpty => '这个会话还没有可以练习的句子。';

  @override
  String get importMedia => '导入音频或视频…';

  @override
  String importTranscribing(String percent) {
    return '正在转写 · $percent%';
  }

  @override
  String get importCopying => '正在复制…';

  @override
  String get importCancel => '取消';

  @override
  String recallInterval(String label, int days) {
    return '$label · $days 天';
  }

  @override
  String get stepQuiz => '测验';

  @override
  String youtubeBlocked(int code) {
    return '这个视频无法在听浪中播放（YouTube 错误 $code）。';
  }

  @override
  String get openOnYouTube => '在 YouTube 打开';

  @override
  String get blindInlineHint => '在原位填写缺少的词或短语，然后检查。颜色分别对应：单词、短语、句子。';

  @override
  String blindScore(int correct, int total) {
    return '答对 $correct/$total';
  }

  @override
  String get blindAddMissed => '把答错的加入复习';

  @override
  String get blindAllCorrect => '全部正确，已标记完成。';

  @override
  String shadowReason(String reason) {
    return '原因：$reason';
  }

  @override
  String get retellTryToUse => '试着用上';

  @override
  String get quizIntro => '根据中文意思回想表达，或者把它填回原句。答错的会加入复习。';

  @override
  String get quizRecall => '用英语说出来';

  @override
  String get quizCloze => '填回原句';

  @override
  String get quizCheck => '检查';

  @override
  String get quizNext => '下一题';

  @override
  String quizDone(int correct, int total) {
    return '测验完成：答对 $correct/$total。';
  }

  @override
  String get quizRestart => '再来一次';

  @override
  String get quizEmpty => '这一段没有可测验的内容。';

  @override
  String get addedToReview => '已加入复习';

  @override
  String get close => '关闭';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get save => '保存';

  @override
  String get makeCourse => '生成课程';

  @override
  String get makeCourseBasic => '基础课程';

  @override
  String get makeCourseBasicBody => '离线生成：按你的水平挑选生词、短语和句子，附盲听和跟读。';

  @override
  String get makeCourseAi => 'AI 课程';

  @override
  String get makeCourseAiBody => '用你的 AI 服务生成讲解、例句、记忆提示和复述提纲。';

  @override
  String get makeCourseNoProvider => '先在设置里添加 AI 服务。';

  @override
  String get makeCourseProvider => '服务';

  @override
  String makeCourseConsent(String host) {
    return '将本次转写文本发送到 $host';
  }

  @override
  String get makeCourseReplace => '这个会话已经生成过课程。重新生成会替换课程内容，学习进度和复习卡片保留。';

  @override
  String get makeCourseStart => '开始生成';

  @override
  String get makeCourseReading => '正在读取转写…';

  @override
  String get makeCourseSelecting => '正在挑选片段…';

  @override
  String makeCoursePlanning(int done, int total) {
    return '正在编写第 $done/$total 个片段…';
  }

  @override
  String get makeCourseCompiling => '正在校验并保存课程…';

  @override
  String makeCourseDone(int clips) {
    return '完成：$clips 个片段已就绪。';
  }

  @override
  String makeCourseFailed(String error) {
    return '课程生成失败：$error';
  }

  @override
  String makeCourseRequests(int count) {
    return 'AI 请求 $count 次';
  }

  @override
  String makeCourseFallbacks(int count) {
    return '$count 个片段使用了基础内容';
  }

  @override
  String get makeCourseOpen => '打开课程';

  @override
  String get providersTitle => 'AI 服务';

  @override
  String get providersBody => '生成 AI 课程时使用。可接入 OpenAI 兼容服务（自带密钥），或用 Ollama、LM Studio 在本机运行。';

  @override
  String get providersEmpty => '还没有添加服务。基础课程不需要服务。';

  @override
  String get providersPrivacy => '密钥保存在 macOS 钥匙串中。';

  @override
  String get providerAdd => '添加服务';

  @override
  String get providerEdit => '编辑服务';

  @override
  String get providerPreset => '服务商';

  @override
  String get providerCustom => '自定义（OpenAI 兼容）';

  @override
  String get providerName => '名称';

  @override
  String get providerBaseUrl => 'Base URL';

  @override
  String get providerModel => '模型';

  @override
  String get providerModelPick => '选择模型';

  @override
  String get providerApiKey => 'API 密钥';

  @override
  String get providerApiKeyOptional => 'API 密钥（可选）';

  @override
  String get providerKeyKeychain => '保存在钥匙串中';

  @override
  String get providerKeyKeep => '已保存密钥。留空则保持不变。';

  @override
  String get providerKeySaved => '已存密钥';

  @override
  String get providerKeyMissing => '无密钥';

  @override
  String get providerTest => '测试连接';

  @override
  String providerTestOk(int count) {
    return '已连接 · 可用模型 $count 个';
  }

  @override
  String get providerTestUnauthorized => '密钥被拒绝。';

  @override
  String get providerCloud => '云端';

  @override
  String get providerLocal => '本机';

  @override
  String get providerDefault => '用于生成课程';

  @override
  String providerDeleteTitle(String name) {
    return '删除 $name？';
  }

  @override
  String get providerDeleteBody => '其密钥会从钥匙串中移除。已生成的课程保留。';

  @override
  String get providerUrlInvalid => '请输入以 http:// 或 https:// 开头的 Base URL';

  @override
  String get providerModelRequired => '请输入模型名称。';

  @override
  String providerModelContext(String tokens) {
    return '上下文 $tokens';
  }

  @override
  String providerModelPrice(String input, String output) {
    return '每百万 token 输入 $input / 输出 $output';
  }

  @override
  String get providerModelLocal => '在本机运行，不按 token 计费。';

  @override
  String get providerModelUnlisted => '不在内置目录中，价格未知。';

  @override
  String get providerLitellmHint => '需要你自己启动 LiteLLM Proxy。';

  @override
  String makeCourseEstimate(int calls, String input, String output, String cost) {
    return '预估：$calls 次请求 · 输入约 $input / 输出约 $output token · $cost';
  }

  @override
  String makeCourseAbout(String usd) {
    return '约 $usd';
  }

  @override
  String get makeCourseLocalFree => '免费（本机运行）';

  @override
  String get makeCourseNoPrice => '无价格数据';

  @override
  String makeCourseTokens(String input, String output) {
    return '输入 $input / 输出 $output token';
  }

  @override
  String get errorFileDialog => '无法打开文件选择窗口。请退出并重新打开 App 后再试。';

  @override
  String get errorFileMissing => '找不到这个文件了。';

  @override
  String errorUnsupportedFormat(String ext) {
    return '不支持 .$ext 文件。可以试试 MP3、M4A、WAV、MP4 或 MOV。';
  }

  @override
  String get errorNoAudio => '这个文件没有可以转写的声音。';

  @override
  String get errorNoTranscriber => '这台 Mac 上还没有能转写文件的识别模型。请在 设置 → 语音识别 里选择。';

  @override
  String errorWithDetail(String detail) {
    return '出了点问题：$detail';
  }

  @override
  String get importAndTranscribe => '导入并转写';

  @override
  String get importCancelled => '已取消导入。';

  @override
  String get panelStart => '开始实时字幕';

  @override
  String get panelUnavailable => '这台 Mac 暂时无法开始实时字幕';

  @override
  String get panelHistory => '记录与复习';

  @override
  String get panelMore => '更多';

  @override
  String get panelAppearance => '外观…';

  @override
  String get panelOpenApp => '打开主窗口';

  @override
  String get panelSettings => '设置…';

  @override
  String get panelHide => '隐藏悬浮窗';

  @override
  String get panelQuit => '退出';

  @override
  String get panelListening => '正在听';

  @override
  String get panelWaiting => '等待声音…';

  @override
  String get panelView => '查看';

  @override
  String get panelMakeCourse => '生成课程';

  @override
  String get panelDropHint => '松开即可导入并转写';

  @override
  String panelNewRecordings(String count) {
    return '$count 条新录音';
  }

  @override
  String get panelDisplay => '显示方式';

  @override
  String get panelModeCard => '卡片';

  @override
  String get panelModeText => '仅文字';

  @override
  String get panelBackground => '背景';

  @override
  String get panelBgGlass => '毛玻璃';

  @override
  String get panelBgSolid => '纯色';

  @override
  String get panelBgClear => '透明';

  @override
  String get panelOpacity => '不透明度';

  @override
  String get panelBackgroundColor => '背景颜色';

  @override
  String get panelTextColor => '文字颜色';

  @override
  String get panelTranslationColor => '译文颜色';

  @override
  String get panelFontSize => '字号与字重';

  @override
  String get panelWeightRegular => '常规';

  @override
  String get panelWeightMedium => '中等';

  @override
  String get panelWeightBold => '粗体';

  @override
  String get panelLines => '显示行数';

  @override
  String get panelShowTranslation => '显示译文';

  @override
  String get panelOutline => '文字描边';

  @override
  String get panelCenter => '居中显示';

  @override
  String get panelLock => '锁定（鼠标穿透）';

  @override
  String get panelUnlock => '解锁';

  @override
  String get panelResetPosition => '重置位置';

  @override
  String get panelLayout => '排列';

  @override
  String get panelLayoutStacked => '上下';

  @override
  String get panelLayoutSideBySide => '左右对照';

  @override
  String get panelLocked => '已锁定 · 点击会穿透';

  @override
  String get panelLockToggle => '字幕时锁定（点击穿透）';

  @override
  String get panelJumpToLatest => '回到最新';

  @override
  String panelNewLines(String count) {
    return '$count 行新内容';
  }

  @override
  String get panelDockToggle => '开始或停止字幕';

  @override
  String get panelDockShow => '显示悬浮窗';

  @override
  String get panelDockUnlock => '解锁字幕';

  @override
  String get panelPreparing => '正在准备…';

  @override
  String get panelDownloading => '正在下载语音模型…';

  @override
  String get panelSaved => '已保存';

  @override
  String panelSummary(String duration, String words) {
    return '$duration · $words 词';
  }

  @override
  String panelFailed(String detail) {
    return '字幕没能开始：$detail';
  }

  @override
  String panelImporting(String count) {
    return '正在导入 $count 个文件，进度可在记录里查看。';
  }

  @override
  String get panelRetry => '重试';

  @override
  String get navRecords => '记录';

  @override
  String get tabCaptions => '字幕';

  @override
  String get tabReview => '复习';

  @override
  String get tabSpeak => '说说';

  @override
  String get tabMine => '我的';

  @override
  String get tabDiscover => '发现';

  @override
  String get tabShared => '共享';

  @override
  String get importAudio => '导入音频';

  @override
  String get recordsEmptyTitle => '还没有记录';

  @override
  String get recordsEmptyBody => '在悬浮窗开始实时字幕，或导入一段录音，转写后在这里精听。';

  @override
  String get dayToday => '今天';

  @override
  String get dayYesterday => '昨天';

  @override
  String get liveRunning => '正在实时字幕';

  @override
  String get originFile => '导入';

  @override
  String get originShared => '分享';

  @override
  String get sessionFailed => '转写失败';

  @override
  String get reviewEmptyHint => '学习课程时收藏有用的表达，到期后会回到这里。';

  @override
  String get reviewDoneHint => '下一批表达到期后会回到这里。';

  @override
  String get sharedEmptyTitle => '社区共享即将上线';

  @override
  String get sharedEmptyBody => '上线前，朋友导出的 .tinglang 文件可以在这里导入。';

  @override
  String get importShared => '导入分享文件…';

  @override
  String get exportShared => '导出分享文件…';

  @override
  String get sharedImported => '已导入。';

  @override
  String get sharedExported => '分享文件已保存。';

  @override
  String get shareNotPackage => '这不是听浪的分享文件。';

  @override
  String get shareNewerVersion => '这个文件来自更新版本的听浪，请更新后再试。';

  @override
  String get shareIncomplete => '分享文件不完整，请让对方重新导出。';

  @override
  String get shareTooLarge => '分享文件太大，无法导入。';

  @override
  String get shareUnsupportedMedia => '文件里的音视频格式不受支持。';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsCaptions => '实时字幕';

  @override
  String get settingsShowPanel => '显示悬浮窗';

  @override
  String get settingsPanelLayout => '悬浮窗排列';

  @override
  String get settingsPanelScrollback => '悬浮窗可回看的行数';

  @override
  String settingsScrollbackLines(String count) {
    return '$count 行';
  }

  @override
  String get settingsKeepSystemAudio => '同时保存系统声音';

  @override
  String get settingsKeepSystemAudioHelp => '之后可以回放原声。仅用于你有权录制的内容。';

  @override
  String get settingsData => '数据';

  @override
  String get settingsBackupHint => '所有数据都在这个文件夹里，备份它即可保留全部记录。';

  @override
  String get settingsAbout => '关于';

  @override
  String get voiceMemos => '语音备忘录';

  @override
  String voiceMemosImport(String count) {
    return '导入并转写（$count）';
  }

  @override
  String get voiceMemoImported => '已导入';

  @override
  String voiceMemoUntitled(String date) {
    return '语音备忘录 · $date';
  }

  @override
  String get voiceMemosAccessTitle => '允许听浪读取语音备忘录';

  @override
  String get voiceMemosAccessBody =>
      'macOS 把语音备忘录放在受保护的文件夹里。请在「系统设置 › 隐私与安全性 › 完全磁盘访问权限」中打开听浪；macOS 可能会要求退出并重新打开。';

  @override
  String get voiceMemosOpenSettings => '打开系统设置';

  @override
  String get voiceMemosCheckAgain => '重新检查';

  @override
  String get voiceMemosNoLibrary =>
      '这台 Mac 上还没有语音备忘录。在 iPhone 和这台 Mac 的 iCloud 设置里打开「语音备忘录」，录音就会出现在这里。';

  @override
  String get voiceMemosUnreadable => '无法读取语音备忘录资料库。先打开一次「语音备忘录」App，再重新检查。';

  @override
  String get voiceMemosEmpty => '这台 Mac 上还没有录音。';

  @override
  String voiceMemosNewToday(String count) {
    return '今天有 $count 条新的语音备忘录';
  }

  @override
  String get voiceMemosImportShort => '导入';

  @override
  String get originVoiceMemo => '语音备忘录';

  @override
  String get settingsAccount => '账号';

  @override
  String get accountSignedOutBody => '登录后可以查看你的套餐和用量；购买和管理在官网完成。不登录也能使用全部本机功能。';

  @override
  String accountSignInHost(String host) {
    return '登录会在浏览器中打开 $host。登录之前不会发送任何内容。';
  }

  @override
  String get accountSignIn => '在浏览器登录';

  @override
  String get accountSigningIn => '正在等待浏览器…';

  @override
  String get accountSignOut => '退出登录';

  @override
  String get navSignIn => '登录';

  @override
  String get planFree => '免费版';

  @override
  String get accountUpgrade => '升级到 Pro';

  @override
  String get cloudOfficialSoon => 'TingLang 官方（敬请期待）';

  @override
  String get accountRefresh => '刷新';

  @override
  String get accountManage => '在网站管理';

  @override
  String get accountPlans => '查看套餐';

  @override
  String accountPlan(String plan) {
    return '套餐：$plan';
  }

  @override
  String get accountStatusActive => '有效';

  @override
  String get accountStatusTrialing => '试用中';

  @override
  String get accountStatusPastDue => '待付款';

  @override
  String get accountStatusCanceled => '已取消';

  @override
  String get accountStatusExpired => '已过期';

  @override
  String get accountStatusNone => '未订阅';

  @override
  String get accountStatusUnknown => '状态未知';

  @override
  String get accountServices => '云端服务';

  @override
  String get accountNoServices => 'TingLang 官方云端服务（转写、AI 课程）敬请期待。';

  @override
  String get cloudServiceTranscribe => '云端转写';

  @override
  String get cloudServiceTranslate => '云端翻译';

  @override
  String get cloudServiceLlm => '无需自备 Key 的 AI 课程';

  @override
  String get cloudServiceIncluded => '已包含';

  @override
  String get cloudServiceNotInPlan => '当前方案不含';

  @override
  String quotaMinutes(String used, String limit) {
    return '已用 $used / $limit 分钟';
  }

  @override
  String quotaCredits(String used, String limit) {
    return '已用 $used / $limit 点';
  }

  @override
  String quotaOther(String used, String limit) {
    return '已用 $used / $limit';
  }

  @override
  String quotaResets(String date) {
    return '$date 重置';
  }

  @override
  String accountOffline(String host, String time) {
    return '暂时连不上 $host，显示的是 $time 的方案信息。';
  }

  @override
  String accountOfflineUnconfirmed(String host) {
    return '暂时连不上 $host，目前无法确认方案状态。本机功能不受影响。';
  }

  @override
  String cloudErrorUnreachable(String host) {
    return '连不上 $host，请检查地址和网络；本机功能不受影响。';
  }

  @override
  String get cloudErrorNoAccounts => '这台服务器不提供账号。';

  @override
  String get cloudErrorNoBrowser => '这个系统暂不支持在浏览器中登录。';

  @override
  String get cloudErrorNoKeychain => '这个系统没有可用的安全存储来保存登录信息。';

  @override
  String get cloudErrorCanceled => '已取消登录。';

  @override
  String get cloudErrorSignIn => '登录没有完成，请重试。';

  @override
  String get cloudErrorSessionEnded => '登录已失效，请重新登录。';

  @override
  String get cloudErrorClientTooOld => '这台服务器需要更新版本的听浪。';

  @override
  String get cloudErrorEntitlement => '需要包含此功能的方案。';

  @override
  String get cloudErrorQuota => '本期额度已用完。';

  @override
  String get cloudErrorRateLimited => '请求太频繁，请稍后再试。';

  @override
  String get cloudErrorFeatureDisabled => '这台服务器不提供该功能。';

  @override
  String get cloudErrorMaintenance => '服务器正在维护，请稍后再试。';

  @override
  String cloudErrorServer(String code) {
    return '服务器无法处理这次请求（$code）。';
  }

  @override
  String get cloudErrorBadResponse => '服务器返回了听浪无法识别的内容。';

  @override
  String get settingsSpeechModels => '语音识别';

  @override
  String get speechForLive => '实时字幕';

  @override
  String get speechForFiles => '文件转写';

  @override
  String get speechAuto => '自动';

  @override
  String get speechModelAppleSpeech => 'Apple 语音识别';

  @override
  String get speechModelAppleDictation => 'Apple 听写';

  @override
  String get speechModelXasr => 'X-ASR 中英';

  @override
  String get speechModelSmallEn => 'Zipformer 英文 20M';

  @override
  String get speechModelMediumEn => 'Zipformer 英文 66M';

  @override
  String get speechModelXasrOffline => 'X-ASR 中英（文件）';

  @override
  String get speechModelParakeet => 'Parakeet TDT 0.6B v2';

  @override
  String get speechAccuracy => '准确度';

  @override
  String get speechSpeed => '速度';

  @override
  String get speechSystemAsset => 'macOS 自带';

  @override
  String get speechInstalled => '已下载';

  @override
  String speechNeedsMacos(String version) {
    return '需要 macOS $version';
  }

  @override
  String get speechInUse => '使用中';

  @override
  String get speechUseThis => '使用';

  @override
  String speechDownload(String size) {
    return '下载 $size';
  }

  @override
  String get speechDelete => '删除';

  @override
  String get speechCancel => '取消';

  @override
  String speechDownloading(String percent) {
    return '正在下载… $percent%';
  }

  @override
  String speechDownloadTitle(String name) {
    return '下载「$name」？';
  }

  @override
  String speechDownloadBody(String size, String host, String license) {
    return '将从 $host 下载 $size，保存在听浪的数据文件夹里，可随时删除。许可证：$license。';
  }

  @override
  String speechDeleteTitle(String name) {
    return '删除「$name」？';
  }

  @override
  String speechDeleteBody(String size) {
    return '释放 $size。之后可以再次下载。';
  }

  @override
  String get speechAccent => '英语口音';

  @override
  String get speechAccentDownload => '从 Apple 下载';

  @override
  String get speechAccentRemove => '移除';

  @override
  String get speechFarField => '远场声音（扬声器、隔着房间）';

  @override
  String get speechShortForm => '短句';

  @override
  String get speechLatency => '识别延迟';

  @override
  String get latencyPowerSaver => '省电';

  @override
  String get latencyBalanced => '平衡';

  @override
  String get latencyFastest => '最低延迟';

  @override
  String get latencyPowerSaverHelp => '最省电，字幕更新稍慢。';

  @override
  String get latencyBalancedHelp => '推荐。';

  @override
  String get latencyFastestHelp => '出字最快，稍多占用 CPU。';

  @override
  String panelModelNeeded(String name, String size) {
    return '开始字幕前需要先下载一次「$name」（$size）。';
  }

  @override
  String panelDownloadingModel(String name, String percent) {
    return '正在下载「$name」… $percent%';
  }

  @override
  String panelLanguageUnsupported(String name, String language) {
    return '「$name」不能识别$language。请在设置里换一个模型。';
  }

  @override
  String get panelOpenSettings => '设置';

  @override
  String errorModelMissing(String name) {
    return '请先在 设置 → 语音识别 里下载「$name」。';
  }

  @override
  String errorSpeechAssetMissing(String locale) {
    return 'macOS 需要先下载 $locale 的语音模型（设置 → 语音识别）。';
  }

  @override
  String get speechChecksumFailed => '下载的文件与校验值不符，已删除。发布方可能更新了文件，请稍后再试。';

  @override
  String get settingsSyncData => '同步与数据';

  @override
  String get speechMode => '识别方式';

  @override
  String get speechModeLocal => '本地模型';

  @override
  String get speechModeCloud => '云端 API';

  @override
  String get speechChooseTitle => '选择识别方式';

  @override
  String get speechChooseLocal => '使用本地模型';

  @override
  String get speechChooseLocalBody => '在这台 Mac 上识别，音频不上传。';

  @override
  String get speechChooseCloud => '使用云端 API';

  @override
  String get speechChooseCloudBody => '适合跑不动本地模型的 Mac。用你自己的密钥，音频会上传。';

  @override
  String speechCpuLevel(String level) {
    return 'CPU 占用$level';
  }

  @override
  String get speechCpuLow => '低';

  @override
  String get speechCpuMedium => '中';

  @override
  String get speechCpuHigh => '高';

  @override
  String get cloudSpeechService => '服务商';

  @override
  String cloudSpeechSendsTo(String host) {
    return '音频会发送到 $host。';
  }

  @override
  String get cloudSpeechGetKey => '获取密钥';

  @override
  String get cloudSpeechSaved => '已保存。';

  @override
  String get cloudSpeechTestOk => '连接成功。';

  @override
  String get cloudSpeechForget => '删除密钥';

  @override
  String cloudSpeechForgetTitle(String service) {
    return '删除$service的密钥？';
  }

  @override
  String cloudSpeechNoLive(String service) {
    return '$service不提供实时识别，实时字幕仍用本地模型。';
  }

  @override
  String cloudSpeechNoFile(String service) {
    return '$service不提供文件转写，文件仍用本地模型转写。';
  }

  @override
  String cloudSpeechFieldRequired(String field) {
    return '请填写 $field。';
  }

  @override
  String get cloudFieldApiKey => 'API Key';

  @override
  String get cloudFieldApiSecret => 'API Secret';

  @override
  String get cloudFieldAppId => 'AppID';

  @override
  String get cloudFieldSecretId => 'SecretId';

  @override
  String get cloudFieldSecretKey => 'SecretKey';

  @override
  String get cloudFieldRegion => '区域';

  @override
  String get cloudRegionExample => '例如 eastus';

  @override
  String get cloudRegionCn => '中国内地（北京）';

  @override
  String get cloudRegionIntl => '国际（新加坡）';

  @override
  String get cloudRegionUs => '美国';

  @override
  String get cloudRegionEu => '欧盟';

  @override
  String get cloudTencent => '腾讯云';

  @override
  String get cloudDashscope => '阿里云百炼';

  @override
  String get cloudXfyun => '讯飞开放平台';

  @override
  String get cloudSoniox => 'Soniox';

  @override
  String get cloudAssemblyai => 'AssemblyAI';

  @override
  String get cloudAzure => 'Azure 语音';

  @override
  String get panelChooseRecognizer => '开始前先选择识别方式：本地模型或云端 API。';

  @override
  String panelCloudNotSetUp(String service) {
    return '请先在设置里填写$service的密钥。';
  }

  @override
  String get panelCloudNotChosen => '请先在设置里选择云端服务商。';

  @override
  String panelCloudLanguage(String service, String language) {
    return '$service不支持识别$language。';
  }

  @override
  String panelCloudLabel(String service) {
    return '云端识别 · $service';
  }

  @override
  String asrFailedUnauthorized(String service) {
    return '$service拒绝了密钥，请在设置里检查。';
  }

  @override
  String asrFailedQuota(String service) {
    return '$service的额度已用完，或服务未开通。';
  }

  @override
  String asrFailedRateLimited(String service) {
    return '$service请求太频繁，请稍后再试。';
  }

  @override
  String asrFailedNetwork(String service) {
    return '连不上$service，请检查网络。';
  }

  @override
  String asrFailedLanguage(String service) {
    return '$service不支持这种语言。';
  }

  @override
  String asrFailedTooLong(String service) {
    return '文件太长，$service无法处理。';
  }

  @override
  String asrFailedOther(String service, String message) {
    return '$service：$message';
  }

  @override
  String get errorCloudNotSetUp => '已选择云端识别，但还没有保存密钥。请在 设置 → 语音识别 里填写。';

  @override
  String get accentUS => '美国';

  @override
  String get accentGB => '英国';

  @override
  String get accentAU => '澳大利亚';

  @override
  String get accentIN => '印度';

  @override
  String get accentCA => '加拿大';

  @override
  String get accentIE => '爱尔兰';

  @override
  String get accentNZ => '新西兰';

  @override
  String get accentSG => '新加坡';

  @override
  String get accentZA => '南非';

  @override
  String get syncTitle => 'iCloud 云盘同步';

  @override
  String get syncBadge => 'iCloud';

  @override
  String get syncBody =>
      '让登录同一 Apple 账户的每台 Mac 拥有相同的课程、录音和学习进度。macOS 会同步你 iCloud 云盘里的 Tinglang 文件夹；听浪没有自己的服务器。';

  @override
  String get syncSwitch => '通过 iCloud 云盘同步';

  @override
  String get syncOff => '已关闭，不会向 iCloud 云盘复制任何内容。';

  @override
  String get syncUnavailable =>
      '这台 Mac 没有开启或设置 iCloud 云盘。请在“系统设置 → Apple 账户 → iCloud → iCloud 云盘”中开启，然后回到这里。';

  @override
  String get syncNoAccess => '听浪没有打开 iCloud 云盘的权限。请在“系统设置 → 隐私与安全性 → 文件与文件夹”中允许，然后重试。';

  @override
  String syncFailed(String error) {
    return '无法使用 iCloud 云盘中的 Tinglang 文件夹。$error';
  }

  @override
  String get syncSyncing => '正在同步…';

  @override
  String get syncUpToDate => '已是最新';

  @override
  String get syncNever => '尚未同步';

  @override
  String syncLast(String time) {
    return '上次同步：$time';
  }

  @override
  String syncWaiting(String count) {
    return '正在等待 iCloud 下载 $count 项内容，下载完成后会自动加入。';
  }

  @override
  String syncCounts(String courses, String recordings, String records) {
    return '$courses 门课程 · $recordings 条录音 · $records 条学习记录';
  }

  @override
  String syncOtherMacs(String count) {
    return '与另外 $count 台 Mac 同步';
  }

  @override
  String get syncFolderLabel => 'iCloud 云盘 › Tinglang';

  @override
  String get syncShowInFinder => '在访达中显示';

  @override
  String get syncNow => '立即同步';

  @override
  String get syncProblemNewerFolder => 'iCloud 云盘中的 Tinglang 文件夹由更新版本的听浪创建。请在这台 Mac 上更新听浪后继续同步。';

  @override
  String syncProblemNewerState(String name) {
    return '$name 使用的是更新版本的听浪。在这台 Mac 更新听浪之前，会跳过它的更改。';
  }

  @override
  String get syncProblemUnreadableState => '无法读取另一台 Mac 的更改，已跳过。';

  @override
  String syncProblemNewerPackage(String name) {
    return '已跳过$name：它由更新版本的听浪生成。';
  }

  @override
  String syncProblemUnreadablePackage(String name) {
    return '已跳过$name：无法读取它在 iCloud 云盘中的文件。';
  }

  @override
  String get syncProblemWriteFailed => '部分更改未能保存到 iCloud 云盘。请检查磁盘是否还有空间。';

  @override
  String get syncUnnamedItem => '一项内容';

  @override
  String syncMoreProblems(String count) {
    return '另有 $count 项。';
  }

  @override
  String get syncFootnote => '设置和 API 密钥只保存在各自的 Mac 上。关闭同步不会删除 iCloud 云盘里已有的内容。';

  @override
  String updateAvailable(String version) {
    return '听浪 $version 已发布。';
  }

  @override
  String get updateWhatsNew => '新版本说明';

  @override
  String get updateInstall => '更新并重新打开';

  @override
  String get updateLater => '以后再说';

  @override
  String updateDownloading(String version, String percent) {
    return '正在下载听浪 $version… $percent%';
  }

  @override
  String get updateCancel => '取消';

  @override
  String get updateInstalling => '正在校验下载的文件并准备安装…';

  @override
  String get updateRestarting => '听浪正在退出以完成更新，随后会自动重新打开。';

  @override
  String get updateTryAgain => '重试';

  @override
  String get updateOpenReleasePage => '打开发布页面';

  @override
  String get updateErrorNetwork => '下载中断了。请检查网络连接后重试。';

  @override
  String get updateErrorChecksum => '下载的文件与公布的校验值不符，已删除。请稍后再试。';

  @override
  String updateErrorPackage(String version) {
    return '下载的文件不是听浪 $version，没有安装任何内容。请改从发布页面下载。';
  }

  @override
  String get updateErrorDisk => '无法在这台 Mac 上保存更新。请检查磁盘是否还有空间。';

  @override
  String get updateErrorBusy => '请先完成或保存录音，再更新。';

  @override
  String get updateErrorQuitRefused => '听浪没能退出，更新没有安装。请重试。';

  @override
  String get updateErrorInstall => '无法把新版本放到位。请从发布页面下载，自己替换听浪。';

  @override
  String get updateErrorNotBundle => '听浪找不到要替换的 App。请从发布页面下载新版本。';

  @override
  String get updateErrorTranslocated => 'macOS 正在从一个临时副本运行听浪。请把听浪移到「应用程序」文件夹，从那里打开后重试，或从发布页面下载新版本。';

  @override
  String get updateErrorReadOnly => '听浪正在从一个不能修改的磁盘（例如磁盘映像）运行。请先把它移到「应用程序」文件夹，或从发布页面下载新版本。';

  @override
  String updateErrorNotWritable(String folder) {
    return '你的账户不能修改听浪所在的文件夹（$folder）。请从发布页面下载新版本，自己替换听浪。';
  }

  @override
  String get updateSettingsTitle => '更新';

  @override
  String get updateAutoCheck => '自动检查更新';

  @override
  String get updateAutoCheckHelp =>
      '听浪每天向 GitHub（api.github.com）询问一次是否有新版本，只发送 App 的版本号，不涉及你本人或你的录音。关闭后，只有你点「立即检查」时才会检查。';

  @override
  String updateCurrentVersion(String version) {
    return '当前版本：听浪 $version。';
  }

  @override
  String get updateCheckNow => '立即检查';

  @override
  String get updateChecking => '正在检查…';

  @override
  String get updateUpToDate => '已是最新版本。';

  @override
  String get updateNoneFound => '没有找到更新。';

  @override
  String get updateNeverChecked => '还没有检查过。';

  @override
  String updateLastChecked(String time) {
    return '上次检查：$time。';
  }

  @override
  String get panelHintRecord => '开始实时字幕（⌘⇧T）';

  @override
  String get panelHintStop => '停止实时字幕（⌘⇧T）';

  @override
  String get panelHintMenu => '听浪菜单：打开主窗口、外观、设置';
}
