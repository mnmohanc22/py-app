# Changelog

All notable changes to this project will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com)
Versioning: [Semantic Versioning](https://semver.org)

## [Unreleased]

## [1.4.2] — 2026-04-11
### Fixed
- Fix gunicorn socket path in systemd unit
- Fix SELinux context on log directory

## [1.4.1] — 2026-03-28
### Fixed
- Health endpoint returning 500 on cold start
- logrotate postrotate signal incorrect

## [1.4.0] — 2026-03-15
### Added
- AWS metadata enrichment in audit pipeline
- /api/v1/info endpoint
- ServiceNow work notes integration

### Changed
- Gunicorn workers formula updated to (CPU*2)+1

## [1.3.0] — 2026-02-01
### Added
- Initial Flask + gunicorn + nginx + systemd setup