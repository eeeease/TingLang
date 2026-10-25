# Importing courses

Tinglang reads courses in the English V3 format (`schema_version: 2`, `design_version: 3`) — the same format it writes when it generates a course from one of your recordings.

## English `course.json`

In **Library → Mine**, choose **Import**, pick an area, then the `course.json`. You can select the complete original media at the same time, or import the course first and link the media later from the Learn page.

- `schema_version: 2` with `design_version: 3` is recognised. Do not change a "V3 design" course to `schema_version: 3`.
- Course times are **absolute times in the complete original media**. A 60-second file cut from minute 10 cannot be paired with a course that still says `00:10:00`.
- Importing the same `podcast_id` again updates the content and keeps recordings, drafts, saved items and completion. Stable clip IDs are what keep those links; history of removed clips is not deleted, but it can no longer jump to a clip that does not exist.
- Instructions inside the JSON are never followed, file paths inside it are never read and URLs are never downloaded.
- Sentence-by-sentence jumps appear only when explicit `tinglang_cues` give sentence times. Older courses with clip times only are never given invented word or sentence alignment.
- `progress.json`, `attempts.jsonl` and Echo-Loop databases are not migrated. Only course content is imported.

## Local media with subtitles

With media and SRT/VTT subtitles only, the importer splits the real cues into segments of about a minute. It does not generate glosses or blanks for you; use **Make course** on a transcribed recording for that. With media only, you can play, shadow and record; the transcript stays empty.

Media files are hashed while streaming, copied into the app's data folder and checked after copying. UTF-8 JSON, SRT and VTT are expected, and a JSON file is limited to 20 MB.
