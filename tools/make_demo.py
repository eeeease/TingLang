#!/usr/bin/env python3
"""Create original demo text + synthetic audio. Requires espeak; not needed to build the app."""
from pathlib import Path
import subprocess
import tempfile
import wave
import json

ROOT = Path(__file__).resolve().parents[1]
DEMO = ROOT / 'assets/demo'
DEMO.mkdir(parents=True, exist_ok=True)
SCENES = [
    ("Show up, get better", [
        "I used to focus on the final score.",
        "These days, I try to get a little better every day.",
        "Showing up matters more than having one perfect session.",
    ], "score", "Showing up", "出现并坚持参与", "These days, I try to ...",
     "现在，我尝试每天进步一点。", "These days, I try to speak English for a few minutes every day.",
     "How has your approach to practice changed?"),
    ("Stay consistent", [
        "When I make a mistake, I try to learn from it.",
        "The goal is not to be perfect, but to stay consistent.",
        "Progress takes patience, especially when things get difficult.",
    ], "patience", "learn from it", "从这件事中吸取经验", "The goal is not to ..., but to ...",
     "目标不是完美，而是坚持。", "The goal is not to sound impressive, but to explain my ideas clearly.",
     "Describe a recent mistake and what you learned from it."),
    ("Take it into your life", [
        "That mindset helps me outside the gym, too.",
        "I have been working on explaining my ideas more clearly.",
        "It takes practice, but I am getting more comfortable.",
    ], "mindset", "takes practice", "需要练习", "I have been working on ...",
     "我一直在练习更清楚地表达想法。", "I have been working on describing my day without switching languages.",
     "What is one thing you are working on right now?"),
]
frames = bytearray()
clips = []
rate = 22050
with tempfile.TemporaryDirectory() as tmp:
    for index, (title, sentences, word, phrase, meaning, frame, sentence_meaning, example, prompt) in enumerate(SCENES, 1):
        cid = f'clip_{index:03}'
        start = len(frames) * 1000 // (rate * 2)
        cues = []
        for si, sentence in enumerate(sentences):
            path = Path(tmp) / f'{index}-{si}.wav'
            subprocess.run(['espeak', '-v', 'en-us', '-s', '150', '-w', str(path), sentence], check=True)
            with wave.open(str(path)) as wav:
                assert wav.getnchannels() == 1 and wav.getsampwidth() == 2 and wav.getframerate() == rate
                a = len(frames) * 1000 // (rate * 2)
                frames.extend(wav.readframes(wav.getnframes()))
                b = len(frames) * 1000 // (rate * 2)
            cues.append(dict(index=si, text=sentence, startTime=a, endTime=b, isBookmarked=False))
            frames.extend(b'\0\0' * int(rate * .28))
        end = len(frames) * 1000 // (rate * 2)
        transcript = ' '.join(sentences)
        def item(iid, kind, text, meaning, original, learner, reusable=''):
            result = dict(id=iid, type=kind, text=text, meaning_zh=meaning,
                simple_explanation_en='Use this expression in a personal example.',
                why_useful='Useful for talking about practice and everyday improvement.',
                original_example=original, timestamp=f'{start//3600000:02}:{start//60000%60:02}:{start//1000%60:02}.{start%1000:03}', usage_note=None,
                common_patterns=[reusable or text], learner_example=learner,
                memory_aid=dict(type='sentence_frame' if kind=='sentence' else 'collocation_chunk',
                    cue_zh='保留表达骨架，换成你自己的真实经历。', note='A practice cue, not an etymology claim.'))
            if kind == 'phrase': result['subtype'] = 'phrase'
            if reusable: result['reusable_frame'] = reusable
            return result
        phrase_item = item(f'{cid}_phrase_01', 'phrase', phrase, meaning,
            next(s for s in sentences if phrase in s), example)
        sentence_item = item(f'{cid}_sentence_01', 'sentence', sentences[1], sentence_meaning,
            sentences[1], example, frame)
        blanks = [dict(id=f'{cid}_blank_word', type='word', answer=word),
            dict(id=f'{cid}_blank_phrase', type='phrase', answer=phrase, learning_item_id=phrase_item['id']),
            dict(id=f'{cid}_blank_sentence', type='sentence', answer=sentences[1], learning_item_id=sentence_item['id'])]
        template = transcript
        for blank in sorted(blanks, key=lambda b: len(b['answer']), reverse=True):
            template = template.replace(blank['answer'], '{{' + blank['id'] + '}}', 1)
        clips.append(dict(id=cid, title=title, topic='Practice and progress', start=start/1000, end=end/1000,
            difficulty=5, learning_value=8, why_selected='Original, self-contained demo of reusable frames.',
            transcript=transcript, learning=dict(words=[], phrases=[phrase_item], sentences=[sentence_item]),
            blind_listening=dict(template=template, blanks=blanks),
            shadowing=[dict(text=s, reason='Try the complete thought, then compare your recording.') for s in sentences[:2]],
            retelling=dict(id=f'{cid}_retelling_01', prompt=prompt,
                outline=['Describe the change or challenge.', 'Explain the approach to practice.'],
                source_evidence=sentences[:2], target_item_ids=[phrase_item['id'], sentence_item['id']],
                follow_up='Use one expression to talk about your own life, not the demo speaker.'),
            tinglang_cues=cues))
with wave.open(str(DEMO / 'consistency.wav'), 'wb') as out:
    out.setnchannels(1); out.setsampwidth(2); out.setframerate(rate); out.writeframes(frames)
course = dict(schema_version=2, design_version=3, podcast_id='tinglang-demo-consistency',
    title='Small reps. Real progress.', learner_level='B2 practice demo',
    tinglang_source='原创演示文字 · eSpeak 合成语音 · 非真实 NBA 采访',
    playback=dict(captions_default=False, show_clip_boundaries=True, transcript_default='hidden'),
    overview=dict(episode_summary_en='An original practice demo about showing up, staying consistent, and expressing your own ideas.',
        episode_summary_zh='从坚持训练到表达自己：原创功能演示，不是采访摘录。', selected_clip_count=3,
        estimated_study_minutes=12, main_topics=['Consistency', 'Practice'], learning_focus=['Reusable sentence frames']),
    clips=clips)
(DEMO / 'course.json').write_text(json.dumps(course, ensure_ascii=False, indent=2) + '\n')
print(f'Original demo: {len(frames)/(rate*2):.2f}s, {len(clips)} clips')
