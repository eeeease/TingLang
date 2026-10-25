import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('zh')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TingLang'**
  String get appTitle;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @exitBlockedRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop and save the recording before quitting TingLang.'**
  String get exitBlockedRecording;

  /// No description provided for @exitBlockedSaveError.
  ///
  /// In en, this message translates to:
  /// **'Something still failed to save. Fix the local storage problem first.'**
  String get exitBlockedSaveError;

  /// No description provided for @lockPendingAttempt.
  ///
  /// In en, this message translates to:
  /// **'The recording stopped but its record is not saved yet. Use Retry save below.'**
  String get lockPendingAttempt;

  /// No description provided for @lockRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording in progress. Stop and save before switching pages.'**
  String get lockRecording;

  /// No description provided for @persistenceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save locally: {error}'**
  String persistenceFailed(String error);

  /// No description provided for @retrySave.
  ///
  /// In en, this message translates to:
  /// **'Retry save'**
  String get retrySave;

  /// No description provided for @showDataLocation.
  ///
  /// In en, this message translates to:
  /// **'Show data location'**
  String get showDataLocation;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @startupFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'TingLang could not start'**
  String get startupFailedTitle;

  /// No description provided for @startupFailedNotice.
  ///
  /// In en, this message translates to:
  /// **'Your library was not reset. Leave the data folder as it is, and copy the error details if you ask for help.'**
  String get startupFailedNotice;

  /// No description provided for @copyErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'Copy error details'**
  String get copyErrorDetails;

  /// No description provided for @areaNba.
  ///
  /// In en, this message translates to:
  /// **'NBA'**
  String get areaNba;

  /// No description provided for @areaGaming.
  ///
  /// In en, this message translates to:
  /// **'Gaming'**
  String get areaGaming;

  /// No description provided for @areaCinema.
  ///
  /// In en, this message translates to:
  /// **'Cinema'**
  String get areaCinema;

  /// No description provided for @areaLife.
  ///
  /// In en, this message translates to:
  /// **'Life & Vlogs'**
  String get areaLife;

  /// No description provided for @areaPodcasts.
  ///
  /// In en, this message translates to:
  /// **'Podcasts'**
  String get areaPodcasts;

  /// No description provided for @areaPersonal.
  ///
  /// In en, this message translates to:
  /// **'My voice'**
  String get areaPersonal;

  /// No description provided for @discoverEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Curated podcasts and channels are on the way'**
  String get discoverEmptyTitle;

  /// No description provided for @discoverEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Themed shelves of hand-picked podcasts and channels to listen to closely.'**
  String get discoverEmptyBody;

  /// No description provided for @discoverImportInstead.
  ///
  /// In en, this message translates to:
  /// **'Import your own material'**
  String get discoverImportInstead;

  /// No description provided for @importMaterial.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importMaterial;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search courses or sources…'**
  String get searchHint;

  /// No description provided for @allScenes.
  ///
  /// In en, this message translates to:
  /// **'All scenes'**
  String get allScenes;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Start with something you genuinely care about.'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Import a video or audio you care about, or try the sample first.'**
  String get libraryEmptyBody;

  /// No description provided for @loadDemo.
  ///
  /// In en, this message translates to:
  /// **'Load the sample course'**
  String get loadDemo;

  /// No description provided for @demoLoaded.
  ///
  /// In en, this message translates to:
  /// **'The sample was added to NBA.'**
  String get demoLoaded;

  /// No description provided for @courseScenes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 scene} other{{count} scenes}}'**
  String courseScenes(int count);

  /// No description provided for @mediaPending.
  ///
  /// In en, this message translates to:
  /// **'Media not attached'**
  String get mediaPending;

  /// No description provided for @mediaLocal.
  ///
  /// In en, this message translates to:
  /// **'Local media'**
  String get mediaLocal;

  /// No description provided for @percentDone.
  ///
  /// In en, this message translates to:
  /// **'{percent}% done'**
  String percentDone(int percent);

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Bring your own scene'**
  String get importTitle;

  /// No description provided for @importSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local video or audio, with subtitles if you have them.'**
  String get importSubtitle;

  /// No description provided for @importAreaLabel.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get importAreaLabel;

  /// No description provided for @pickMedia.
  ///
  /// In en, this message translates to:
  /// **'Choose local video / audio'**
  String get pickMedia;

  /// No description provided for @pickSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Choose SRT / VTT subtitles (optional)'**
  String get pickSubtitles;

  /// No description provided for @courseNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Course name'**
  String get courseNameLabel;

  /// No description provided for @untitledScene.
  ///
  /// In en, this message translates to:
  /// **'Untitled scene'**
  String get untitledScene;

  /// No description provided for @importNeedMedia.
  ///
  /// In en, this message translates to:
  /// **'Choose a media file.'**
  String get importNeedMedia;

  /// No description provided for @updateCourseTitle.
  ///
  /// In en, this message translates to:
  /// **'Update existing course?'**
  String get updateCourseTitle;

  /// No description provided for @updateCourseBody.
  ///
  /// In en, this message translates to:
  /// **'A course with this ID already exists. Its content will be updated; your practice records, recordings, saved expressions and completion marks are kept.'**
  String get updateCourseBody;

  /// No description provided for @updateContent.
  ///
  /// In en, this message translates to:
  /// **'Update content'**
  String get updateContent;

  /// No description provided for @importing.
  ///
  /// In en, this message translates to:
  /// **'Copying and checking…'**
  String get importing;

  /// No description provided for @importToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add to library'**
  String get importToLibrary;

  /// No description provided for @attachMediaPrompt.
  ///
  /// In en, this message translates to:
  /// **'The course is ready. Attach the original media to play it.'**
  String get attachMediaPrompt;

  /// No description provided for @attachMedia.
  ///
  /// In en, this message translates to:
  /// **'Attach full video / audio'**
  String get attachMedia;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @playClip.
  ///
  /// In en, this message translates to:
  /// **'Play clip'**
  String get playClip;

  /// No description provided for @backToClipStart.
  ///
  /// In en, this message translates to:
  /// **'Back to clip start'**
  String get backToClipStart;

  /// No description provided for @abLoop.
  ///
  /// In en, this message translates to:
  /// **'A–B loop'**
  String get abLoop;

  /// No description provided for @clipRange.
  ///
  /// In en, this message translates to:
  /// **'CLIP {start} — {end}'**
  String clipRange(String start, String end);

  /// No description provided for @clipEnd.
  ///
  /// In en, this message translates to:
  /// **'end'**
  String get clipEnd;

  /// No description provided for @mediaBoundsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Course times go beyond the media length. Attach the complete original media from the same source, not an already-cut clip.'**
  String get mediaBoundsMismatch;

  /// No description provided for @transcript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get transcript;

  /// No description provided for @hideTranscript.
  ///
  /// In en, this message translates to:
  /// **'Hide transcript'**
  String get hideTranscript;

  /// No description provided for @showTranscript.
  ///
  /// In en, this message translates to:
  /// **'Show transcript'**
  String get showTranscript;

  /// No description provided for @noSubtitles.
  ///
  /// In en, this message translates to:
  /// **'No subtitles yet. Pair this media with an SRT/VTT file when importing it.'**
  String get noSubtitles;

  /// No description provided for @listenFirst.
  ///
  /// In en, this message translates to:
  /// **'Listen once first; let the words appear a little later.'**
  String get listenFirst;

  /// No description provided for @wordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Words worth keeping'**
  String get wordsTitle;

  /// No description provided for @phrasesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expressions you can reuse'**
  String get phrasesTitle;

  /// No description provided for @sentencesTitle.
  ///
  /// In en, this message translates to:
  /// **'A frame for your own words'**
  String get sentencesTitle;

  /// No description provided for @noItems.
  ///
  /// In en, this message translates to:
  /// **'No prepared words or patterns for this clip. You can still listen, shadow and record.'**
  String get noItems;

  /// No description provided for @saveToReview.
  ///
  /// In en, this message translates to:
  /// **'Save to review'**
  String get saveToReview;

  /// No description provided for @savedToReview.
  ///
  /// In en, this message translates to:
  /// **'Added to review.'**
  String get savedToReview;

  /// No description provided for @inThisScene.
  ///
  /// In en, this message translates to:
  /// **'IN THIS SCENE\n{text}'**
  String inThisScene(String text);

  /// No description provided for @makeItYours.
  ///
  /// In en, this message translates to:
  /// **'MAKE IT YOURS\n{text}'**
  String makeItYours(String text);

  /// No description provided for @frameLabel.
  ///
  /// In en, this message translates to:
  /// **'Frame: {frame}'**
  String frameLabel(String frame);

  /// No description provided for @blindTitle.
  ///
  /// In en, this message translates to:
  /// **'Listen before you look'**
  String get blindTitle;

  /// No description provided for @noBlanks.
  ///
  /// In en, this message translates to:
  /// **'No prepared blanks. Hide the transcript, listen to the whole clip, then say what you heard.'**
  String get noBlanks;

  /// No description provided for @checkAnswers.
  ///
  /// In en, this message translates to:
  /// **'Check my answers'**
  String get checkAnswers;

  /// No description provided for @hideAnswers.
  ///
  /// In en, this message translates to:
  /// **'Hide answers'**
  String get hideAnswers;

  /// No description provided for @showAnswers.
  ///
  /// In en, this message translates to:
  /// **'Show answers'**
  String get showAnswers;

  /// No description provided for @shadowTitle.
  ///
  /// In en, this message translates to:
  /// **'Borrow the rhythm'**
  String get shadowTitle;

  /// No description provided for @retellTitle.
  ///
  /// In en, this message translates to:
  /// **'Now, make it yours'**
  String get retellTitle;

  /// No description provided for @shadowFallback.
  ///
  /// In en, this message translates to:
  /// **'Play the original, pause, then record your shadowing.'**
  String get shadowFallback;

  /// No description provided for @focusOn.
  ///
  /// In en, this message translates to:
  /// **'Focus on'**
  String get focusOn;

  /// No description provided for @needHint.
  ///
  /// In en, this message translates to:
  /// **'Need a hint?'**
  String get needHint;

  /// No description provided for @stepWords.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get stepWords;

  /// No description provided for @stepPhrases.
  ///
  /// In en, this message translates to:
  /// **'Phrases'**
  String get stepPhrases;

  /// No description provided for @stepSentences.
  ///
  /// In en, this message translates to:
  /// **'Sentences'**
  String get stepSentences;

  /// No description provided for @stepBlind.
  ///
  /// In en, this message translates to:
  /// **'Blind'**
  String get stepBlind;

  /// No description provided for @stepShadow.
  ///
  /// In en, this message translates to:
  /// **'Shadow'**
  String get stepShadow;

  /// No description provided for @stepRetell.
  ///
  /// In en, this message translates to:
  /// **'Retell'**
  String get stepRetell;

  /// No description provided for @stepDone.
  ///
  /// In en, this message translates to:
  /// **'I\'ve finished this step'**
  String get stepDone;

  /// No description provided for @backToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back to library'**
  String get backToLibrary;

  /// No description provided for @changeMedia.
  ///
  /// In en, this message translates to:
  /// **'Change media'**
  String get changeMedia;

  /// No description provided for @practiceHint.
  ///
  /// In en, this message translates to:
  /// **'Jot down a few cue words, or what you just wanted to say…\nYour words are kept exactly as written.'**
  String get practiceHint;

  /// No description provided for @draftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved on this computer'**
  String get draftSaved;

  /// No description provided for @draftSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving draft…'**
  String get draftSaving;

  /// No description provided for @stopAndSave.
  ///
  /// In en, this message translates to:
  /// **'Stop and save · {time}'**
  String stopAndSave(String time);

  /// No description provided for @recordYourself.
  ///
  /// In en, this message translates to:
  /// **'Record yourself'**
  String get recordYourself;

  /// No description provided for @saveTextOnly.
  ///
  /// In en, this message translates to:
  /// **'Save text only'**
  String get saveTextOnly;

  /// No description provided for @recordingBadge.
  ///
  /// In en, this message translates to:
  /// **'● Recording'**
  String get recordingBadge;

  /// No description provided for @practiceNotice.
  ///
  /// In en, this message translates to:
  /// **'Use headphones to compare with the original.'**
  String get practiceNotice;

  /// No description provided for @practiceSaved.
  ///
  /// In en, this message translates to:
  /// **'Practice saved on this computer.'**
  String get practiceSaved;

  /// No description provided for @practiceEmpty.
  ///
  /// In en, this message translates to:
  /// **'Write your expression first, or record your own voice.'**
  String get practiceEmpty;

  /// No description provided for @recentPractice.
  ///
  /// In en, this message translates to:
  /// **'Recently saved practice'**
  String get recentPractice;

  /// No description provided for @clipPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice for this clip'**
  String get clipPractice;

  /// No description provided for @playRecording.
  ///
  /// In en, this message translates to:
  /// **'Play your recording'**
  String get playRecording;

  /// No description provided for @showAllSaved.
  ///
  /// In en, this message translates to:
  /// **'Show all saved'**
  String get showAllSaved;

  /// No description provided for @reviewEmptyNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review yet'**
  String get reviewEmptyNone;

  /// No description provided for @reviewEmptyDone.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get reviewEmptyDone;

  /// No description provided for @recallPrompt.
  ///
  /// In en, this message translates to:
  /// **'Recall the expression you saved from this clip.'**
  String get recallPrompt;

  /// No description provided for @nextReview.
  ///
  /// In en, this message translates to:
  /// **'Next review: {date}'**
  String nextReview(String date);

  /// No description provided for @reveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get reveal;

  /// No description provided for @recallAgain.
  ///
  /// In en, this message translates to:
  /// **'Forgot'**
  String get recallAgain;

  /// No description provided for @recallHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get recallHard;

  /// No description provided for @recallGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get recallGood;

  /// No description provided for @recallEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get recallEasy;

  /// No description provided for @backToScene.
  ///
  /// In en, this message translates to:
  /// **'Back to the scene'**
  String get backToScene;

  /// No description provided for @clipMissing.
  ///
  /// In en, this message translates to:
  /// **'The original clip is not in the current course version. Your saved expression and practice are kept.'**
  String get clipMissing;

  /// No description provided for @speakQuestion.
  ///
  /// In en, this message translates to:
  /// **'What is one thing you are working on right now?'**
  String get speakQuestion;

  /// No description provided for @speakHelp.
  ///
  /// In en, this message translates to:
  /// **'Talk about training, games, study or something small from today — or switch topics entirely.'**
  String get speakHelp;

  /// No description provided for @appVersionLine.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersionLine(String version);

  /// No description provided for @uiLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get uiLanguage;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @learningLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language you are learning'**
  String get learningLanguage;

  /// No description provided for @nativeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Your language (for translations)'**
  String get nativeLanguage;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @exportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Export practice as Markdown'**
  String get exportMarkdown;

  /// No description provided for @exportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export practice text'**
  String get exportDialogTitle;

  /// No description provided for @exported.
  ///
  /// In en, this message translates to:
  /// **'Text exported. Recordings stay in the local data folder.'**
  String get exported;

  /// No description provided for @copyDataFolder.
  ///
  /// In en, this message translates to:
  /// **'Copy data folder path'**
  String get copyDataFolder;

  /// No description provided for @dataFolderCopied.
  ///
  /// In en, this message translates to:
  /// **'Data folder path copied.'**
  String get dataFolderCopied;

  /// No description provided for @openInFinder.
  ///
  /// In en, this message translates to:
  /// **'Open in Finder'**
  String get openInFinder;

  /// No description provided for @finderFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot open Finder: {error}'**
  String finderFailed(String error);

  /// No description provided for @openSourceBody.
  ///
  /// In en, this message translates to:
  /// **'Open source under AGPL-3.0. Commercial licences are available from the author.'**
  String get openSourceBody;

  /// No description provided for @viewLicenses.
  ///
  /// In en, this message translates to:
  /// **'View full open-source licences'**
  String get viewLicenses;

  /// No description provided for @legalese.
  ///
  /// In en, this message translates to:
  /// **'Copyright 2026 eeeease and Tinglang contributors.'**
  String get legalese;

  /// No description provided for @exportHeading.
  ///
  /// In en, this message translates to:
  /// **'# TingLang — My English practice'**
  String get exportHeading;

  /// No description provided for @exportedAt.
  ///
  /// In en, this message translates to:
  /// **'Exported: {date}'**
  String exportedAt(String date);

  /// No description provided for @exportTextOnly.
  ///
  /// In en, this message translates to:
  /// **'This export contains text only. Original recordings and media stay in the app data folder.'**
  String get exportTextOnly;

  /// No description provided for @exportAudioOnly.
  ///
  /// In en, this message translates to:
  /// **'_Audio-only practice._'**
  String get exportAudioOnly;

  /// No description provided for @exportRecordingSaved.
  ///
  /// In en, this message translates to:
  /// **'Recording: saved locally'**
  String get exportRecordingSaved;

  /// No description provided for @exportRecordingNone.
  ///
  /// In en, this message translates to:
  /// **'Recording: none'**
  String get exportRecordingNone;

  /// No description provided for @exportExpressions.
  ///
  /// In en, this message translates to:
  /// **'## Expressions'**
  String get exportExpressions;

  /// No description provided for @liveSourceSystem.
  ///
  /// In en, this message translates to:
  /// **'System audio'**
  String get liveSourceSystem;

  /// No description provided for @liveSourceMic.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get liveSourceMic;

  /// No description provided for @liveStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get liveStop;

  /// No description provided for @liveStopping.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get liveStopping;

  /// No description provided for @liveLanguagePair.
  ///
  /// In en, this message translates to:
  /// **'{source} → {target}'**
  String liveLanguagePair(String source, String target);

  /// No description provided for @liveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live captions are not available on this Mac yet: {reason}'**
  String liveUnavailable(String reason);

  /// No description provided for @liveNeedSpeechModel.
  ///
  /// In en, this message translates to:
  /// **'Recognising {language} needs a speech model download first.'**
  String liveNeedSpeechModel(String language);

  /// No description provided for @liveNeedTranslationPack.
  ///
  /// In en, this message translates to:
  /// **'Translating {pair} needs a language pack download first.'**
  String liveNeedTranslationPack(String pair);

  /// No description provided for @liveDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get liveDownload;

  /// No description provided for @liveIssueSilentTap.
  ///
  /// In en, this message translates to:
  /// **'System audio arrived silent, so TingLang switched to Screen Recording capture. If macOS asks, allow TingLang in System Settings → Privacy & Security.'**
  String get liveIssueSilentTap;

  /// No description provided for @liveIssueFallback.
  ///
  /// In en, this message translates to:
  /// **'Capturing through Screen Recording.'**
  String get liveIssueFallback;

  /// No description provided for @liveTranslating.
  ///
  /// In en, this message translates to:
  /// **'Translating…'**
  String get liveTranslating;

  /// No description provided for @liveSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Captions · {date}'**
  String liveSessionTitle(String date);

  /// No description provided for @liveSessionInterrupted.
  ///
  /// In en, this message translates to:
  /// **'interrupted'**
  String get liveSessionInterrupted;

  /// No description provided for @liveSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search all captions'**
  String get liveSearchHint;

  /// No description provided for @liveNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No captions match.'**
  String get liveNoMatches;

  /// No description provided for @liveExport.
  ///
  /// In en, this message translates to:
  /// **'Export…'**
  String get liveExport;

  /// No description provided for @liveDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get liveDelete;

  /// No description provided for @liveDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this session and its captions?'**
  String get liveDeleteConfirm;

  /// No description provided for @liveExportBilingual.
  ///
  /// In en, this message translates to:
  /// **'Bilingual'**
  String get liveExportBilingual;

  /// No description provided for @liveExportSource.
  ///
  /// In en, this message translates to:
  /// **'Original only'**
  String get liveExportSource;

  /// No description provided for @liveExportTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation only'**
  String get liveExportTranslation;

  /// No description provided for @liveTimesNote.
  ///
  /// In en, this message translates to:
  /// **'Times count from the start of the captions.'**
  String get liveTimesNote;

  /// No description provided for @liveSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save captions: {error}'**
  String liveSaveFailed(String error);

  /// No description provided for @sessionTranscript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get sessionTranscript;

  /// No description provided for @sessionDictation.
  ///
  /// In en, this message translates to:
  /// **'Dictation'**
  String get sessionDictation;

  /// No description provided for @sessionNoMedia.
  ///
  /// In en, this message translates to:
  /// **'No audio was saved with this session, so it can\'t be played. To keep audio next time, turn on “Save system audio with captions” in Settings.'**
  String get sessionNoMedia;

  /// No description provided for @playerBack5.
  ///
  /// In en, this message translates to:
  /// **'Back 5 seconds'**
  String get playerBack5;

  /// No description provided for @playerForward5.
  ///
  /// In en, this message translates to:
  /// **'Forward 5 seconds'**
  String get playerForward5;

  /// No description provided for @playerSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get playerSpeed;

  /// No description provided for @playerVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get playerVolume;

  /// No description provided for @playerMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get playerMute;

  /// No description provided for @playerUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get playerUnmute;

  /// No description provided for @playerSetA.
  ///
  /// In en, this message translates to:
  /// **'Set A'**
  String get playerSetA;

  /// No description provided for @playerSetB.
  ///
  /// In en, this message translates to:
  /// **'Set B'**
  String get playerSetB;

  /// No description provided for @playerClearLoop.
  ///
  /// In en, this message translates to:
  /// **'Clear loop'**
  String get playerClearLoop;

  /// No description provided for @playerLoopSentence.
  ///
  /// In en, this message translates to:
  /// **'Loop this sentence'**
  String get playerLoopSentence;

  /// No description provided for @dictationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Listen and type what you hear.'**
  String get dictationPrompt;

  /// No description provided for @dictationPlay.
  ///
  /// In en, this message translates to:
  /// **'Play sentence'**
  String get dictationPlay;

  /// No description provided for @dictationHint.
  ///
  /// In en, this message translates to:
  /// **'Type the sentence… (⌘↩ checks, ⌘R replays)'**
  String get dictationHint;

  /// No description provided for @dictationCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get dictationCheck;

  /// No description provided for @dictationPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get dictationPrevious;

  /// No description provided for @dictationNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get dictationNext;

  /// No description provided for @dictationReveal.
  ///
  /// In en, this message translates to:
  /// **'Show answer'**
  String get dictationReveal;

  /// No description provided for @dictationCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get dictationCorrect;

  /// No description provided for @dictationClose.
  ///
  /// In en, this message translates to:
  /// **'Almost'**
  String get dictationClose;

  /// No description provided for @dictationIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get dictationIncorrect;

  /// No description provided for @dictationProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} sentences correct'**
  String dictationProgress(int done, int total);

  /// No description provided for @dictationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sentences to practise in this session yet.'**
  String get dictationEmpty;

  /// No description provided for @importMedia.
  ///
  /// In en, this message translates to:
  /// **'Import audio or video…'**
  String get importMedia;

  /// No description provided for @importTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing · {percent}%'**
  String importTranscribing(String percent);

  /// No description provided for @importCopying.
  ///
  /// In en, this message translates to:
  /// **'Copying…'**
  String get importCopying;

  /// No description provided for @importCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get importCancel;

  /// No description provided for @recallInterval.
  ///
  /// In en, this message translates to:
  /// **'{label} · {days} d'**
  String recallInterval(String label, int days);

  /// No description provided for @stepQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get stepQuiz;

  /// No description provided for @youtubeBlocked.
  ///
  /// In en, this message translates to:
  /// **'This video can\'t be played inside TingLang (YouTube error {code}).'**
  String youtubeBlocked(int code);

  /// No description provided for @openOnYouTube.
  ///
  /// In en, this message translates to:
  /// **'Open on YouTube'**
  String get openOnYouTube;

  /// No description provided for @blindInlineHint.
  ///
  /// In en, this message translates to:
  /// **'Type each missing word or phrase in place, then check. Colours: word, phrase, sentence.'**
  String get blindInlineHint;

  /// No description provided for @blindScore.
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct'**
  String blindScore(int correct, int total);

  /// No description provided for @blindAddMissed.
  ///
  /// In en, this message translates to:
  /// **'Add missed items to review'**
  String get blindAddMissed;

  /// No description provided for @blindAllCorrect.
  ///
  /// In en, this message translates to:
  /// **'All correct. Step marked done.'**
  String get blindAllCorrect;

  /// No description provided for @shadowReason.
  ///
  /// In en, this message translates to:
  /// **'Why: {reason}'**
  String shadowReason(String reason);

  /// No description provided for @retellTryToUse.
  ///
  /// In en, this message translates to:
  /// **'Try to use'**
  String get retellTryToUse;

  /// No description provided for @quizIntro.
  ///
  /// In en, this message translates to:
  /// **'Recall each item from its meaning, or fill it back into the sentence where you heard it. Misses go to your review deck.'**
  String get quizIntro;

  /// No description provided for @quizRecall.
  ///
  /// In en, this message translates to:
  /// **'Say it in English'**
  String get quizRecall;

  /// No description provided for @quizCloze.
  ///
  /// In en, this message translates to:
  /// **'Fill the gap'**
  String get quizCloze;

  /// No description provided for @quizCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get quizCheck;

  /// No description provided for @quizNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get quizNext;

  /// No description provided for @quizDone.
  ///
  /// In en, this message translates to:
  /// **'Quiz finished: {correct} of {total}.'**
  String quizDone(int correct, int total);

  /// No description provided for @quizRestart.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get quizRestart;

  /// No description provided for @quizEmpty.
  ///
  /// In en, this message translates to:
  /// **'This scene has no items to quiz.'**
  String get quizEmpty;

  /// No description provided for @addedToReview.
  ///
  /// In en, this message translates to:
  /// **'Added to review'**
  String get addedToReview;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @makeCourse.
  ///
  /// In en, this message translates to:
  /// **'Make course'**
  String get makeCourse;

  /// No description provided for @makeCourseBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic course'**
  String get makeCourseBasic;

  /// No description provided for @makeCourseBasicBody.
  ///
  /// In en, this message translates to:
  /// **'Offline: words above your level, phrases and sentences, with blind listening and shadowing.'**
  String get makeCourseBasicBody;

  /// No description provided for @makeCourseAi.
  ///
  /// In en, this message translates to:
  /// **'AI course'**
  String get makeCourseAi;

  /// No description provided for @makeCourseAiBody.
  ///
  /// In en, this message translates to:
  /// **'Your AI service writes explanations, examples, memory aids and a retelling outline.'**
  String get makeCourseAiBody;

  /// No description provided for @makeCourseNoProvider.
  ///
  /// In en, this message translates to:
  /// **'Add an AI provider in Settings to use this.'**
  String get makeCourseNoProvider;

  /// No description provided for @makeCourseProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get makeCourseProvider;

  /// No description provided for @makeCourseConsent.
  ///
  /// In en, this message translates to:
  /// **'Send this transcript\'s text to {host}'**
  String makeCourseConsent(String host);

  /// No description provided for @makeCourseReplace.
  ///
  /// In en, this message translates to:
  /// **'A course from this session already exists. Making it again replaces its content; your progress and review cards are kept.'**
  String get makeCourseReplace;

  /// No description provided for @makeCourseStart.
  ///
  /// In en, this message translates to:
  /// **'Make course'**
  String get makeCourseStart;

  /// No description provided for @makeCourseReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the transcript…'**
  String get makeCourseReading;

  /// No description provided for @makeCourseSelecting.
  ///
  /// In en, this message translates to:
  /// **'Choosing clips…'**
  String get makeCourseSelecting;

  /// No description provided for @makeCoursePlanning.
  ///
  /// In en, this message translates to:
  /// **'Writing clip {done} of {total}…'**
  String makeCoursePlanning(int done, int total);

  /// No description provided for @makeCourseCompiling.
  ///
  /// In en, this message translates to:
  /// **'Checking and saving the course…'**
  String get makeCourseCompiling;

  /// No description provided for @makeCourseDone.
  ///
  /// In en, this message translates to:
  /// **'Done: {clips} clips are ready.'**
  String makeCourseDone(int clips);

  /// No description provided for @makeCourseFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not make the course: {error}'**
  String makeCourseFailed(String error);

  /// No description provided for @makeCourseRequests.
  ///
  /// In en, this message translates to:
  /// **'{count} AI requests'**
  String makeCourseRequests(int count);

  /// No description provided for @makeCourseFallbacks.
  ///
  /// In en, this message translates to:
  /// **'{count} clips used Basic content'**
  String makeCourseFallbacks(int count);

  /// No description provided for @makeCourseOpen.
  ///
  /// In en, this message translates to:
  /// **'Open course'**
  String get makeCourseOpen;

  /// No description provided for @providersTitle.
  ///
  /// In en, this message translates to:
  /// **'AI providers'**
  String get providersTitle;

  /// No description provided for @providersBody.
  ///
  /// In en, this message translates to:
  /// **'Used for AI courses: any OpenAI-compatible service with your own key, or a model on this Mac with Ollama or LM Studio.'**
  String get providersBody;

  /// No description provided for @providersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No providers yet. Basic courses work without one.'**
  String get providersEmpty;

  /// No description provided for @providersPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Keys are kept in the macOS Keychain.'**
  String get providersPrivacy;

  /// No description provided for @providerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add provider'**
  String get providerAdd;

  /// No description provided for @providerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit provider'**
  String get providerEdit;

  /// No description provided for @providerPreset.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get providerPreset;

  /// No description provided for @providerCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom (OpenAI-compatible)'**
  String get providerCustom;

  /// No description provided for @providerName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get providerName;

  /// No description provided for @providerBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get providerBaseUrl;

  /// No description provided for @providerModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get providerModel;

  /// No description provided for @providerModelPick.
  ///
  /// In en, this message translates to:
  /// **'Choose a model'**
  String get providerModelPick;

  /// No description provided for @providerApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get providerApiKey;

  /// No description provided for @providerApiKeyOptional.
  ///
  /// In en, this message translates to:
  /// **'API key (optional)'**
  String get providerApiKeyOptional;

  /// No description provided for @providerKeyKeychain.
  ///
  /// In en, this message translates to:
  /// **'Saved in the Keychain'**
  String get providerKeyKeychain;

  /// No description provided for @providerKeyKeep.
  ///
  /// In en, this message translates to:
  /// **'A key is saved. Leave empty to keep it.'**
  String get providerKeyKeep;

  /// No description provided for @providerKeySaved.
  ///
  /// In en, this message translates to:
  /// **'key saved'**
  String get providerKeySaved;

  /// No description provided for @providerKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'no key'**
  String get providerKeyMissing;

  /// No description provided for @providerTest.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get providerTest;

  /// No description provided for @providerTestOk.
  ///
  /// In en, this message translates to:
  /// **'Connected · {count} models available'**
  String providerTestOk(int count);

  /// No description provided for @providerTestUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'The key was rejected.'**
  String get providerTestUnauthorized;

  /// No description provided for @providerCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get providerCloud;

  /// No description provided for @providerLocal.
  ///
  /// In en, this message translates to:
  /// **'On this Mac'**
  String get providerLocal;

  /// No description provided for @providerDefault.
  ///
  /// In en, this message translates to:
  /// **'Use for course generation'**
  String get providerDefault;

  /// No description provided for @providerDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String providerDeleteTitle(String name);

  /// No description provided for @providerDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its key is removed from the Keychain. Courses made with it stay.'**
  String get providerDeleteBody;

  /// No description provided for @providerUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a base URL starting with http:// or https://'**
  String get providerUrlInvalid;

  /// No description provided for @providerModelRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a model name.'**
  String get providerModelRequired;

  /// No description provided for @providerModelContext.
  ///
  /// In en, this message translates to:
  /// **'{tokens} context'**
  String providerModelContext(String tokens);

  /// No description provided for @providerModelPrice.
  ///
  /// In en, this message translates to:
  /// **'{input} in / {output} out per 1M tokens'**
  String providerModelPrice(String input, String output);

  /// No description provided for @providerModelLocal.
  ///
  /// In en, this message translates to:
  /// **'Runs on this Mac: no per-token cost.'**
  String get providerModelLocal;

  /// No description provided for @providerModelUnlisted.
  ///
  /// In en, this message translates to:
  /// **'Not in the bundled catalog: price unknown.'**
  String get providerModelUnlisted;

  /// No description provided for @providerLitellmHint.
  ///
  /// In en, this message translates to:
  /// **'Runs through a LiteLLM Proxy you start yourself.'**
  String get providerLitellmHint;

  /// No description provided for @makeCourseEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimate: {calls} requests · ~{input} in / ~{output} out tokens · {cost}'**
  String makeCourseEstimate(int calls, String input, String output, String cost);

  /// No description provided for @makeCourseAbout.
  ///
  /// In en, this message translates to:
  /// **'about {usd}'**
  String makeCourseAbout(String usd);

  /// No description provided for @makeCourseLocalFree.
  ///
  /// In en, this message translates to:
  /// **'free (runs on this Mac)'**
  String get makeCourseLocalFree;

  /// No description provided for @makeCourseNoPrice.
  ///
  /// In en, this message translates to:
  /// **'no price data'**
  String get makeCourseNoPrice;

  /// No description provided for @makeCourseTokens.
  ///
  /// In en, this message translates to:
  /// **'{input} in / {output} out tokens'**
  String makeCourseTokens(String input, String output);

  /// No description provided for @errorFileDialog.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the file dialog. Quit and reopen the app, then try again.'**
  String get errorFileDialog;

  /// No description provided for @errorFileMissing.
  ///
  /// In en, this message translates to:
  /// **'That file is no longer available.'**
  String get errorFileMissing;

  /// No description provided for @errorUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'.{ext} files aren\'t supported. Try MP3, M4A, WAV, MP4 or MOV.'**
  String errorUnsupportedFormat(String ext);

  /// No description provided for @errorNoAudio.
  ///
  /// In en, this message translates to:
  /// **'This file has no sound to transcribe.'**
  String get errorNoAudio;

  /// No description provided for @errorNoTranscriber.
  ///
  /// In en, this message translates to:
  /// **'No speech model can transcribe files on this Mac yet. Choose one in Settings → Speech recognition.'**
  String get errorNoTranscriber;

  /// No description provided for @errorWithDetail.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {detail}'**
  String errorWithDetail(String detail);

  /// No description provided for @importAndTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Import and transcribe'**
  String get importAndTranscribe;

  /// No description provided for @importCancelled.
  ///
  /// In en, this message translates to:
  /// **'Import cancelled.'**
  String get importCancelled;

  /// No description provided for @panelStart.
  ///
  /// In en, this message translates to:
  /// **'Start live captions'**
  String get panelStart;

  /// No description provided for @panelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live captions can\'t start on this Mac right now'**
  String get panelUnavailable;

  /// No description provided for @panelHistory.
  ///
  /// In en, this message translates to:
  /// **'History and review'**
  String get panelHistory;

  /// No description provided for @panelMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get panelMore;

  /// No description provided for @panelAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance…'**
  String get panelAppearance;

  /// No description provided for @panelOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open main window'**
  String get panelOpenApp;

  /// No description provided for @panelSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings…'**
  String get panelSettings;

  /// No description provided for @panelHide.
  ///
  /// In en, this message translates to:
  /// **'Hide floating window'**
  String get panelHide;

  /// No description provided for @panelQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get panelQuit;

  /// No description provided for @panelListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get panelListening;

  /// No description provided for @panelWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for speech…'**
  String get panelWaiting;

  /// No description provided for @panelView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get panelView;

  /// No description provided for @panelMakeCourse.
  ///
  /// In en, this message translates to:
  /// **'Make course'**
  String get panelMakeCourse;

  /// No description provided for @panelDropHint.
  ///
  /// In en, this message translates to:
  /// **'Drop to import and transcribe'**
  String get panelDropHint;

  /// No description provided for @panelNewRecordings.
  ///
  /// In en, this message translates to:
  /// **'{count} new recordings'**
  String panelNewRecordings(String count);

  /// No description provided for @panelDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get panelDisplay;

  /// No description provided for @panelModeCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get panelModeCard;

  /// No description provided for @panelModeText.
  ///
  /// In en, this message translates to:
  /// **'Text only'**
  String get panelModeText;

  /// No description provided for @panelBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get panelBackground;

  /// No description provided for @panelBgGlass.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get panelBgGlass;

  /// No description provided for @panelBgSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get panelBgSolid;

  /// No description provided for @panelBgClear.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get panelBgClear;

  /// No description provided for @panelOpacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get panelOpacity;

  /// No description provided for @panelBackgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background colour'**
  String get panelBackgroundColor;

  /// No description provided for @panelTextColor.
  ///
  /// In en, this message translates to:
  /// **'Text colour'**
  String get panelTextColor;

  /// No description provided for @panelTranslationColor.
  ///
  /// In en, this message translates to:
  /// **'Translation colour'**
  String get panelTranslationColor;

  /// No description provided for @panelFontSize.
  ///
  /// In en, this message translates to:
  /// **'Size and weight'**
  String get panelFontSize;

  /// No description provided for @panelWeightRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get panelWeightRegular;

  /// No description provided for @panelWeightMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get panelWeightMedium;

  /// No description provided for @panelWeightBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get panelWeightBold;

  /// No description provided for @panelLines.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get panelLines;

  /// No description provided for @panelShowTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get panelShowTranslation;

  /// No description provided for @panelOutline.
  ///
  /// In en, this message translates to:
  /// **'Outline text'**
  String get panelOutline;

  /// No description provided for @panelCenter.
  ///
  /// In en, this message translates to:
  /// **'Centre lines'**
  String get panelCenter;

  /// No description provided for @panelLock.
  ///
  /// In en, this message translates to:
  /// **'Lock and click through'**
  String get panelLock;

  /// No description provided for @panelUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get panelUnlock;

  /// No description provided for @panelResetPosition.
  ///
  /// In en, this message translates to:
  /// **'Reset position'**
  String get panelResetPosition;

  /// No description provided for @panelLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get panelLayout;

  /// No description provided for @panelLayoutStacked.
  ///
  /// In en, this message translates to:
  /// **'Stacked'**
  String get panelLayoutStacked;

  /// No description provided for @panelLayoutSideBySide.
  ///
  /// In en, this message translates to:
  /// **'Side by side'**
  String get panelLayoutSideBySide;

  /// No description provided for @panelLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked · clicks pass through'**
  String get panelLocked;

  /// No description provided for @panelLockToggle.
  ///
  /// In en, this message translates to:
  /// **'Lock while captioning (clicks pass through)'**
  String get panelLockToggle;

  /// No description provided for @panelJumpToLatest.
  ///
  /// In en, this message translates to:
  /// **'Back to latest'**
  String get panelJumpToLatest;

  /// No description provided for @panelNewLines.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String panelNewLines(String count);

  /// No description provided for @panelDockToggle.
  ///
  /// In en, this message translates to:
  /// **'Start or stop captions'**
  String get panelDockToggle;

  /// No description provided for @panelDockShow.
  ///
  /// In en, this message translates to:
  /// **'Show floating window'**
  String get panelDockShow;

  /// No description provided for @panelDockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock captions'**
  String get panelDockUnlock;

  /// No description provided for @panelPreparing.
  ///
  /// In en, this message translates to:
  /// **'Getting ready…'**
  String get panelPreparing;

  /// No description provided for @panelDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading the speech model…'**
  String get panelDownloading;

  /// No description provided for @panelSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get panelSaved;

  /// No description provided for @panelSummary.
  ///
  /// In en, this message translates to:
  /// **'{duration} · {words} words'**
  String panelSummary(String duration, String words);

  /// No description provided for @panelFailed.
  ///
  /// In en, this message translates to:
  /// **'Captions didn\'t start: {detail}'**
  String panelFailed(String detail);

  /// No description provided for @panelImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing {count} file(s). Progress shows in History.'**
  String panelImporting(String count);

  /// No description provided for @panelRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get panelRetry;

  /// No description provided for @navRecords.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navRecords;

  /// No description provided for @tabCaptions.
  ///
  /// In en, this message translates to:
  /// **'Captions'**
  String get tabCaptions;

  /// No description provided for @tabReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get tabReview;

  /// No description provided for @tabSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get tabSpeak;

  /// No description provided for @tabMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get tabMine;

  /// No description provided for @tabDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get tabDiscover;

  /// No description provided for @tabShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get tabShared;

  /// No description provided for @importAudio.
  ///
  /// In en, this message translates to:
  /// **'Import audio'**
  String get importAudio;

  /// No description provided for @recordsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing captured yet'**
  String get recordsEmptyTitle;

  /// No description provided for @recordsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start live captions from the floating panel, or import a recording to transcribe it for close listening.'**
  String get recordsEmptyBody;

  /// No description provided for @dayToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dayToday;

  /// No description provided for @dayYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dayYesterday;

  /// No description provided for @liveRunning.
  ///
  /// In en, this message translates to:
  /// **'Live captions are running'**
  String get liveRunning;

  /// No description provided for @originFile.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get originFile;

  /// No description provided for @originShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get originShared;

  /// No description provided for @sessionFailed.
  ///
  /// In en, this message translates to:
  /// **'transcription failed'**
  String get sessionFailed;

  /// No description provided for @reviewEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Save useful expressions while studying a course; they come back here when they are due.'**
  String get reviewEmptyHint;

  /// No description provided for @reviewDoneHint.
  ///
  /// In en, this message translates to:
  /// **'The next expressions come back when they are due.'**
  String get reviewDoneHint;

  /// No description provided for @sharedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Community sharing is coming'**
  String get sharedEmptyTitle;

  /// No description provided for @sharedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Until then, import .tinglang files that friends export for you.'**
  String get sharedEmptyBody;

  /// No description provided for @importShared.
  ///
  /// In en, this message translates to:
  /// **'Import shared file…'**
  String get importShared;

  /// No description provided for @exportShared.
  ///
  /// In en, this message translates to:
  /// **'Export share file…'**
  String get exportShared;

  /// No description provided for @sharedImported.
  ///
  /// In en, this message translates to:
  /// **'Imported.'**
  String get sharedImported;

  /// No description provided for @sharedExported.
  ///
  /// In en, this message translates to:
  /// **'Share file saved.'**
  String get sharedExported;

  /// No description provided for @shareNotPackage.
  ///
  /// In en, this message translates to:
  /// **'This is not a TingLang share file.'**
  String get shareNotPackage;

  /// No description provided for @shareNewerVersion.
  ///
  /// In en, this message translates to:
  /// **'This file comes from a newer version of TingLang. Update the app and try again.'**
  String get shareNewerVersion;

  /// No description provided for @shareIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The share file is incomplete. Ask for it to be exported again.'**
  String get shareIncomplete;

  /// No description provided for @shareTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The share file is too large to import.'**
  String get shareTooLarge;

  /// No description provided for @shareUnsupportedMedia.
  ///
  /// In en, this message translates to:
  /// **'The audio or video in this file is not in a supported format.'**
  String get shareUnsupportedMedia;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsCaptions.
  ///
  /// In en, this message translates to:
  /// **'Live captions'**
  String get settingsCaptions;

  /// No description provided for @settingsShowPanel.
  ///
  /// In en, this message translates to:
  /// **'Show the floating panel'**
  String get settingsShowPanel;

  /// No description provided for @settingsPanelLayout.
  ///
  /// In en, this message translates to:
  /// **'Floating panel layout'**
  String get settingsPanelLayout;

  /// No description provided for @settingsPanelScrollback.
  ///
  /// In en, this message translates to:
  /// **'Lines you can scroll back on the panel'**
  String get settingsPanelScrollback;

  /// No description provided for @settingsScrollbackLines.
  ///
  /// In en, this message translates to:
  /// **'{count} lines'**
  String settingsScrollbackLines(String count);

  /// No description provided for @settingsKeepSystemAudio.
  ///
  /// In en, this message translates to:
  /// **'Save system audio with captions'**
  String get settingsKeepSystemAudio;

  /// No description provided for @settingsKeepSystemAudioHelp.
  ///
  /// In en, this message translates to:
  /// **'Lets you replay what was said. Only for material you may record.'**
  String get settingsKeepSystemAudioHelp;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Everything lives in this folder; back it up to keep your history.'**
  String get settingsBackupHint;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @voiceMemos.
  ///
  /// In en, this message translates to:
  /// **'Voice Memos'**
  String get voiceMemos;

  /// No description provided for @voiceMemosImport.
  ///
  /// In en, this message translates to:
  /// **'Import and transcribe ({count})'**
  String voiceMemosImport(String count);

  /// No description provided for @voiceMemoImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get voiceMemoImported;

  /// No description provided for @voiceMemoUntitled.
  ///
  /// In en, this message translates to:
  /// **'Voice memo · {date}'**
  String voiceMemoUntitled(String date);

  /// No description provided for @voiceMemosAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Let TingLang read Voice Memos'**
  String get voiceMemosAccessTitle;

  /// No description provided for @voiceMemosAccessBody.
  ///
  /// In en, this message translates to:
  /// **'macOS keeps Voice Memos in a protected folder. Turn on TingLang in System Settings › Privacy & Security › Full Disk Access; macOS may ask you to quit and reopen it.'**
  String get voiceMemosAccessBody;

  /// No description provided for @voiceMemosOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open System Settings'**
  String get voiceMemosOpenSettings;

  /// No description provided for @voiceMemosCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get voiceMemosCheckAgain;

  /// No description provided for @voiceMemosNoLibrary.
  ///
  /// In en, this message translates to:
  /// **'No Voice Memos on this Mac yet. Turn on Voice Memos in iCloud on your iPhone and this Mac, and your recordings appear here.'**
  String get voiceMemosNoLibrary;

  /// No description provided for @voiceMemosUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the Voice Memos library. Open the Voice Memos app once, then check again.'**
  String get voiceMemosUnreadable;

  /// No description provided for @voiceMemosEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recordings on this Mac yet.'**
  String get voiceMemosEmpty;

  /// No description provided for @voiceMemosNewToday.
  ///
  /// In en, this message translates to:
  /// **'{count} new voice memos today'**
  String voiceMemosNewToday(String count);

  /// No description provided for @voiceMemosImportShort.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get voiceMemosImportShort;

  /// No description provided for @originVoiceMemo.
  ///
  /// In en, this message translates to:
  /// **'Voice Memos'**
  String get originVoiceMemo;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @accountSignedOutBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your plan and usage. Buying and managing happen on the website; everything on this Mac works without an account.'**
  String get accountSignedOutBody;

  /// No description provided for @accountSignInHost.
  ///
  /// In en, this message translates to:
  /// **'Signing in opens {host} in your browser. Nothing is sent before you sign in.'**
  String accountSignInHost(String host);

  /// No description provided for @accountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in in browser'**
  String get accountSignIn;

  /// No description provided for @accountSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the browser…'**
  String get accountSigningIn;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @navSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get navSignIn;

  /// No description provided for @planFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get planFree;

  /// No description provided for @accountUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get accountUpgrade;

  /// No description provided for @cloudOfficialSoon.
  ///
  /// In en, this message translates to:
  /// **'TingLang official (coming soon)'**
  String get cloudOfficialSoon;

  /// No description provided for @accountRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get accountRefresh;

  /// No description provided for @accountManage.
  ///
  /// In en, this message translates to:
  /// **'Manage on the website'**
  String get accountManage;

  /// No description provided for @accountPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get accountPlans;

  /// No description provided for @accountPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan: {plan}'**
  String accountPlan(String plan);

  /// No description provided for @accountStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get accountStatusActive;

  /// No description provided for @accountStatusTrialing.
  ///
  /// In en, this message translates to:
  /// **'Trial'**
  String get accountStatusTrialing;

  /// No description provided for @accountStatusPastDue.
  ///
  /// In en, this message translates to:
  /// **'Payment due'**
  String get accountStatusPastDue;

  /// No description provided for @accountStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get accountStatusCanceled;

  /// No description provided for @accountStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get accountStatusExpired;

  /// No description provided for @accountStatusNone.
  ///
  /// In en, this message translates to:
  /// **'No plan'**
  String get accountStatusNone;

  /// No description provided for @accountStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown status'**
  String get accountStatusUnknown;

  /// No description provided for @accountServices.
  ///
  /// In en, this message translates to:
  /// **'Cloud services'**
  String get accountServices;

  /// No description provided for @accountNoServices.
  ///
  /// In en, this message translates to:
  /// **'TingLang\'s own cloud services (transcription, AI courses) are coming soon.'**
  String get accountNoServices;

  /// No description provided for @cloudServiceTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Cloud transcription'**
  String get cloudServiceTranscribe;

  /// No description provided for @cloudServiceTranslate.
  ///
  /// In en, this message translates to:
  /// **'Cloud translation'**
  String get cloudServiceTranslate;

  /// No description provided for @cloudServiceLlm.
  ///
  /// In en, this message translates to:
  /// **'AI courses without your own key'**
  String get cloudServiceLlm;

  /// No description provided for @cloudServiceIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get cloudServiceIncluded;

  /// No description provided for @cloudServiceNotInPlan.
  ///
  /// In en, this message translates to:
  /// **'Not in your plan'**
  String get cloudServiceNotInPlan;

  /// No description provided for @quotaMinutes.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} minutes used'**
  String quotaMinutes(String used, String limit);

  /// No description provided for @quotaCredits.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} credits used'**
  String quotaCredits(String used, String limit);

  /// No description provided for @quotaOther.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} used'**
  String quotaOther(String used, String limit);

  /// No description provided for @quotaResets.
  ///
  /// In en, this message translates to:
  /// **'resets {date}'**
  String quotaResets(String date);

  /// No description provided for @accountOffline.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach {host}. Showing the plan as of {time}.'**
  String accountOffline(String host, String time);

  /// No description provided for @accountOfflineUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach {host}, so the plan cannot be confirmed right now. Features on this Mac are not affected.'**
  String accountOfflineUnconfirmed(String host);

  /// No description provided for @cloudErrorUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach {host}. Check the address and your connection; features on this Mac keep working.'**
  String cloudErrorUnreachable(String host);

  /// No description provided for @cloudErrorNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'This server does not offer accounts.'**
  String get cloudErrorNoAccounts;

  /// No description provided for @cloudErrorNoBrowser.
  ///
  /// In en, this message translates to:
  /// **'Signing in through the browser is not available on this system.'**
  String get cloudErrorNoBrowser;

  /// No description provided for @cloudErrorNoKeychain.
  ///
  /// In en, this message translates to:
  /// **'There is no secure storage for the sign-in on this system.'**
  String get cloudErrorNoKeychain;

  /// No description provided for @cloudErrorCanceled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was canceled.'**
  String get cloudErrorCanceled;

  /// No description provided for @cloudErrorSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign-in did not complete. Try again.'**
  String get cloudErrorSignIn;

  /// No description provided for @cloudErrorSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Sign in again.'**
  String get cloudErrorSessionEnded;

  /// No description provided for @cloudErrorClientTooOld.
  ///
  /// In en, this message translates to:
  /// **'This server needs a newer version of TingLang.'**
  String get cloudErrorClientTooOld;

  /// No description provided for @cloudErrorEntitlement.
  ///
  /// In en, this message translates to:
  /// **'This needs a plan that includes it.'**
  String get cloudErrorEntitlement;

  /// No description provided for @cloudErrorQuota.
  ///
  /// In en, this message translates to:
  /// **'The quota for this period is used up.'**
  String get cloudErrorQuota;

  /// No description provided for @cloudErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Try again in a moment.'**
  String get cloudErrorRateLimited;

  /// No description provided for @cloudErrorFeatureDisabled.
  ///
  /// In en, this message translates to:
  /// **'This server does not offer that.'**
  String get cloudErrorFeatureDisabled;

  /// No description provided for @cloudErrorMaintenance.
  ///
  /// In en, this message translates to:
  /// **'The server is under maintenance. Try again later.'**
  String get cloudErrorMaintenance;

  /// No description provided for @cloudErrorServer.
  ///
  /// In en, this message translates to:
  /// **'The server could not handle the request ({code}).'**
  String cloudErrorServer(String code);

  /// No description provided for @cloudErrorBadResponse.
  ///
  /// In en, this message translates to:
  /// **'The server sent something TingLang does not understand.'**
  String get cloudErrorBadResponse;

  /// No description provided for @settingsSpeechModels.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition'**
  String get settingsSpeechModels;

  /// No description provided for @speechForLive.
  ///
  /// In en, this message translates to:
  /// **'Live captions'**
  String get speechForLive;

  /// No description provided for @speechForFiles.
  ///
  /// In en, this message translates to:
  /// **'File transcription'**
  String get speechForFiles;

  /// No description provided for @speechAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get speechAuto;

  /// No description provided for @speechModelAppleSpeech.
  ///
  /// In en, this message translates to:
  /// **'Apple Speech'**
  String get speechModelAppleSpeech;

  /// No description provided for @speechModelAppleDictation.
  ///
  /// In en, this message translates to:
  /// **'Apple Dictation'**
  String get speechModelAppleDictation;

  /// No description provided for @speechModelXasr.
  ///
  /// In en, this message translates to:
  /// **'X-ASR Chinese + English'**
  String get speechModelXasr;

  /// No description provided for @speechModelSmallEn.
  ///
  /// In en, this message translates to:
  /// **'Zipformer English 20M'**
  String get speechModelSmallEn;

  /// No description provided for @speechModelMediumEn.
  ///
  /// In en, this message translates to:
  /// **'Zipformer English 66M'**
  String get speechModelMediumEn;

  /// No description provided for @speechModelXasrOffline.
  ///
  /// In en, this message translates to:
  /// **'X-ASR Chinese + English (files)'**
  String get speechModelXasrOffline;

  /// No description provided for @speechModelParakeet.
  ///
  /// In en, this message translates to:
  /// **'Parakeet TDT 0.6B v2'**
  String get speechModelParakeet;

  /// No description provided for @speechAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get speechAccuracy;

  /// No description provided for @speechSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speechSpeed;

  /// No description provided for @speechSystemAsset.
  ///
  /// In en, this message translates to:
  /// **'Part of macOS'**
  String get speechSystemAsset;

  /// No description provided for @speechInstalled.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get speechInstalled;

  /// No description provided for @speechNeedsMacos.
  ///
  /// In en, this message translates to:
  /// **'Needs macOS {version}'**
  String speechNeedsMacos(String version);

  /// No description provided for @speechInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get speechInUse;

  /// No description provided for @speechUseThis.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get speechUseThis;

  /// No description provided for @speechDownload.
  ///
  /// In en, this message translates to:
  /// **'Download {size}'**
  String speechDownload(String size);

  /// No description provided for @speechDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get speechDelete;

  /// No description provided for @speechCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get speechCancel;

  /// No description provided for @speechDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String speechDownloading(String percent);

  /// No description provided for @speechDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download {name}?'**
  String speechDownloadTitle(String name);

  /// No description provided for @speechDownloadBody.
  ///
  /// In en, this message translates to:
  /// **'{size} from {host}, kept in TingLang\'s data folder until you delete it. Licence: {license}.'**
  String speechDownloadBody(String size, String host, String license);

  /// No description provided for @speechDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String speechDeleteTitle(String name);

  /// No description provided for @speechDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Frees {size}. You can download it again later.'**
  String speechDeleteBody(String size);

  /// No description provided for @speechAccent.
  ///
  /// In en, this message translates to:
  /// **'English accent'**
  String get speechAccent;

  /// No description provided for @speechAccentDownload.
  ///
  /// In en, this message translates to:
  /// **'Download from Apple'**
  String get speechAccentDownload;

  /// No description provided for @speechAccentRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get speechAccentRemove;

  /// No description provided for @speechFarField.
  ///
  /// In en, this message translates to:
  /// **'Far-field audio (speakers, across a room)'**
  String get speechFarField;

  /// No description provided for @speechShortForm.
  ///
  /// In en, this message translates to:
  /// **'Short phrases'**
  String get speechShortForm;

  /// No description provided for @speechLatency.
  ///
  /// In en, this message translates to:
  /// **'Recognition latency'**
  String get speechLatency;

  /// No description provided for @latencyPowerSaver.
  ///
  /// In en, this message translates to:
  /// **'Power saver'**
  String get latencyPowerSaver;

  /// No description provided for @latencyBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get latencyBalanced;

  /// No description provided for @latencyFastest.
  ///
  /// In en, this message translates to:
  /// **'Lowest latency'**
  String get latencyFastest;

  /// No description provided for @latencyPowerSaverHelp.
  ///
  /// In en, this message translates to:
  /// **'Uses the least CPU; captions update a little less often.'**
  String get latencyPowerSaverHelp;

  /// No description provided for @latencyBalancedHelp.
  ///
  /// In en, this message translates to:
  /// **'Recommended.'**
  String get latencyBalancedHelp;

  /// No description provided for @latencyFastestHelp.
  ///
  /// In en, this message translates to:
  /// **'Earliest captions, slightly more CPU.'**
  String get latencyFastestHelp;

  /// No description provided for @panelModelNeeded.
  ///
  /// In en, this message translates to:
  /// **'{name} needs a one-time download ({size}) before captions can start.'**
  String panelModelNeeded(String name, String size);

  /// No description provided for @panelDownloadingModel.
  ///
  /// In en, this message translates to:
  /// **'Downloading {name}… {percent}%'**
  String panelDownloadingModel(String name, String percent);

  /// No description provided for @panelLanguageUnsupported.
  ///
  /// In en, this message translates to:
  /// **'{name} does not recognise {language}. Choose another model in Settings.'**
  String panelLanguageUnsupported(String name, String language);

  /// No description provided for @panelOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get panelOpenSettings;

  /// No description provided for @errorModelMissing.
  ///
  /// In en, this message translates to:
  /// **'Download {name} in Settings → Speech recognition first.'**
  String errorModelMissing(String name);

  /// No description provided for @errorSpeechAssetMissing.
  ///
  /// In en, this message translates to:
  /// **'macOS needs to download its speech model for {locale} first (Settings → Speech recognition).'**
  String errorSpeechAssetMissing(String locale);

  /// No description provided for @speechChecksumFailed.
  ///
  /// In en, this message translates to:
  /// **'The download did not match its checksum and was removed. The publisher may have changed the file; try again later.'**
  String get speechChecksumFailed;

  /// No description provided for @settingsSyncData.
  ///
  /// In en, this message translates to:
  /// **'Sync & data'**
  String get settingsSyncData;

  /// No description provided for @speechMode.
  ///
  /// In en, this message translates to:
  /// **'Recognition'**
  String get speechMode;

  /// No description provided for @speechModeLocal.
  ///
  /// In en, this message translates to:
  /// **'On this Mac'**
  String get speechModeLocal;

  /// No description provided for @speechModeCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud API'**
  String get speechModeCloud;

  /// No description provided for @speechChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'How should TingLang recognise speech?'**
  String get speechChooseTitle;

  /// No description provided for @speechChooseLocal.
  ///
  /// In en, this message translates to:
  /// **'Use a model on this Mac'**
  String get speechChooseLocal;

  /// No description provided for @speechChooseLocalBody.
  ///
  /// In en, this message translates to:
  /// **'Recognised on this Mac; no audio is uploaded.'**
  String get speechChooseLocalBody;

  /// No description provided for @speechChooseCloud.
  ///
  /// In en, this message translates to:
  /// **'Use a cloud API'**
  String get speechChooseCloud;

  /// No description provided for @speechChooseCloudBody.
  ///
  /// In en, this message translates to:
  /// **'For Macs that can\'t run the models. Your own key; audio is uploaded.'**
  String get speechChooseCloudBody;

  /// No description provided for @speechCpuLevel.
  ///
  /// In en, this message translates to:
  /// **'CPU {level}'**
  String speechCpuLevel(String level);

  /// No description provided for @speechCpuLow.
  ///
  /// In en, this message translates to:
  /// **'low'**
  String get speechCpuLow;

  /// No description provided for @speechCpuMedium.
  ///
  /// In en, this message translates to:
  /// **'medium'**
  String get speechCpuMedium;

  /// No description provided for @speechCpuHigh.
  ///
  /// In en, this message translates to:
  /// **'high'**
  String get speechCpuHigh;

  /// No description provided for @cloudSpeechService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get cloudSpeechService;

  /// No description provided for @cloudSpeechSendsTo.
  ///
  /// In en, this message translates to:
  /// **'Audio is sent to {host}.'**
  String cloudSpeechSendsTo(String host);

  /// No description provided for @cloudSpeechGetKey.
  ///
  /// In en, this message translates to:
  /// **'Get a key'**
  String get cloudSpeechGetKey;

  /// No description provided for @cloudSpeechSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get cloudSpeechSaved;

  /// No description provided for @cloudSpeechTestOk.
  ///
  /// In en, this message translates to:
  /// **'Connected.'**
  String get cloudSpeechTestOk;

  /// No description provided for @cloudSpeechForget.
  ///
  /// In en, this message translates to:
  /// **'Remove keys'**
  String get cloudSpeechForget;

  /// No description provided for @cloudSpeechForgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove the {service} keys?'**
  String cloudSpeechForgetTitle(String service);

  /// No description provided for @cloudSpeechNoLive.
  ///
  /// In en, this message translates to:
  /// **'{service} has no live recognition; live captions use the model on this Mac.'**
  String cloudSpeechNoLive(String service);

  /// No description provided for @cloudSpeechNoFile.
  ///
  /// In en, this message translates to:
  /// **'{service} cannot transcribe files; files use the model on this Mac.'**
  String cloudSpeechNoFile(String service);

  /// No description provided for @cloudSpeechFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter {field}.'**
  String cloudSpeechFieldRequired(String field);

  /// No description provided for @cloudFieldApiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get cloudFieldApiKey;

  /// No description provided for @cloudFieldApiSecret.
  ///
  /// In en, this message translates to:
  /// **'API Secret'**
  String get cloudFieldApiSecret;

  /// No description provided for @cloudFieldAppId.
  ///
  /// In en, this message translates to:
  /// **'App ID'**
  String get cloudFieldAppId;

  /// No description provided for @cloudFieldSecretId.
  ///
  /// In en, this message translates to:
  /// **'SecretId'**
  String get cloudFieldSecretId;

  /// No description provided for @cloudFieldSecretKey.
  ///
  /// In en, this message translates to:
  /// **'SecretKey'**
  String get cloudFieldSecretKey;

  /// No description provided for @cloudFieldRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get cloudFieldRegion;

  /// No description provided for @cloudRegionExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. eastus'**
  String get cloudRegionExample;

  /// No description provided for @cloudRegionCn.
  ///
  /// In en, this message translates to:
  /// **'Mainland China (Beijing)'**
  String get cloudRegionCn;

  /// No description provided for @cloudRegionIntl.
  ///
  /// In en, this message translates to:
  /// **'International (Singapore)'**
  String get cloudRegionIntl;

  /// No description provided for @cloudRegionUs.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get cloudRegionUs;

  /// No description provided for @cloudRegionEu.
  ///
  /// In en, this message translates to:
  /// **'European Union'**
  String get cloudRegionEu;

  /// No description provided for @cloudTencent.
  ///
  /// In en, this message translates to:
  /// **'Tencent Cloud'**
  String get cloudTencent;

  /// No description provided for @cloudDashscope.
  ///
  /// In en, this message translates to:
  /// **'Alibaba Cloud Model Studio'**
  String get cloudDashscope;

  /// No description provided for @cloudXfyun.
  ///
  /// In en, this message translates to:
  /// **'iFlytek'**
  String get cloudXfyun;

  /// No description provided for @cloudSoniox.
  ///
  /// In en, this message translates to:
  /// **'Soniox'**
  String get cloudSoniox;

  /// No description provided for @cloudAssemblyai.
  ///
  /// In en, this message translates to:
  /// **'AssemblyAI'**
  String get cloudAssemblyai;

  /// No description provided for @cloudAzure.
  ///
  /// In en, this message translates to:
  /// **'Azure AI Speech'**
  String get cloudAzure;

  /// No description provided for @panelChooseRecognizer.
  ///
  /// In en, this message translates to:
  /// **'Choose how to recognise speech first: a model on this Mac or a cloud API.'**
  String get panelChooseRecognizer;

  /// No description provided for @panelCloudNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Add your {service} key in Settings first.'**
  String panelCloudNotSetUp(String service);

  /// No description provided for @panelCloudNotChosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a cloud service in Settings first.'**
  String get panelCloudNotChosen;

  /// No description provided for @panelCloudLanguage.
  ///
  /// In en, this message translates to:
  /// **'{service} does not recognise {language}.'**
  String panelCloudLanguage(String service, String language);

  /// No description provided for @panelCloudLabel.
  ///
  /// In en, this message translates to:
  /// **'Cloud · {service}'**
  String panelCloudLabel(String service);

  /// No description provided for @asrFailedUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'{service} refused the key. Check it in Settings.'**
  String asrFailedUnauthorized(String service);

  /// No description provided for @asrFailedQuota.
  ///
  /// In en, this message translates to:
  /// **'{service}: no balance left, or the service isn\'t activated.'**
  String asrFailedQuota(String service);

  /// No description provided for @asrFailedRateLimited.
  ///
  /// In en, this message translates to:
  /// **'{service} is busy. Try again shortly.'**
  String asrFailedRateLimited(String service);

  /// No description provided for @asrFailedNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach {service}. Check the network.'**
  String asrFailedNetwork(String service);

  /// No description provided for @asrFailedLanguage.
  ///
  /// In en, this message translates to:
  /// **'{service} does not support this language.'**
  String asrFailedLanguage(String service);

  /// No description provided for @asrFailedTooLong.
  ///
  /// In en, this message translates to:
  /// **'The file is too long for {service}.'**
  String asrFailedTooLong(String service);

  /// No description provided for @asrFailedOther.
  ///
  /// In en, this message translates to:
  /// **'{service}: {message}'**
  String asrFailedOther(String service, String message);

  /// No description provided for @errorCloudNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Cloud recognition is on, but no key is saved. Add one in Settings → Speech recognition.'**
  String get errorCloudNotSetUp;

  /// No description provided for @accentUS.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get accentUS;

  /// No description provided for @accentGB.
  ///
  /// In en, this message translates to:
  /// **'United Kingdom'**
  String get accentGB;

  /// No description provided for @accentAU.
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get accentAU;

  /// No description provided for @accentIN.
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get accentIN;

  /// No description provided for @accentCA.
  ///
  /// In en, this message translates to:
  /// **'Canada'**
  String get accentCA;

  /// No description provided for @accentIE.
  ///
  /// In en, this message translates to:
  /// **'Ireland'**
  String get accentIE;

  /// No description provided for @accentNZ.
  ///
  /// In en, this message translates to:
  /// **'New Zealand'**
  String get accentNZ;

  /// No description provided for @accentSG.
  ///
  /// In en, this message translates to:
  /// **'Singapore'**
  String get accentSG;

  /// No description provided for @accentZA.
  ///
  /// In en, this message translates to:
  /// **'South Africa'**
  String get accentZA;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'iCloud Drive sync'**
  String get syncTitle;

  /// No description provided for @syncBadge.
  ///
  /// In en, this message translates to:
  /// **'iCloud'**
  String get syncBadge;

  /// No description provided for @syncBody.
  ///
  /// In en, this message translates to:
  /// **'Keep your courses, recordings and learning progress the same on every Mac signed in to your Apple Account. macOS syncs a Tinglang folder in your iCloud Drive; TingLang has no server of its own.'**
  String get syncBody;

  /// No description provided for @syncSwitch.
  ///
  /// In en, this message translates to:
  /// **'Sync through iCloud Drive'**
  String get syncSwitch;

  /// No description provided for @syncOff.
  ///
  /// In en, this message translates to:
  /// **'Off. Nothing is copied to iCloud Drive.'**
  String get syncOff;

  /// No description provided for @syncUnavailable.
  ///
  /// In en, this message translates to:
  /// **'iCloud Drive is off or not set up on this Mac. Turn it on in System Settings → Apple Account → iCloud → iCloud Drive, then come back here.'**
  String get syncUnavailable;

  /// No description provided for @syncNoAccess.
  ///
  /// In en, this message translates to:
  /// **'TingLang is not allowed to open iCloud Drive. Allow it in System Settings → Privacy & Security → Files and Folders, then try again.'**
  String get syncNoAccess;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not use the Tinglang folder in iCloud Drive. {error}'**
  String syncFailed(String error);

  /// No description provided for @syncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncSyncing;

  /// No description provided for @syncUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get syncUpToDate;

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get syncNever;

  /// No description provided for @syncLast.
  ///
  /// In en, this message translates to:
  /// **'Last synced {time}'**
  String syncLast(String time);

  /// No description provided for @syncWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for iCloud to download {count} item(s). They are added as soon as they arrive.'**
  String syncWaiting(String count);

  /// No description provided for @syncCounts.
  ///
  /// In en, this message translates to:
  /// **'{courses} course(s) · {recordings} recording(s) · {records} learning record(s)'**
  String syncCounts(String courses, String recordings, String records);

  /// No description provided for @syncOtherMacs.
  ///
  /// In en, this message translates to:
  /// **'Shared with {count} other Mac(s)'**
  String syncOtherMacs(String count);

  /// No description provided for @syncFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'iCloud Drive › Tinglang'**
  String get syncFolderLabel;

  /// No description provided for @syncShowInFinder.
  ///
  /// In en, this message translates to:
  /// **'Show in Finder'**
  String get syncShowInFinder;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncProblemNewerFolder.
  ///
  /// In en, this message translates to:
  /// **'The Tinglang folder in iCloud Drive was set up by a newer version of TingLang. Update TingLang on this Mac to keep syncing.'**
  String get syncProblemNewerFolder;

  /// No description provided for @syncProblemNewerState.
  ///
  /// In en, this message translates to:
  /// **'{name} uses a newer version of TingLang. Its changes are skipped until you update TingLang on this Mac.'**
  String syncProblemNewerState(String name);

  /// No description provided for @syncProblemUnreadableState.
  ///
  /// In en, this message translates to:
  /// **'Changes from another Mac could not be read and were skipped.'**
  String get syncProblemUnreadableState;

  /// No description provided for @syncProblemNewerPackage.
  ///
  /// In en, this message translates to:
  /// **'Skipped {name}: it was made by a newer version of TingLang.'**
  String syncProblemNewerPackage(String name);

  /// No description provided for @syncProblemUnreadablePackage.
  ///
  /// In en, this message translates to:
  /// **'Skipped {name}: its file in iCloud Drive could not be read.'**
  String syncProblemUnreadablePackage(String name);

  /// No description provided for @syncProblemWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Some changes could not be saved to iCloud Drive. Check that the disk has free space.'**
  String get syncProblemWriteFailed;

  /// No description provided for @syncUnnamedItem.
  ///
  /// In en, this message translates to:
  /// **'an item'**
  String get syncUnnamedItem;

  /// No description provided for @syncMoreProblems.
  ///
  /// In en, this message translates to:
  /// **'And {count} more.'**
  String syncMoreProblems(String count);

  /// No description provided for @syncFootnote.
  ///
  /// In en, this message translates to:
  /// **'Settings and API keys stay on each Mac. Turning sync off keeps what is already in iCloud Drive.'**
  String get syncFootnote;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'TingLang {version} is available.'**
  String updateAvailable(String version);

  /// No description provided for @updateWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get updateWhatsNew;

  /// No description provided for @updateInstall.
  ///
  /// In en, this message translates to:
  /// **'Update and restart'**
  String get updateInstall;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading TingLang {version}… {percent}%'**
  String updateDownloading(String version, String percent);

  /// No description provided for @updateCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get updateCancel;

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Checking the download and getting it ready…'**
  String get updateInstalling;

  /// No description provided for @updateRestarting.
  ///
  /// In en, this message translates to:
  /// **'TingLang is quitting to finish the update and will open again by itself.'**
  String get updateRestarting;

  /// No description provided for @updateTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get updateTryAgain;

  /// No description provided for @updateOpenReleasePage.
  ///
  /// In en, this message translates to:
  /// **'Open the release page'**
  String get updateOpenReleasePage;

  /// No description provided for @updateErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'The download stopped. Check your internet connection and try again.'**
  String get updateErrorNetwork;

  /// No description provided for @updateErrorChecksum.
  ///
  /// In en, this message translates to:
  /// **'The download did not match its published checksum, so it was deleted. Try again later.'**
  String get updateErrorChecksum;

  /// No description provided for @updateErrorPackage.
  ///
  /// In en, this message translates to:
  /// **'The download is not TingLang {version}, so nothing was installed. Download it from the release page instead.'**
  String updateErrorPackage(String version);

  /// No description provided for @updateErrorDisk.
  ///
  /// In en, this message translates to:
  /// **'The update could not be saved on this Mac. Check that the disk has free space.'**
  String get updateErrorDisk;

  /// No description provided for @updateErrorBusy.
  ///
  /// In en, this message translates to:
  /// **'Finish or save your recording first, then update.'**
  String get updateErrorBusy;

  /// No description provided for @updateErrorQuitRefused.
  ///
  /// In en, this message translates to:
  /// **'TingLang could not quit, so the update was not installed. Try again.'**
  String get updateErrorQuitRefused;

  /// No description provided for @updateErrorInstall.
  ///
  /// In en, this message translates to:
  /// **'The new version could not be put in place. Download it from the release page and replace TingLang yourself.'**
  String get updateErrorInstall;

  /// No description provided for @updateErrorNotBundle.
  ///
  /// In en, this message translates to:
  /// **'TingLang cannot find its own app to replace. Download the new version from the release page.'**
  String get updateErrorNotBundle;

  /// No description provided for @updateErrorTranslocated.
  ///
  /// In en, this message translates to:
  /// **'macOS is running TingLang from a temporary copy. Move TingLang to the Applications folder, open it from there and try again, or download the new version from the release page.'**
  String get updateErrorTranslocated;

  /// No description provided for @updateErrorReadOnly.
  ///
  /// In en, this message translates to:
  /// **'TingLang is running from a disk that cannot be changed (a disk image, for example). Move it to the Applications folder first, or download the new version from the release page.'**
  String get updateErrorReadOnly;

  /// No description provided for @updateErrorNotWritable.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot change the folder TingLang is in ({folder}). Download the new version from the release page and replace TingLang yourself.'**
  String updateErrorNotWritable(String folder);

  /// No description provided for @updateSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updateSettingsTitle;

  /// No description provided for @updateAutoCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates automatically'**
  String get updateAutoCheck;

  /// No description provided for @updateAutoCheckHelp.
  ///
  /// In en, this message translates to:
  /// **'Once a day TingLang asks GitHub (api.github.com) whether a new version is out. Only the app\'s version is sent, nothing about you or your recordings. When this is off, TingLang checks only when you press Check now.'**
  String get updateAutoCheckHelp;

  /// No description provided for @updateCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'You have TingLang {version}.'**
  String updateCurrentVersion(String version);

  /// No description provided for @updateCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get updateCheckNow;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'This is the latest version.'**
  String get updateUpToDate;

  /// No description provided for @updateNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No update found.'**
  String get updateNoneFound;

  /// No description provided for @updateNeverChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet.'**
  String get updateNeverChecked;

  /// No description provided for @updateLastChecked.
  ///
  /// In en, this message translates to:
  /// **'Last checked {time}.'**
  String updateLastChecked(String time);

  /// No description provided for @panelHintRecord.
  ///
  /// In en, this message translates to:
  /// **'Start live captions (⌘⇧T)'**
  String get panelHintRecord;

  /// No description provided for @panelHintStop.
  ///
  /// In en, this message translates to:
  /// **'Stop live captions (⌘⇧T)'**
  String get panelHintStop;

  /// No description provided for @panelHintMenu.
  ///
  /// In en, this message translates to:
  /// **'TingLang menu: open the app, appearance, settings'**
  String get panelHintMenu;

  /// No description provided for @updateBadgeHint.
  ///
  /// In en, this message translates to:
  /// **'TingLang {version} is available — click to update'**
  String updateBadgeHint(String version);

  /// No description provided for @updateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'TingLang {version} is available'**
  String updateDialogTitle(String version);

  /// No description provided for @updateDialogBody.
  ///
  /// In en, this message translates to:
  /// **'You have {current}. Updating downloads the new version, checks it, puts it in place and reopens TingLang. Your library and settings stay as they are.'**
  String updateDialogBody(String current);

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to TingLang'**
  String get onboardingWelcome;

  /// No description provided for @onboardingStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingStepOf(String current, String total);

  /// No description provided for @onboardingStepPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get onboardingStepPermissions;

  /// No description provided for @onboardingStepModel.
  ///
  /// In en, this message translates to:
  /// **'Speech model'**
  String get onboardingStepModel;

  /// No description provided for @onboardingStepUsage.
  ///
  /// In en, this message translates to:
  /// **'How to use'**
  String get onboardingStepUsage;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingDone.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingDone;

  /// No description provided for @onboardingPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Let TingLang hear the sound'**
  String get onboardingPermissionsTitle;

  /// No description provided for @onboardingPermissionsBody.
  ///
  /// In en, this message translates to:
  /// **'macOS asks you to approve these yourself. TingLang uses them only while captions or a recording run; unless you turn on a cloud service, the sound stays on this Mac.'**
  String get onboardingPermissionsBody;

  /// No description provided for @onboardingPermissionsReturn.
  ///
  /// In en, this message translates to:
  /// **'Come back after changing System Settings: this list updates by itself.'**
  String get onboardingPermissionsReturn;

  /// No description provided for @permissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get permissionRequired;

  /// No description provided for @permissionOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get permissionOptional;

  /// No description provided for @permissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get permissionGranted;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get permissionDenied;

  /// No description provided for @permissionAskedLater.
  ///
  /// In en, this message translates to:
  /// **'Asked on first use'**
  String get permissionAskedLater;

  /// No description provided for @permissionAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get permissionAllow;

  /// No description provided for @permissionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open System Settings'**
  String get permissionOpenSettings;

  /// No description provided for @permissionSystemAudio.
  ///
  /// In en, this message translates to:
  /// **'System audio recording'**
  String get permissionSystemAudio;

  /// No description provided for @permissionSystemAudioBody.
  ///
  /// In en, this message translates to:
  /// **'Live captions hear what your Mac plays (videos, meetings, podcasts) through it. macOS asks the first time captions start: choose Allow. If you said no before, open System Settings and turn TingLang on under system audio recording.'**
  String get permissionSystemAudioBody;

  /// No description provided for @permissionMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get permissionMicrophone;

  /// No description provided for @permissionMicrophoneBody.
  ///
  /// In en, this message translates to:
  /// **'For speaking practice, and for captions when their source is the microphone.'**
  String get permissionMicrophoneBody;

  /// No description provided for @permissionScreen.
  ///
  /// In en, this message translates to:
  /// **'Screen recording'**
  String get permissionScreen;

  /// No description provided for @permissionScreenBody.
  ///
  /// In en, this message translates to:
  /// **'A fallback: when system audio arrives silent, TingLang takes the sound through screen recording instead. It keeps no picture.'**
  String get permissionScreenBody;

  /// No description provided for @permissionFullDisk.
  ///
  /// In en, this message translates to:
  /// **'Full Disk Access'**
  String get permissionFullDisk;

  /// No description provided for @permissionFullDiskBody.
  ///
  /// In en, this message translates to:
  /// **'Only for importing Voice Memos; macOS may ask you to quit and reopen TingLang.'**
  String get permissionFullDiskBody;

  /// No description provided for @onboardingModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how speech is recognised'**
  String get onboardingModelTitle;

  /// No description provided for @onboardingModelBody.
  ///
  /// In en, this message translates to:
  /// **'Captions and transcripts come from a speech recognition model. A model on this Mac suits most people: free, offline, and the audio never leaves it.'**
  String get onboardingModelBody;

  /// No description provided for @onboardingRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get onboardingRecommended;

  /// No description provided for @onboardingModelForMac.
  ///
  /// In en, this message translates to:
  /// **'Recommended for this Mac'**
  String get onboardingModelForMac;

  /// No description provided for @onboardingModelReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get onboardingModelReady;

  /// No description provided for @onboardingModelNone.
  ///
  /// In en, this message translates to:
  /// **'No model on this Mac can run yet; a cloud API still works.'**
  String get onboardingModelNone;

  /// No description provided for @onboardingModelMore.
  ///
  /// In en, this message translates to:
  /// **'Other models, latency and accents are in Settings → Speech recognition.'**
  String get onboardingModelMore;

  /// No description provided for @onboardingCloudNext.
  ///
  /// In en, this message translates to:
  /// **'When you finish this guide, Settings → Speech recognition opens: pick a service and enter your own key.'**
  String get onboardingCloudNext;

  /// No description provided for @onboardingUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Using TingLang'**
  String get onboardingUsageTitle;

  /// No description provided for @onboardingUseStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start live captions'**
  String get onboardingUseStartTitle;

  /// No description provided for @onboardingUseStartBody.
  ///
  /// In en, this message translates to:
  /// **'Press the orange button at the left end of the floating panel, or ⌘⇧T in any app. What your Mac plays turns into captions as you listen.'**
  String get onboardingUseStartBody;

  /// No description provided for @onboardingUsePanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Place the panel'**
  String get onboardingUsePanelTitle;

  /// No description provided for @onboardingUsePanelBody.
  ///
  /// In en, this message translates to:
  /// **'Drag the panel anywhere over a video or a meeting. Point at it for its toolbar: change the look, or lock it so clicks pass through.'**
  String get onboardingUsePanelBody;

  /// No description provided for @onboardingUseHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Replay and learn'**
  String get onboardingUseHistoryTitle;

  /// No description provided for @onboardingUseHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'When you stop, the session is saved in History: replay it line by line, or make a course for close listening, speaking and review.'**
  String get onboardingUseHistoryBody;

  /// No description provided for @onboardingUseFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcribe files'**
  String get onboardingUseFilesTitle;

  /// No description provided for @onboardingUseFilesBody.
  ///
  /// In en, this message translates to:
  /// **'Drop an audio or video file on the panel or the main window to get a transcript you can replay line by line.'**
  String get onboardingUseFilesBody;

  /// No description provided for @onboardingReopen.
  ///
  /// In en, this message translates to:
  /// **'You can open this guide again from Settings → General.'**
  String get onboardingReopen;

  /// No description provided for @onboardingSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Getting started'**
  String get onboardingSettingsTitle;

  /// No description provided for @onboardingSettingsBody.
  ///
  /// In en, this message translates to:
  /// **'Permissions, the speech model and the basics, step by step.'**
  String get onboardingSettingsBody;

  /// No description provided for @onboardingSettingsOpen.
  ///
  /// In en, this message translates to:
  /// **'Show again'**
  String get onboardingSettingsOpen;

  /// No description provided for @panelMicrophoneDenied.
  ///
  /// In en, this message translates to:
  /// **'macOS doesn\'t let TingLang use the microphone. Turn TingLang on in System Settings → Privacy & Security → Microphone; if it is on already, turn it off and on again.'**
  String get panelMicrophoneDenied;

  /// No description provided for @panelSystemAudioDenied.
  ///
  /// In en, this message translates to:
  /// **'macOS doesn\'t let TingLang record system audio. Allow TingLang in System Settings → Privacy & Security, under screen and system audio recording.'**
  String get panelSystemAudioDenied;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
