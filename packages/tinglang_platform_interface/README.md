# tinglang_platform_interface

Pure Dart (no Flutter). Defines every native capability Tinglang uses as an
interface, the `Availability` result of probing a backend, the
`BackendRegistry<T>` factory that picks one implementation per capability, and
fake implementations for tests. Runs with `dart test` on Linux CI.

Backend ids and their OS/version/permission/download requirements live in
`BackendCatalog`; real implementations (in `tinglang_native_*`) and fakes share
the same specs, so selection tests exercise the real rules.
