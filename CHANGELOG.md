# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.1.2] - 2019-07-30

### Added

### Fixed

- Update Dashboards from the "Export for sharing externally" to normal export, to avoid datasource templating errors.

### Changed

- Made the error log output from the Get-CADC functions consistent with each other.

## [0.1.1] - 2019-07-29

### Added

- Leaves InfluxData, log files, and scripts in place during Uninstall-VisualizationSetup
- **New Dashboard** - CVAD Delivery Group Details
- **New Dashboard** - CVAD TimeShift

### Fixed

- Fixes [#2](https://github.com/littletoyrobots/EUCMonitoringRedux/issues/2) - Have the Install-VisualizationSetup insert Grafana yaml files in the newly downloaded directory.

### Changed

- Moved the incomplete scripts to Testing directory in Config
- Assets for screenshots moved to its own branch

## [0.1.0] - 2019-07-26

### Added

- First public version.
- Figuring out if I like this Changelog format
- **New Dashboard** - CADC Overview
- **New Dashboard** - CVAD Overview

### Fixed

- Fixes [#1](https://github.com/littletoyrobots/EUCMonitoringRedux/issues/1) - Answers questions about current usage of Invoke-CommandAs, which is not yet ready for inclusion as it creates an additional dependency.

## [0.0.0] - YYYY-MM-DD

### Added

- New features

### Changed

- Changes in existing functionality

### Fixed

- Any bug fixes, with referenced case using the following format
- Fixes [#0](https://github.com/littletoyrobots/EUCMonitoringRedux/issues/0) - Short Blurb

### Removed

- Any now removed features

### Security

- In case of vulnerabilities
