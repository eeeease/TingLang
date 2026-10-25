# Security policy

## Reporting a vulnerability

Please report security problems privately through GitHub: open the repository's **Security** tab and choose **Report a vulnerability**. Do not open a public issue for them.

Include what you found, how to reproduce it, the Tinglang version or commit, and your macOS version. Never include real API keys, sign-in tokens, recordings or other personal data in a report; describe them instead.

This is a small project maintained in spare time. You will get an acknowledgement as soon as the report has been read, and a fix or a decision with its reasons as soon as practical. Please give us a reasonable time to release a fix before you publish details.

如需中文沟通，可以在私密报告里直接用中文书写。

## Scope

In scope: the macOS app in this repository, its native plugin, the scripts that build it, the API contract in `api/` and the client in `packages/tinglang_api`.

Especially welcome: ways the app could send audio, transcripts or keys anywhere the user did not choose; ways to make the app follow paths, URLs or instructions found inside imported files, course JSON or model output; Keychain or sign-in token leaks; problems in how imported `.tinglang` and course files are unpacked.

Out of scope: servers that implement the API contract (report those to whoever runs them), third-party AI providers, and Apple's own frameworks.

## Supported versions

Only the latest commit on `main` receives fixes until regular releases exist.
