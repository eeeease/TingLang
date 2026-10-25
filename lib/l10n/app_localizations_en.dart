// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TingLang';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSettings => 'Settings';

  @override
  String get exitBlockedRecording => 'Stop and save the recording before quitting TingLang.';

  @override
  String get exitBlockedSaveError =>
      'Something still failed to save. Fix the local storage problem first.';

  @override
  String get lockPendingAttempt =>
      'The recording stopped but its record is not saved yet. Use Retry save below.';

  @override
  String get lockRecording => 'Recording in progress. Stop and save before switching pages.';

  @override
  String persistenceFailed(String error) {
    return 'Could not save locally: $error';
  }

  @override
  String get retrySave => 'Retry save';

  @override
  String get showDataLocation => 'Show data location';

  @override
  String get cancel => 'Cancel';

  @override
  String get startupFailedTitle => 'TingLang could not start';

  @override
  String get startupFailedNotice =>
      'Your library was not reset. Leave the data folder as it is, and copy the error details if you ask for help.';

  @override
  String get copyErrorDetails => 'Copy error details';

  @override
  String get areaNba => 'NBA';

  @override
  String get areaGaming => 'Gaming';

  @override
  String get areaCinema => 'Cinema';

  @override
  String get areaLife => 'Life & Vlogs';

  @override
  String get areaPodcasts => 'Podcasts';

  @override
  String get areaPersonal => 'My voice';

  @override
  String get discoverEmptyTitle => 'Curated podcasts and channels are on the way';

  @override
  String get discoverEmptyBody =>
      'Themed shelves of hand-picked podcasts and channels to listen to closely.';

  @override
  String get discoverImportInstead => 'Import your own material';

  @override
  String get importMaterial => 'Import';

  @override
  String get searchHint => 'Search courses or sources…';

  @override
  String get allScenes => 'All scenes';

  @override
  String get libraryEmptyTitle => 'Start with something you genuinely care about.';

  @override
  String get libraryEmptyBody => 'Import a video or audio you care about, or try the sample first.';

  @override
  String get loadDemo => 'Load the sample course';

  @override
  String get demoLoaded => 'The sample was added to NBA.';

  @override
  String courseScenes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scenes',
      one: '1 scene',
    );
    return '$_temp0';
  }

  @override
  String get mediaPending => 'Media not attached';

  @override
  String get mediaLocal => 'Local media';

  @override
  String percentDone(int percent) {
    return '$percent% done';
  }

  @override
  String get importTitle => 'Bring your own scene';

  @override
  String get importSubtitle => 'Local video or audio, with subtitles if you have them.';

  @override
  String get importAreaLabel => 'Area';

  @override
  String get pickMedia => 'Choose local video / audio';

  @override
  String get pickSubtitles => 'Choose SRT / VTT subtitles (optional)';

  @override
  String get courseNameLabel => 'Course name';

  @override
  String get untitledScene => 'Untitled scene';

  @override
  String get importNeedMedia => 'Choose a media file.';

  @override
  String get updateCourseTitle => 'Update existing course?';

  @override
  String get updateCourseBody =>
      'A course with this ID already exists. Its content will be updated; your practice records, recordings, saved expressions and completion marks are kept.';

  @override
  String get updateContent => 'Update content';

  @override
  String get importing => 'Copying and checking…';

  @override
  String get importToLibrary => 'Add to library';

  @override
  String get attachMediaPrompt => 'The course is ready. Attach the original media to play it.';

  @override
  String get attachMedia => 'Attach full video / audio';

  @override
  String get pause => 'Pause';

  @override
  String get playClip => 'Play clip';

  @override
  String get backToClipStart => 'Back to clip start';

  @override
  String get abLoop => 'A–B loop';

  @override
  String clipRange(String start, String end) {
    return 'CLIP $start — $end';
  }

  @override
  String get clipEnd => 'end';

  @override
  String get mediaBoundsMismatch =>
      'Course times go beyond the media length. Attach the complete original media from the same source, not an already-cut clip.';

  @override
  String get transcript => 'Transcript';

  @override
  String get hideTranscript => 'Hide transcript';

  @override
  String get showTranscript => 'Show transcript';

  @override
  String get noSubtitles =>
      'No subtitles yet. Pair this media with an SRT/VTT file when importing it.';

  @override
  String get listenFirst => 'Listen once first; let the words appear a little later.';

  @override
  String get wordsTitle => 'Words worth keeping';

  @override
  String get phrasesTitle => 'Expressions you can reuse';

  @override
  String get sentencesTitle => 'A frame for your own words';

  @override
  String get noItems =>
      'No prepared words or patterns for this clip. You can still listen, shadow and record.';

  @override
  String get saveToReview => 'Save to review';

  @override
  String get savedToReview => 'Added to review.';

  @override
  String inThisScene(String text) {
    return 'IN THIS SCENE\n$text';
  }

  @override
  String makeItYours(String text) {
    return 'MAKE IT YOURS\n$text';
  }

  @override
  String frameLabel(String frame) {
    return 'Frame: $frame';
  }

  @override
  String get blindTitle => 'Listen before you look';

  @override
  String get noBlanks =>
      'No prepared blanks. Hide the transcript, listen to the whole clip, then say what you heard.';

  @override
  String get checkAnswers => 'Check my answers';

  @override
  String get hideAnswers => 'Hide answers';

  @override
  String get showAnswers => 'Show answers';

  @override
  String get shadowTitle => 'Borrow the rhythm';

  @override
  String get retellTitle => 'Now, make it yours';

  @override
  String get shadowFallback => 'Play the original, pause, then record your shadowing.';

  @override
  String get focusOn => 'Focus on';

  @override
  String get needHint => 'Need a hint?';

  @override
  String get stepWords => 'Words';

  @override
  String get stepPhrases => 'Phrases';

  @override
  String get stepSentences => 'Sentences';

  @override
  String get stepBlind => 'Blind';

  @override
  String get stepShadow => 'Shadow';

  @override
  String get stepRetell => 'Retell';

  @override
  String get stepDone => 'I\'ve finished this step';

  @override
  String get backToLibrary => 'Back to library';

  @override
  String get changeMedia => 'Change media';

  @override
  String get practiceHint =>
      'Jot down a few cue words, or what you just wanted to say…\nYour words are kept exactly as written.';

  @override
  String get draftSaved => 'Draft saved on this computer';

  @override
  String get draftSaving => 'Saving draft…';

  @override
  String stopAndSave(String time) {
    return 'Stop and save · $time';
  }

  @override
  String get recordYourself => 'Record yourself';

  @override
  String get saveTextOnly => 'Save text only';

  @override
  String get recordingBadge => '● Recording';

  @override
  String get practiceNotice => 'Use headphones to compare with the original.';

  @override
  String get practiceSaved => 'Practice saved on this computer.';

  @override
  String get practiceEmpty => 'Write your expression first, or record your own voice.';

  @override
  String get recentPractice => 'Recently saved practice';

  @override
  String get clipPractice => 'Practice for this clip';

  @override
  String get playRecording => 'Play your recording';

  @override
  String get showAllSaved => 'Show all saved';

  @override
  String get reviewEmptyNone => 'Nothing to review yet';

  @override
  String get reviewEmptyDone => 'All caught up';

  @override
  String get recallPrompt => 'Recall the expression you saved from this clip.';

  @override
  String nextReview(String date) {
    return 'Next review: $date';
  }

  @override
  String get reveal => 'Reveal';

  @override
  String get recallAgain => 'Forgot';

  @override
  String get recallHard => 'Hard';

  @override
  String get recallGood => 'Good';

  @override
  String get recallEasy => 'Easy';

  @override
  String get backToScene => 'Back to the scene';

  @override
  String get clipMissing =>
      'The original clip is not in the current course version. Your saved expression and practice are kept.';

  @override
  String get speakQuestion => 'What is one thing you are working on right now?';

  @override
  String get speakHelp =>
      'Talk about training, games, study or something small from today — or switch topics entirely.';

  @override
  String appVersionLine(String version) {
    return 'Version $version';
  }

  @override
  String get uiLanguage => 'Interface language';

  @override
  String get followSystem => 'Follow system';

  @override
  String get learningLanguage => 'Language you are learning';

  @override
  String get nativeLanguage => 'Your language (for translations)';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get exportMarkdown => 'Export practice as Markdown';

  @override
  String get exportDialogTitle => 'Export practice text';

  @override
  String get exported => 'Text exported. Recordings stay in the local data folder.';

  @override
  String get copyDataFolder => 'Copy data folder path';

  @override
  String get dataFolderCopied => 'Data folder path copied.';

  @override
  String get openInFinder => 'Open in Finder';

  @override
  String finderFailed(String error) {
    return 'Cannot open Finder: $error';
  }

  @override
  String get openSourceBody =>
      'Open source under AGPL-3.0. Commercial licences are available from the author.';

  @override
  String get viewLicenses => 'View full open-source licences';

  @override
  String get legalese => 'Copyright 2026 eeeease and Tinglang contributors.';

  @override
  String get exportHeading => '# TingLang — My English practice';

  @override
  String exportedAt(String date) {
    return 'Exported: $date';
  }

  @override
  String get exportTextOnly =>
      'This export contains text only. Original recordings and media stay in the app data folder.';

  @override
  String get exportAudioOnly => '_Audio-only practice._';

  @override
  String get exportRecordingSaved => 'Recording: saved locally';

  @override
  String get exportRecordingNone => 'Recording: none';

  @override
  String get exportExpressions => '## Expressions';

  @override
  String get liveSourceSystem => 'System audio';

  @override
  String get liveSourceMic => 'Microphone';

  @override
  String get liveStop => 'Stop';

  @override
  String get liveStopping => 'Saving…';

  @override
  String liveLanguagePair(String source, String target) {
    return '$source → $target';
  }

  @override
  String liveUnavailable(String reason) {
    return 'Live captions are not available on this Mac yet: $reason';
  }

  @override
  String liveNeedSpeechModel(String language) {
    return 'Recognising $language needs a speech model download first.';
  }

  @override
  String liveNeedTranslationPack(String pair) {
    return 'Translating $pair needs a language pack download first.';
  }

  @override
  String get liveDownload => 'Download';

  @override
  String get liveIssueSilentTap =>
      'System audio arrived silent, so TingLang switched to Screen Recording capture. If macOS asks, allow TingLang in System Settings → Privacy & Security.';

  @override
  String get liveIssueFallback => 'Capturing through Screen Recording.';

  @override
  String get liveTranslating => 'Translating…';

  @override
  String liveSessionTitle(String date) {
    return 'Captions · $date';
  }

  @override
  String get liveSessionInterrupted => 'interrupted';

  @override
  String get liveSearchHint => 'Search all captions';

  @override
  String get liveNoMatches => 'No captions match.';

  @override
  String get liveExport => 'Export…';

  @override
  String get liveDelete => 'Delete';

  @override
  String get liveDeleteConfirm => 'Delete this session and its captions?';

  @override
  String get liveExportBilingual => 'Bilingual';

  @override
  String get liveExportSource => 'Original only';

  @override
  String get liveExportTranslation => 'Translation only';

  @override
  String get liveTimesNote => 'Times count from the start of the captions.';

  @override
  String liveSaveFailed(String error) {
    return 'Could not save captions: $error';
  }

  @override
  String get sessionTranscript => 'Transcript';

  @override
  String get sessionDictation => 'Dictation';

  @override
  String get sessionNoMedia =>
      'No audio was saved with this session, so it can\'t be played. To keep audio next time, turn on “Save system audio with captions” in Settings.';

  @override
  String get playerBack5 => 'Back 5 seconds';

  @override
  String get playerForward5 => 'Forward 5 seconds';

  @override
  String get playerSpeed => 'Speed';

  @override
  String get playerVolume => 'Volume';

  @override
  String get playerMute => 'Mute';

  @override
  String get playerUnmute => 'Unmute';

  @override
  String get playerSetA => 'Set A';

  @override
  String get playerSetB => 'Set B';

  @override
  String get playerClearLoop => 'Clear loop';

  @override
  String get playerLoopSentence => 'Loop this sentence';

  @override
  String get dictationPrompt => 'Listen and type what you hear.';

  @override
  String get dictationPlay => 'Play sentence';

  @override
  String get dictationHint => 'Type the sentence… (⌘↩ checks, ⌘R replays)';

  @override
  String get dictationCheck => 'Check';

  @override
  String get dictationPrevious => 'Previous';

  @override
  String get dictationNext => 'Next';

  @override
  String get dictationReveal => 'Show answer';

  @override
  String get dictationCorrect => 'Correct';

  @override
  String get dictationClose => 'Almost';

  @override
  String get dictationIncorrect => 'Not yet';

  @override
  String dictationProgress(int done, int total) {
    return '$done of $total sentences correct';
  }

  @override
  String get dictationEmpty => 'No sentences to practise in this session yet.';

  @override
  String get importMedia => 'Import audio or video…';

  @override
  String importTranscribing(String percent) {
    return 'Transcribing · $percent%';
  }

  @override
  String get importCopying => 'Copying…';

  @override
  String get importCancel => 'Cancel';

  @override
  String recallInterval(String label, int days) {
    return '$label · $days d';
  }

  @override
  String get stepQuiz => 'Quiz';

  @override
  String youtubeBlocked(int code) {
    return 'This video can\'t be played inside TingLang (YouTube error $code).';
  }

  @override
  String get openOnYouTube => 'Open on YouTube';

  @override
  String get blindInlineHint =>
      'Type each missing word or phrase in place, then check. Colours: word, phrase, sentence.';

  @override
  String blindScore(int correct, int total) {
    return '$correct of $total correct';
  }

  @override
  String get blindAddMissed => 'Add missed items to review';

  @override
  String get blindAllCorrect => 'All correct. Step marked done.';

  @override
  String shadowReason(String reason) {
    return 'Why: $reason';
  }

  @override
  String get retellTryToUse => 'Try to use';

  @override
  String get quizIntro =>
      'Recall each item from its meaning, or fill it back into the sentence where you heard it. Misses go to your review deck.';

  @override
  String get quizRecall => 'Say it in English';

  @override
  String get quizCloze => 'Fill the gap';

  @override
  String get quizCheck => 'Check';

  @override
  String get quizNext => 'Next';

  @override
  String quizDone(int correct, int total) {
    return 'Quiz finished: $correct of $total.';
  }

  @override
  String get quizRestart => 'Try again';

  @override
  String get quizEmpty => 'This scene has no items to quiz.';

  @override
  String get addedToReview => 'Added to review';

  @override
  String get close => 'Close';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get save => 'Save';

  @override
  String get makeCourse => 'Make course';

  @override
  String get makeCourseBasic => 'Basic course';

  @override
  String get makeCourseBasicBody =>
      'Offline: words above your level, phrases and sentences, with blind listening and shadowing.';

  @override
  String get makeCourseAi => 'AI course';

  @override
  String get makeCourseAiBody =>
      'Your AI service writes explanations, examples, memory aids and a retelling outline.';

  @override
  String get makeCourseNoProvider => 'Add an AI provider in Settings to use this.';

  @override
  String get makeCourseProvider => 'Provider';

  @override
  String makeCourseConsent(String host) {
    return 'Send this transcript\'s text to $host';
  }

  @override
  String get makeCourseReplace =>
      'A course from this session already exists. Making it again replaces its content; your progress and review cards are kept.';

  @override
  String get makeCourseStart => 'Make course';

  @override
  String get makeCourseReading => 'Reading the transcript…';

  @override
  String get makeCourseSelecting => 'Choosing clips…';

  @override
  String makeCoursePlanning(int done, int total) {
    return 'Writing clip $done of $total…';
  }

  @override
  String get makeCourseCompiling => 'Checking and saving the course…';

  @override
  String makeCourseDone(int clips) {
    return 'Done: $clips clips are ready.';
  }

  @override
  String makeCourseFailed(String error) {
    return 'Could not make the course: $error';
  }

  @override
  String makeCourseRequests(int count) {
    return '$count AI requests';
  }

  @override
  String makeCourseFallbacks(int count) {
    return '$count clips used Basic content';
  }

  @override
  String get makeCourseOpen => 'Open course';

  @override
  String get providersTitle => 'AI providers';

  @override
  String get providersBody =>
      'Used for AI courses: any OpenAI-compatible service with your own key, or a model on this Mac with Ollama or LM Studio.';

  @override
  String get providersEmpty => 'No providers yet. Basic courses work without one.';

  @override
  String get providersPrivacy => 'Keys are kept in the macOS Keychain.';

  @override
  String get providerAdd => 'Add provider';

  @override
  String get providerEdit => 'Edit provider';

  @override
  String get providerPreset => 'Service';

  @override
  String get providerCustom => 'Custom (OpenAI-compatible)';

  @override
  String get providerName => 'Name';

  @override
  String get providerBaseUrl => 'Base URL';

  @override
  String get providerModel => 'Model';

  @override
  String get providerModelPick => 'Choose a model';

  @override
  String get providerApiKey => 'API key';

  @override
  String get providerApiKeyOptional => 'API key (optional)';

  @override
  String get providerKeyKeychain => 'Saved in the Keychain';

  @override
  String get providerKeyKeep => 'A key is saved. Leave empty to keep it.';

  @override
  String get providerKeySaved => 'key saved';

  @override
  String get providerKeyMissing => 'no key';

  @override
  String get providerTest => 'Test connection';

  @override
  String providerTestOk(int count) {
    return 'Connected · $count models available';
  }

  @override
  String get providerTestUnauthorized => 'The key was rejected.';

  @override
  String get providerCloud => 'Cloud';

  @override
  String get providerLocal => 'On this Mac';

  @override
  String get providerDefault => 'Use for course generation';

  @override
  String providerDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get providerDeleteBody =>
      'Its key is removed from the Keychain. Courses made with it stay.';

  @override
  String get providerUrlInvalid => 'Enter a base URL starting with http:// or https://';

  @override
  String get providerModelRequired => 'Enter a model name.';

  @override
  String providerModelContext(String tokens) {
    return '$tokens context';
  }

  @override
  String providerModelPrice(String input, String output) {
    return '$input in / $output out per 1M tokens';
  }

  @override
  String get providerModelLocal => 'Runs on this Mac: no per-token cost.';

  @override
  String get providerModelUnlisted => 'Not in the bundled catalog: price unknown.';

  @override
  String get providerLitellmHint => 'Runs through a LiteLLM Proxy you start yourself.';

  @override
  String makeCourseEstimate(int calls, String input, String output, String cost) {
    return 'Estimate: $calls requests · ~$input in / ~$output out tokens · $cost';
  }

  @override
  String makeCourseAbout(String usd) {
    return 'about $usd';
  }

  @override
  String get makeCourseLocalFree => 'free (runs on this Mac)';

  @override
  String get makeCourseNoPrice => 'no price data';

  @override
  String makeCourseTokens(String input, String output) {
    return '$input in / $output out tokens';
  }

  @override
  String get errorFileDialog =>
      'Couldn\'t open the file dialog. Quit and reopen the app, then try again.';

  @override
  String get errorFileMissing => 'That file is no longer available.';

  @override
  String errorUnsupportedFormat(String ext) {
    return '.$ext files aren\'t supported. Try MP3, M4A, WAV, MP4 or MOV.';
  }

  @override
  String get errorNoAudio => 'This file has no sound to transcribe.';

  @override
  String get errorNoTranscriber =>
      'No speech model can transcribe files on this Mac yet. Choose one in Settings → Speech recognition.';

  @override
  String errorWithDetail(String detail) {
    return 'Something went wrong: $detail';
  }

  @override
  String get importAndTranscribe => 'Import and transcribe';

  @override
  String get importCancelled => 'Import cancelled.';

  @override
  String get panelStart => 'Start live captions';

  @override
  String get panelUnavailable => 'Live captions can\'t start on this Mac right now';

  @override
  String get panelHistory => 'History and review';

  @override
  String get panelMore => 'More';

  @override
  String get panelAppearance => 'Appearance…';

  @override
  String get panelOpenApp => 'Open main window';

  @override
  String get panelSettings => 'Settings…';

  @override
  String get panelHide => 'Hide floating window';

  @override
  String get panelQuit => 'Quit';

  @override
  String get panelListening => 'Listening';

  @override
  String get panelWaiting => 'Waiting for speech…';

  @override
  String get panelView => 'View';

  @override
  String get panelMakeCourse => 'Make course';

  @override
  String get panelDropHint => 'Drop to import and transcribe';

  @override
  String panelNewRecordings(String count) {
    return '$count new recordings';
  }

  @override
  String get panelDisplay => 'Display';

  @override
  String get panelModeCard => 'Card';

  @override
  String get panelModeText => 'Text only';

  @override
  String get panelBackground => 'Background';

  @override
  String get panelBgGlass => 'Glass';

  @override
  String get panelBgSolid => 'Solid';

  @override
  String get panelBgClear => 'None';

  @override
  String get panelOpacity => 'Opacity';

  @override
  String get panelBackgroundColor => 'Background colour';

  @override
  String get panelTextColor => 'Text colour';

  @override
  String get panelTranslationColor => 'Translation colour';

  @override
  String get panelFontSize => 'Size and weight';

  @override
  String get panelWeightRegular => 'Regular';

  @override
  String get panelWeightMedium => 'Medium';

  @override
  String get panelWeightBold => 'Bold';

  @override
  String get panelLines => 'Lines';

  @override
  String get panelShowTranslation => 'Show translation';

  @override
  String get panelOutline => 'Outline text';

  @override
  String get panelCenter => 'Centre lines';

  @override
  String get panelLock => 'Lock and click through';

  @override
  String get panelUnlock => 'Unlock';

  @override
  String get panelResetPosition => 'Reset position';

  @override
  String get panelLayout => 'Layout';

  @override
  String get panelLayoutStacked => 'Stacked';

  @override
  String get panelLayoutSideBySide => 'Side by side';

  @override
  String get panelLocked => 'Locked · clicks pass through';

  @override
  String get panelLockToggle => 'Lock while captioning (clicks pass through)';

  @override
  String get panelJumpToLatest => 'Back to latest';

  @override
  String panelNewLines(String count) {
    return '$count new';
  }

  @override
  String get panelDockToggle => 'Start or stop captions';

  @override
  String get panelDockShow => 'Show floating window';

  @override
  String get panelDockUnlock => 'Unlock captions';

  @override
  String get panelPreparing => 'Getting ready…';

  @override
  String get panelDownloading => 'Downloading the speech model…';

  @override
  String get panelSaved => 'Saved';

  @override
  String panelSummary(String duration, String words) {
    return '$duration · $words words';
  }

  @override
  String panelFailed(String detail) {
    return 'Captions didn\'t start: $detail';
  }

  @override
  String panelImporting(String count) {
    return 'Importing $count file(s). Progress shows in History.';
  }

  @override
  String get panelRetry => 'Try again';

  @override
  String get navRecords => 'History';

  @override
  String get tabCaptions => 'Captions';

  @override
  String get tabReview => 'Review';

  @override
  String get tabSpeak => 'Speak';

  @override
  String get tabMine => 'Mine';

  @override
  String get tabDiscover => 'Discover';

  @override
  String get tabShared => 'Shared';

  @override
  String get importAudio => 'Import audio';

  @override
  String get recordsEmptyTitle => 'Nothing captured yet';

  @override
  String get recordsEmptyBody =>
      'Start live captions from the floating panel, or import a recording to transcribe it for close listening.';

  @override
  String get dayToday => 'Today';

  @override
  String get dayYesterday => 'Yesterday';

  @override
  String get liveRunning => 'Live captions are running';

  @override
  String get originFile => 'Imported';

  @override
  String get originShared => 'Shared';

  @override
  String get sessionFailed => 'transcription failed';

  @override
  String get reviewEmptyHint =>
      'Save useful expressions while studying a course; they come back here when they are due.';

  @override
  String get reviewDoneHint => 'The next expressions come back when they are due.';

  @override
  String get sharedEmptyTitle => 'Community sharing is coming';

  @override
  String get sharedEmptyBody => 'Until then, import .tinglang files that friends export for you.';

  @override
  String get importShared => 'Import shared file…';

  @override
  String get exportShared => 'Export share file…';

  @override
  String get sharedImported => 'Imported.';

  @override
  String get sharedExported => 'Share file saved.';

  @override
  String get shareNotPackage => 'This is not a TingLang share file.';

  @override
  String get shareNewerVersion =>
      'This file comes from a newer version of TingLang. Update the app and try again.';

  @override
  String get shareIncomplete => 'The share file is incomplete. Ask for it to be exported again.';

  @override
  String get shareTooLarge => 'The share file is too large to import.';

  @override
  String get shareUnsupportedMedia =>
      'The audio or video in this file is not in a supported format.';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsCaptions => 'Live captions';

  @override
  String get settingsShowPanel => 'Show the floating panel';

  @override
  String get settingsPanelLayout => 'Floating panel layout';

  @override
  String get settingsPanelScrollback => 'Lines you can scroll back on the panel';

  @override
  String settingsScrollbackLines(String count) {
    return '$count lines';
  }

  @override
  String get settingsKeepSystemAudio => 'Save system audio with captions';

  @override
  String get settingsKeepSystemAudioHelp =>
      'Lets you replay what was said. Only for material you may record.';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsBackupHint =>
      'Everything lives in this folder; back it up to keep your history.';

  @override
  String get settingsAbout => 'About';

  @override
  String get voiceMemos => 'Voice Memos';

  @override
  String voiceMemosImport(String count) {
    return 'Import and transcribe ($count)';
  }

  @override
  String get voiceMemoImported => 'Imported';

  @override
  String voiceMemoUntitled(String date) {
    return 'Voice memo · $date';
  }

  @override
  String get voiceMemosAccessTitle => 'Let TingLang read Voice Memos';

  @override
  String get voiceMemosAccessBody =>
      'macOS keeps Voice Memos in a protected folder. Turn on TingLang in System Settings › Privacy & Security › Full Disk Access; macOS may ask you to quit and reopen it.';

  @override
  String get voiceMemosOpenSettings => 'Open System Settings';

  @override
  String get voiceMemosCheckAgain => 'Check again';

  @override
  String get voiceMemosNoLibrary =>
      'No Voice Memos on this Mac yet. Turn on Voice Memos in iCloud on your iPhone and this Mac, and your recordings appear here.';

  @override
  String get voiceMemosUnreadable =>
      'Couldn\'t read the Voice Memos library. Open the Voice Memos app once, then check again.';

  @override
  String get voiceMemosEmpty => 'No recordings on this Mac yet.';

  @override
  String voiceMemosNewToday(String count) {
    return '$count new voice memos today';
  }

  @override
  String get voiceMemosImportShort => 'Import';

  @override
  String get originVoiceMemo => 'Voice Memos';

  @override
  String get settingsAccount => 'Account';

  @override
  String get accountSignedOutBody =>
      'Sign in to see your plan and usage. Buying and managing happen on the website; everything on this Mac works without an account.';

  @override
  String accountSignInHost(String host) {
    return 'Signing in opens $host in your browser. Nothing is sent before you sign in.';
  }

  @override
  String get accountSignIn => 'Sign in in browser';

  @override
  String get accountSigningIn => 'Waiting for the browser…';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get navSignIn => 'Sign in';

  @override
  String get planFree => 'Free';

  @override
  String get accountUpgrade => 'Upgrade to Pro';

  @override
  String get cloudOfficialSoon => 'TingLang official (coming soon)';

  @override
  String get accountRefresh => 'Refresh';

  @override
  String get accountManage => 'Manage on the website';

  @override
  String get accountPlans => 'Plans';

  @override
  String accountPlan(String plan) {
    return 'Plan: $plan';
  }

  @override
  String get accountStatusActive => 'Active';

  @override
  String get accountStatusTrialing => 'Trial';

  @override
  String get accountStatusPastDue => 'Payment due';

  @override
  String get accountStatusCanceled => 'Canceled';

  @override
  String get accountStatusExpired => 'Expired';

  @override
  String get accountStatusNone => 'No plan';

  @override
  String get accountStatusUnknown => 'Unknown status';

  @override
  String get accountServices => 'Cloud services';

  @override
  String get accountNoServices =>
      'TingLang\'s own cloud services (transcription, AI courses) are coming soon.';

  @override
  String get cloudServiceTranscribe => 'Cloud transcription';

  @override
  String get cloudServiceTranslate => 'Cloud translation';

  @override
  String get cloudServiceLlm => 'AI courses without your own key';

  @override
  String get cloudServiceIncluded => 'Included';

  @override
  String get cloudServiceNotInPlan => 'Not in your plan';

  @override
  String quotaMinutes(String used, String limit) {
    return '$used of $limit minutes used';
  }

  @override
  String quotaCredits(String used, String limit) {
    return '$used of $limit credits used';
  }

  @override
  String quotaOther(String used, String limit) {
    return '$used of $limit used';
  }

  @override
  String quotaResets(String date) {
    return 'resets $date';
  }

  @override
  String accountOffline(String host, String time) {
    return 'Cannot reach $host. Showing the plan as of $time.';
  }

  @override
  String accountOfflineUnconfirmed(String host) {
    return 'Cannot reach $host, so the plan cannot be confirmed right now. Features on this Mac are not affected.';
  }

  @override
  String cloudErrorUnreachable(String host) {
    return 'Cannot reach $host. Check the address and your connection; features on this Mac keep working.';
  }

  @override
  String get cloudErrorNoAccounts => 'This server does not offer accounts.';

  @override
  String get cloudErrorNoBrowser =>
      'Signing in through the browser is not available on this system.';

  @override
  String get cloudErrorNoKeychain => 'There is no secure storage for the sign-in on this system.';

  @override
  String get cloudErrorCanceled => 'Sign-in was canceled.';

  @override
  String get cloudErrorSignIn => 'Sign-in did not complete. Try again.';

  @override
  String get cloudErrorSessionEnded => 'Your session has ended. Sign in again.';

  @override
  String get cloudErrorClientTooOld => 'This server needs a newer version of TingLang.';

  @override
  String get cloudErrorEntitlement => 'This needs a plan that includes it.';

  @override
  String get cloudErrorQuota => 'The quota for this period is used up.';

  @override
  String get cloudErrorRateLimited => 'Too many requests. Try again in a moment.';

  @override
  String get cloudErrorFeatureDisabled => 'This server does not offer that.';

  @override
  String get cloudErrorMaintenance => 'The server is under maintenance. Try again later.';

  @override
  String cloudErrorServer(String code) {
    return 'The server could not handle the request ($code).';
  }

  @override
  String get cloudErrorBadResponse => 'The server sent something TingLang does not understand.';

  @override
  String get settingsSpeechModels => 'Speech recognition';

  @override
  String get speechForLive => 'Live captions';

  @override
  String get speechForFiles => 'File transcription';

  @override
  String get speechAuto => 'Automatic';

  @override
  String get speechModelAppleSpeech => 'Apple Speech';

  @override
  String get speechModelAppleDictation => 'Apple Dictation';

  @override
  String get speechModelXasr => 'X-ASR Chinese + English';

  @override
  String get speechModelSmallEn => 'Zipformer English 20M';

  @override
  String get speechModelMediumEn => 'Zipformer English 66M';

  @override
  String get speechModelXasrOffline => 'X-ASR Chinese + English (files)';

  @override
  String get speechModelParakeet => 'Parakeet TDT 0.6B v2';

  @override
  String get speechAccuracy => 'Accuracy';

  @override
  String get speechSpeed => 'Speed';

  @override
  String get speechSystemAsset => 'Part of macOS';

  @override
  String get speechInstalled => 'Downloaded';

  @override
  String speechNeedsMacos(String version) {
    return 'Needs macOS $version';
  }

  @override
  String get speechInUse => 'In use';

  @override
  String get speechUseThis => 'Use';

  @override
  String speechDownload(String size) {
    return 'Download $size';
  }

  @override
  String get speechDelete => 'Delete';

  @override
  String get speechCancel => 'Cancel';

  @override
  String speechDownloading(String percent) {
    return 'Downloading… $percent%';
  }

  @override
  String speechDownloadTitle(String name) {
    return 'Download $name?';
  }

  @override
  String speechDownloadBody(String size, String host, String license) {
    return '$size from $host, kept in TingLang\'s data folder until you delete it. Licence: $license.';
  }

  @override
  String speechDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String speechDeleteBody(String size) {
    return 'Frees $size. You can download it again later.';
  }

  @override
  String get speechAccent => 'English accent';

  @override
  String get speechAccentDownload => 'Download from Apple';

  @override
  String get speechAccentRemove => 'Remove';

  @override
  String get speechFarField => 'Far-field audio (speakers, across a room)';

  @override
  String get speechShortForm => 'Short phrases';

  @override
  String get speechLatency => 'Recognition latency';

  @override
  String get latencyPowerSaver => 'Power saver';

  @override
  String get latencyBalanced => 'Balanced';

  @override
  String get latencyFastest => 'Lowest latency';

  @override
  String get latencyPowerSaverHelp => 'Uses the least CPU; captions update a little less often.';

  @override
  String get latencyBalancedHelp => 'Recommended.';

  @override
  String get latencyFastestHelp => 'Earliest captions, slightly more CPU.';

  @override
  String panelModelNeeded(String name, String size) {
    return '$name needs a one-time download ($size) before captions can start.';
  }

  @override
  String panelDownloadingModel(String name, String percent) {
    return 'Downloading $name… $percent%';
  }

  @override
  String panelLanguageUnsupported(String name, String language) {
    return '$name does not recognise $language. Choose another model in Settings.';
  }

  @override
  String get panelOpenSettings => 'Settings';

  @override
  String errorModelMissing(String name) {
    return 'Download $name in Settings → Speech recognition first.';
  }

  @override
  String errorSpeechAssetMissing(String locale) {
    return 'macOS needs to download its speech model for $locale first (Settings → Speech recognition).';
  }

  @override
  String get speechChecksumFailed =>
      'The download did not match its checksum and was removed. The publisher may have changed the file; try again later.';

  @override
  String get settingsSyncData => 'Sync & data';

  @override
  String get speechMode => 'Recognition';

  @override
  String get speechModeLocal => 'On this Mac';

  @override
  String get speechModeCloud => 'Cloud API';

  @override
  String get speechChooseTitle => 'How should TingLang recognise speech?';

  @override
  String get speechChooseLocal => 'Use a model on this Mac';

  @override
  String get speechChooseLocalBody => 'Recognised on this Mac; no audio is uploaded.';

  @override
  String get speechChooseCloud => 'Use a cloud API';

  @override
  String get speechChooseCloudBody =>
      'For Macs that can\'t run the models. Your own key; audio is uploaded.';

  @override
  String speechCpuLevel(String level) {
    return 'CPU $level';
  }

  @override
  String get speechCpuLow => 'low';

  @override
  String get speechCpuMedium => 'medium';

  @override
  String get speechCpuHigh => 'high';

  @override
  String get cloudSpeechService => 'Service';

  @override
  String cloudSpeechSendsTo(String host) {
    return 'Audio is sent to $host.';
  }

  @override
  String get cloudSpeechGetKey => 'Get a key';

  @override
  String get cloudSpeechSaved => 'Saved.';

  @override
  String get cloudSpeechTestOk => 'Connected.';

  @override
  String get cloudSpeechForget => 'Remove keys';

  @override
  String cloudSpeechForgetTitle(String service) {
    return 'Remove the $service keys?';
  }

  @override
  String cloudSpeechNoLive(String service) {
    return '$service has no live recognition; live captions use the model on this Mac.';
  }

  @override
  String cloudSpeechNoFile(String service) {
    return '$service cannot transcribe files; files use the model on this Mac.';
  }

  @override
  String cloudSpeechFieldRequired(String field) {
    return 'Enter $field.';
  }

  @override
  String get cloudFieldApiKey => 'API Key';

  @override
  String get cloudFieldApiSecret => 'API Secret';

  @override
  String get cloudFieldAppId => 'App ID';

  @override
  String get cloudFieldSecretId => 'SecretId';

  @override
  String get cloudFieldSecretKey => 'SecretKey';

  @override
  String get cloudFieldRegion => 'Region';

  @override
  String get cloudRegionExample => 'e.g. eastus';

  @override
  String get cloudRegionCn => 'Mainland China (Beijing)';

  @override
  String get cloudRegionIntl => 'International (Singapore)';

  @override
  String get cloudRegionUs => 'United States';

  @override
  String get cloudRegionEu => 'European Union';

  @override
  String get cloudTencent => 'Tencent Cloud';

  @override
  String get cloudDashscope => 'Alibaba Cloud Model Studio';

  @override
  String get cloudXfyun => 'iFlytek';

  @override
  String get cloudSoniox => 'Soniox';

  @override
  String get cloudAssemblyai => 'AssemblyAI';

  @override
  String get cloudAzure => 'Azure AI Speech';

  @override
  String get panelChooseRecognizer =>
      'Choose how to recognise speech first: a model on this Mac or a cloud API.';

  @override
  String panelCloudNotSetUp(String service) {
    return 'Add your $service key in Settings first.';
  }

  @override
  String get panelCloudNotChosen => 'Choose a cloud service in Settings first.';

  @override
  String panelCloudLanguage(String service, String language) {
    return '$service does not recognise $language.';
  }

  @override
  String panelCloudLabel(String service) {
    return 'Cloud · $service';
  }

  @override
  String asrFailedUnauthorized(String service) {
    return '$service refused the key. Check it in Settings.';
  }

  @override
  String asrFailedQuota(String service) {
    return '$service: no balance left, or the service isn\'t activated.';
  }

  @override
  String asrFailedRateLimited(String service) {
    return '$service is busy. Try again shortly.';
  }

  @override
  String asrFailedNetwork(String service) {
    return 'Can\'t reach $service. Check the network.';
  }

  @override
  String asrFailedLanguage(String service) {
    return '$service does not support this language.';
  }

  @override
  String asrFailedTooLong(String service) {
    return 'The file is too long for $service.';
  }

  @override
  String asrFailedOther(String service, String message) {
    return '$service: $message';
  }

  @override
  String get errorCloudNotSetUp =>
      'Cloud recognition is on, but no key is saved. Add one in Settings → Speech recognition.';

  @override
  String get accentUS => 'United States';

  @override
  String get accentGB => 'United Kingdom';

  @override
  String get accentAU => 'Australia';

  @override
  String get accentIN => 'India';

  @override
  String get accentCA => 'Canada';

  @override
  String get accentIE => 'Ireland';

  @override
  String get accentNZ => 'New Zealand';

  @override
  String get accentSG => 'Singapore';

  @override
  String get accentZA => 'South Africa';

  @override
  String get syncTitle => 'iCloud Drive sync';

  @override
  String get syncBadge => 'iCloud';

  @override
  String get syncBody =>
      'Keep your courses, recordings and learning progress the same on every Mac signed in to your Apple Account. macOS syncs a Tinglang folder in your iCloud Drive; TingLang has no server of its own.';

  @override
  String get syncSwitch => 'Sync through iCloud Drive';

  @override
  String get syncOff => 'Off. Nothing is copied to iCloud Drive.';

  @override
  String get syncUnavailable =>
      'iCloud Drive is off or not set up on this Mac. Turn it on in System Settings → Apple Account → iCloud → iCloud Drive, then come back here.';

  @override
  String get syncNoAccess =>
      'TingLang is not allowed to open iCloud Drive. Allow it in System Settings → Privacy & Security → Files and Folders, then try again.';

  @override
  String syncFailed(String error) {
    return 'Could not use the Tinglang folder in iCloud Drive. $error';
  }

  @override
  String get syncSyncing => 'Syncing…';

  @override
  String get syncUpToDate => 'Up to date';

  @override
  String get syncNever => 'Not synced yet';

  @override
  String syncLast(String time) {
    return 'Last synced $time';
  }

  @override
  String syncWaiting(String count) {
    return 'Waiting for iCloud to download $count item(s). They are added as soon as they arrive.';
  }

  @override
  String syncCounts(String courses, String recordings, String records) {
    return '$courses course(s) · $recordings recording(s) · $records learning record(s)';
  }

  @override
  String syncOtherMacs(String count) {
    return 'Shared with $count other Mac(s)';
  }

  @override
  String get syncFolderLabel => 'iCloud Drive › Tinglang';

  @override
  String get syncShowInFinder => 'Show in Finder';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncProblemNewerFolder =>
      'The Tinglang folder in iCloud Drive was set up by a newer version of TingLang. Update TingLang on this Mac to keep syncing.';

  @override
  String syncProblemNewerState(String name) {
    return '$name uses a newer version of TingLang. Its changes are skipped until you update TingLang on this Mac.';
  }

  @override
  String get syncProblemUnreadableState =>
      'Changes from another Mac could not be read and were skipped.';

  @override
  String syncProblemNewerPackage(String name) {
    return 'Skipped $name: it was made by a newer version of TingLang.';
  }

  @override
  String syncProblemUnreadablePackage(String name) {
    return 'Skipped $name: its file in iCloud Drive could not be read.';
  }

  @override
  String get syncProblemWriteFailed =>
      'Some changes could not be saved to iCloud Drive. Check that the disk has free space.';

  @override
  String get syncUnnamedItem => 'an item';

  @override
  String syncMoreProblems(String count) {
    return 'And $count more.';
  }

  @override
  String get syncFootnote =>
      'Settings and API keys stay on each Mac. Turning sync off keeps what is already in iCloud Drive.';

  @override
  String updateAvailable(String version) {
    return 'TingLang $version is available.';
  }

  @override
  String get updateWhatsNew => 'What\'s new';

  @override
  String get updateInstall => 'Update and restart';

  @override
  String get updateLater => 'Later';

  @override
  String updateDownloading(String version, String percent) {
    return 'Downloading TingLang $version… $percent%';
  }

  @override
  String get updateCancel => 'Cancel';

  @override
  String get updateInstalling => 'Checking the download and getting it ready…';

  @override
  String get updateRestarting =>
      'TingLang is quitting to finish the update and will open again by itself.';

  @override
  String get updateTryAgain => 'Try again';

  @override
  String get updateOpenReleasePage => 'Open the release page';

  @override
  String get updateErrorNetwork =>
      'The download stopped. Check your internet connection and try again.';

  @override
  String get updateErrorChecksum =>
      'The download did not match its published checksum, so it was deleted. Try again later.';

  @override
  String updateErrorPackage(String version) {
    return 'The download is not TingLang $version, so nothing was installed. Download it from the release page instead.';
  }

  @override
  String get updateErrorDisk =>
      'The update could not be saved on this Mac. Check that the disk has free space.';

  @override
  String get updateErrorBusy => 'Finish or save your recording first, then update.';

  @override
  String get updateErrorQuitRefused =>
      'TingLang could not quit, so the update was not installed. Try again.';

  @override
  String get updateErrorInstall =>
      'The new version could not be put in place. Download it from the release page and replace TingLang yourself.';

  @override
  String get updateErrorNotBundle =>
      'TingLang cannot find its own app to replace. Download the new version from the release page.';

  @override
  String get updateErrorTranslocated =>
      'macOS is running TingLang from a temporary copy. Move TingLang to the Applications folder, open it from there and try again, or download the new version from the release page.';

  @override
  String get updateErrorReadOnly =>
      'TingLang is running from a disk that cannot be changed (a disk image, for example). Move it to the Applications folder first, or download the new version from the release page.';

  @override
  String updateErrorNotWritable(String folder) {
    return 'Your account cannot change the folder TingLang is in ($folder). Download the new version from the release page and replace TingLang yourself.';
  }

  @override
  String get updateSettingsTitle => 'Updates';

  @override
  String get updateAutoCheck => 'Check for updates automatically';

  @override
  String get updateAutoCheckHelp =>
      'Once a day TingLang asks GitHub (api.github.com) whether a new version is out. Only the app\'s version is sent, nothing about you or your recordings. When this is off, TingLang checks only when you press Check now.';

  @override
  String updateCurrentVersion(String version) {
    return 'You have TingLang $version.';
  }

  @override
  String get updateCheckNow => 'Check now';

  @override
  String get updateChecking => 'Checking…';

  @override
  String get updateUpToDate => 'This is the latest version.';

  @override
  String get updateNoneFound => 'No update found.';

  @override
  String get updateNeverChecked => 'Not checked yet.';

  @override
  String updateLastChecked(String time) {
    return 'Last checked $time.';
  }

  @override
  String get panelHintRecord => 'Start live captions (⌘⇧T)';

  @override
  String get panelHintStop => 'Stop live captions (⌘⇧T)';

  @override
  String get panelHintMenu => 'TingLang menu: open the app, appearance, settings';

  @override
  String updateBadgeHint(String version) {
    return 'TingLang $version is available — click to update';
  }

  @override
  String updateDialogTitle(String version) {
    return 'TingLang $version is available';
  }

  @override
  String updateDialogBody(String current) {
    return 'You have $current. Updating downloads the new version, checks it, puts it in place and reopens TingLang. Your library and settings stay as they are.';
  }

  @override
  String get onboardingWelcome => 'Welcome to TingLang';

  @override
  String onboardingStepOf(String current, String total) {
    return 'Step $current of $total';
  }

  @override
  String get onboardingStepPermissions => 'Permissions';

  @override
  String get onboardingStepModel => 'Speech model';

  @override
  String get onboardingStepUsage => 'How to use';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingDone => 'Get started';

  @override
  String get onboardingPermissionsTitle => 'Let TingLang hear the sound';

  @override
  String get onboardingPermissionsBody =>
      'macOS asks you to approve these yourself. TingLang uses them only while captions or a recording run; unless you turn on a cloud service, the sound stays on this Mac.';

  @override
  String get onboardingPermissionsReturn =>
      'Come back after changing System Settings: this list updates by itself.';

  @override
  String get permissionRequired => 'Required';

  @override
  String get permissionOptional => 'Optional';

  @override
  String get permissionGranted => 'Allowed';

  @override
  String get permissionDenied => 'Not allowed';

  @override
  String get permissionAskedLater => 'Asked on first use';

  @override
  String get permissionAllow => 'Allow';

  @override
  String get permissionOpenSettings => 'Open System Settings';

  @override
  String get permissionSystemAudio => 'System audio recording';

  @override
  String get permissionSystemAudioBody =>
      'Live captions hear what your Mac plays (videos, meetings, podcasts) through it. macOS asks the first time captions start: choose Allow. If you said no before, open System Settings and turn TingLang on under system audio recording.';

  @override
  String get permissionMicrophone => 'Microphone';

  @override
  String get permissionMicrophoneBody =>
      'For speaking practice, and for captions when their source is the microphone.';

  @override
  String get permissionScreen => 'Screen recording';

  @override
  String get permissionScreenBody =>
      'A fallback: when system audio arrives silent, TingLang takes the sound through screen recording instead. It keeps no picture.';

  @override
  String get permissionFullDisk => 'Full Disk Access';

  @override
  String get permissionFullDiskBody =>
      'Only for importing Voice Memos; macOS may ask you to quit and reopen TingLang.';

  @override
  String get onboardingModelTitle => 'Choose how speech is recognised';

  @override
  String get onboardingModelBody =>
      'Captions and transcripts come from a speech recognition model. A model on this Mac suits most people: free, offline, and the audio never leaves it.';

  @override
  String get onboardingRecommended => 'Recommended';

  @override
  String get onboardingModelForMac => 'Recommended for this Mac';

  @override
  String get onboardingModelReady => 'Ready';

  @override
  String get onboardingModelNone => 'No model on this Mac can run yet; a cloud API still works.';

  @override
  String get onboardingModelMore =>
      'Other models, latency and accents are in Settings → Speech recognition.';

  @override
  String get onboardingCloudNext =>
      'When you finish this guide, Settings → Speech recognition opens: pick a service and enter your own key.';

  @override
  String get onboardingUsageTitle => 'Using TingLang';

  @override
  String get onboardingUseStartTitle => 'Start live captions';

  @override
  String get onboardingUseStartBody =>
      'Press the orange button at the left end of the floating panel, or ⌘⇧T in any app. What your Mac plays turns into captions as you listen.';

  @override
  String get onboardingUsePanelTitle => 'Place the panel';

  @override
  String get onboardingUsePanelBody =>
      'Drag the panel anywhere over a video or a meeting. Point at it for its toolbar: change the look, or lock it so clicks pass through.';

  @override
  String get onboardingUseHistoryTitle => 'Replay and learn';

  @override
  String get onboardingUseHistoryBody =>
      'When you stop, the session is saved in History: replay it line by line, or make a course for close listening, speaking and review.';

  @override
  String get onboardingUseFilesTitle => 'Transcribe files';

  @override
  String get onboardingUseFilesBody =>
      'Drop an audio or video file on the panel or the main window to get a transcript you can replay line by line.';

  @override
  String get onboardingReopen => 'You can open this guide again from Settings → General.';

  @override
  String get onboardingSettingsTitle => 'Getting started';

  @override
  String get onboardingSettingsBody =>
      'Permissions, the speech model and the basics, step by step.';

  @override
  String get onboardingSettingsOpen => 'Show again';
}
