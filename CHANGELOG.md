# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.2.0 - 2024-11-25

### Added

- Added optional internal supervision of the buffer.
- Added `async_push/2`.

### Fixed

- Requeuing failed messages.

## 1.1.0 - 2024-07-11

### Added

- Added a `:buffer` option to `OffBroadwayMemory.Producer`.

### Changed

- Deprecated `:buffer_pid` in `OffBroadwayMemory.Producer`, use `:buffer` instead.

### Fixed

- Fixed passing options to `OffBroadwayMemory.Buffer.start_link/1`. Thanks @lukeledet.
