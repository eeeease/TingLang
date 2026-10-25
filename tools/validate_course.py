#!/usr/bin/env python3
"""Read-only validation of the subset of English V3 consumed by Tinglang.

This is not a replacement for English's full pedagogical validator. No media
URL, file path, prompt, command or external reference is executed.
"""
from pathlib import Path
import argparse
import json
import math
import re


def timestamp(value: object) -> int:
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if math.isfinite(value) and value >= 0:
            return math.floor(value * 1000 + .5)
    if isinstance(value, str):
        match = re.fullmatch(r'(?:(\d+):)?([0-5]?\d):([0-5]\d)(?:[.,](\d{1,3}))?', value.strip())
        if match:
            h, m, s, ms = match.groups()
            return ((int(h or 0) * 60 + int(m)) * 60 + int(s)) * 1000 + int((ms or '').ljust(3, '0'))
    raise ValueError(f'Invalid timestamp: {value!r}')


def validate(course: dict) -> list[str]:
    errors: list[str] = []
    if not isinstance(course, dict):
        return ['course must be a JSON object']
    if type(course.get('schema_version')) is not int or course['schema_version'] != 2:
        errors.append('Expected schema_version: 2')
    if course.get('design_version', 3) != 3:
        errors.append('Expected design_version: 3')
    for name in ('podcast_id', 'title'):
        if not isinstance(course.get(name), str) or not course[name].strip():
            errors.append(f'Missing {name}')
    clips = course.get('clips')
    if not isinstance(clips, list) or not 1 <= len(clips) <= 5000:
        return errors + ['Expected 1–5000 clips']
    seen: set[str] = set()
    item_ids: set[str] = set()
    for index, clip in enumerate(clips):
        try:
            cid = clip['id']
            if not isinstance(cid, str) or not cid.strip() or cid in seen:
                raise ValueError('missing or duplicate clip id')
            seen.add(cid)
            start = timestamp(clip['start'])
            end = None if clip.get('end') is None and course.get('tinglang_untranscribed') is True else timestamp(clip.get('end'))
            if end is not None and end <= start:
                raise ValueError('end is not later than start')
            transcript = clip.get('transcript', '')
            if not isinstance(transcript, str):
                raise ValueError('transcript must be text')
            for group in ('words', 'phrases', 'sentences'):
                for item in clip.get('learning', {}).get(group, []):
                    iid = item.get('id')
                    if not iid or iid in item_ids:
                        raise ValueError('missing or duplicate learning item id')
                    item_ids.add(iid)
                    if not item.get('text'):
                        raise ValueError(f'{iid}: missing text')
                    original = item.get('original_example', '')
                    if original and original not in transcript:
                        raise ValueError(f'{iid}: original_example is not in transcript')
            blind = clip.get('blind_listening', {})
            template = blind.get('template', '')
            reconstructed = template
            bids: set[str] = set()
            for blank in blind.get('blanks', []):
                bid, answer = blank['id'], blank['answer']
                token = '{{' + bid + '}}'
                if bid in bids or template.count(token) != 1 or not answer:
                    raise ValueError('duplicate or missing blank token/answer')
                bids.add(bid)
                reconstructed = reconstructed.replace(token, answer)
            if template and (re.sub(r'\s+', ' ', reconstructed).strip() != re.sub(r'\s+', ' ', transcript).strip()
                             or re.search(r'\{\{[^}]+\}\}', reconstructed)):
                raise ValueError('blind answers do not reconstruct transcript')
            for passage in clip.get('shadowing', []):
                text = passage if isinstance(passage, str) else passage['text']
                if text not in transcript:
                    raise ValueError('shadowing text is not in transcript')
            retell = clip.get('retelling', {})
            evidence = retell.get('source_evidence', [])
            if evidence and (len(evidence) != len(retell.get('outline', [])) or any(e not in transcript for e in evidence)):
                raise ValueError('retelling evidence does not match source')
            for cue in clip.get('tinglang_cues', []):
                if (cue['startTime'] < start or cue['endTime'] <= cue['startTime']
                        or (end is not None and cue['endTime'] > end)):
                    raise ValueError('subtitle cue outside clip bounds')
        except (KeyError, ValueError, TypeError, AttributeError) as error:
            errors.append(f'clip[{index}]: {error}')
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('course', type=Path)
    args = parser.parse_args()
    try:
        if args.course.stat().st_size > 20 * 1024 * 1024:
            raise ValueError('Course JSON exceeds 20 MB')
        data = json.loads(args.course.read_text(encoding='utf-8'))
        errors = validate(data)
    except (OSError, ValueError) as error:
        errors = [str(error)]
    if errors:
        for error in errors: print(f'ERROR: {error}')
        return 1
    print(f'VALID: {data["podcast_id"]}, {len(data["clips"])} clips. No media was opened or downloaded.')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
