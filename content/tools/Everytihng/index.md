---
title: "Everything"
description: "A filename search engine for Windows that indexes NTFS volumes and returns results instantly as you type."
version: "1.4.1.1032"
categories: ["Tools"]
tags: ["Applications","System MGMT"]
layout: "tools-single"
download_url: "https://www.voidtools.com/downloads/"
tool_image: "images/posts/Everything_(software)_icon.png"
---
# Everything

Everything is a filename search engine for Windows, developed by voidtools. Unlike Windows Search, it initially displays every file and folder on the machine and narrows the result set as a search filter is typed. It builds its index from the NTFS Master File Table rather than crawling the file system, which is why a full index of a typical workstation completes in seconds rather than hours.

The current stable release is 1.4.1.1032. A 1.5 beta (1.5.0.1422b) is published alongside it and introduces an expanded search syntax, plugin architecture, and ARM64 installers.

## Key Features
---

| Feature | Detail |
| :--- | :--- |
| **Instant filename search** | Results filter in real time as the search string is typed. |
| **Fast indexing** | A fresh Windows 11 install (approximately 250,000 files) indexes in about 5 seconds; 1,000,000 files takes about 1 minute. |
| **Low resource usage** | Approximately 35 MB RAM and under 14 MB disk for 250,000 files; approximately 100 MB RAM and 45 MB disk for 1,000,000 files. |
| **Real-time updates** | File system changes are monitored continuously and reflected in results immediately. |
| **USN Journal tracking** | NTFS indexes stay current via the NTFS USN Journal, so changes made while Everything is closed are not missed. |
| **Content search** | The `content:` function searches file contents. Content is not indexed, so this is significantly slower than filename search. |
| **Command line interface** | `es.exe` provides scriptable search, sorting, and export to CSV, TXT, EFU, and M3U. |
| **Network and non-NTFS indexing** | FAT, FAT32, exFAT, mapped drives, NAS, and network shares can be added as folder indexes. |
| **ETP/FTP and HTTP servers** | Remote search access over the network, available in the full (non-Lite) build. |
| **SDK** | Documented API for integrating Everything search into other applications. |

## Overview
---

Everything is a practical daily-driver tool for system administration and helpdesk work. Typical use cases include:

*   **Locating files without knowing the path** - useful when a user reports "I saved it somewhere" and the path is unknown.
*   **Finding orphaned or duplicated data** - sorting by size or extension to identify large files, stale installers, or PST/OST files consuming disk space.
*   **Auditing file distribution** - exporting result sets to CSV or EFU for reporting, migration planning, or storage cleanup.
*   **Rapid application launching** - searching for an executable and running it directly from the result list.
*   **Scripted inventory** - using `es.exe` in batch or PowerShell workflows to enumerate files matching a pattern across indexed volumes.

Everything is freeware, contains no malware, spyware, or adware, and is distributed under the MIT license via the Windows Package Manager manifest.

## System Requirements
---

| Item | Requirement |
| :--- | :--- |
| Operating system | Windows XP, Vista, 7, 8, 10, and 11 |
| Architectures | x86, x64, ARM, ARM64 (ARM builds are portable ZIP only in 1.4) |
| NTFS indexing | Requires the Everything service, or Everything running as administrator |
| Non-NTFS volumes | Indexed as folder indexes, added manually under Tools > Options > Folders |

NTFS indexing requires low-level read access to the volume, which is why administrative privileges are involved. Installing the Everything service and running the client as a standard user avoids a UAC prompt on every launch.

## Editions and Builds
---

| Build | Notes |
| :--- | :--- |
| **Standard (Multilingual)** | Full feature set, all supported languages included. |
| **Lite** | Same as standard with ETP/FTP server, HTTP server, and IPC removed. The command line interface, the SDK, and Windows accessibility features and screen readers will not work with the Lite build. |
| **Portable ZIP** | No installation, no service; suitable for running from a technician USB stick. |
| **en-US** | English-only build, roughly 40 percent smaller than the multilingual package. |
| **1.5 Beta** | Adds plugin support, expanded search syntax, and ARM64 installers. Currently 1.5.0.1422b. |

## Installation and Access
---

Everything can be obtained and deployed in several ways:

*   **Download the installer**: EXE and MSI installers for x86 and x64 are available from the [voidtools downloads page](https://www.voidtools.com/downloads). By default Everything installs to `C:\Program Files\Everything`.
*   **Run portable**: Extract the portable ZIP and run `Everything.exe` directly. Note that NTFS indexing still requires administrator rights or the service.
*   **Install via Winget**: Use the Windows Package Manager for scripted or unattended deployment.
*   **Install the Everything service**: Under Tools > Options > General, check **Everything Service** and uncheck **Run as administrator**. This is the recommended configuration for managed endpoints, as it removes the UAC prompt while retaining NTFS indexing.
*   **Store settings in the user profile**: Under Tools > Options > General, check **Store settings and data in %APPDATA%\Everything** so per-user configuration persists correctly.

Winget package identifiers:

```powershell
# Stable release
winget install -e --id voidtools.Everything

# 1.5 beta
winget install -e --id voidtools.Everything.Beta

# Command line interface (ES)
winget install -e --id voidtools.Everything.Cli
```

MSI packages are published for both architectures, which makes Everything straightforward to deploy through Intune, Group Policy software installation, or an RMM tool. Installation requires administrative privileges.

## Search Syntax Quick Reference
---

The following operators are documented in the voidtools FAQ and apply to the 1.4 stable release.

| Syntax | Result |
| :--- | :--- |
| `abc 123` | AND - matches names containing both terms (space is the default AND operator) |
| `*.jpg \| *.bmp` | OR - matches either term |
| `!abc` | NOT - excludes the term |
| `"foo bar"` | Quoted literal, used to include spaces |
| `*` | Matches any number of characters |
| `?` | Matches exactly one character |
| `*.mp3` | Matches a file extension |
| `downloads\ .mp3` | Restricts the search to a path segment |

Everything 1.5 extends this with grouping, macros, and character entities:

| Syntax | Result |
| :--- | :--- |
| `!<abc 123>` | Grouping - matches NOT (abc AND 123) |
| `<apple banana> \| orange` | Grouping to override precedence (OR is evaluated before AND by default) |
| `audio:` `video:` `image:` `doc:` `exe:` `zip:` | Macros matching common file type groups |
| `path:abc` | Matches the full path rather than the filename |
| `date-modified:today` | Search function against a file property |
| `case:extension:JPG` | Search modifier combined with a search function |
| `C:\Program&sp:Files` | Character entity for a literal space |

Filename parts are addressable as separate components: for `C:\folder\file.txt`, the path is `C:\folder`, the name is `file.txt`, the stem is `file`, and the extension is `txt`.

## Command Line Interface (ES)
---

`es.exe` is a separate download that queries a running Everything instance over IPC. Everything must be installed and running, and the Lite build is not supported.

```
es.exe [options] [search text]
```

Common options:

| Option | Purpose |
| :--- | :--- |
| `-n <num>` | Limit the number of results |
| `-sort <column>` | Sort by name, path, size, extension, or a date column |
| `-p` | Match full path and file name |
| `-r` | Search using regular expressions |
| `-export-csv <file>` | Export results to CSV |
| `-export-efu <file>` | Export to an Everything file list |
| `-date-format 1` | Output dates as ISO-8601 |
| `-get-result-count` | Return the total result count only |
| `/ad` and `/a-d` | Folders only, or files only |
| `-reindex` | Force a reindex and return once complete |

Examples taken from the voidtools documentation:

```
:: Export all mp3 files to an Everything file list
es.exe *.mp3 -export-efu mp3.efu

:: Show the ten largest files
es.exe -sort size -n 10

:: Show the ten most recently modified files
es.exe -sort dm -n 10
```

ES returns errorlevel 0 on success. Errorlevel 8 indicates the Everything IPC window was not found, which in practice means the Everything client is not running.

## Common Configuration Issues
---

| Symptom | Resolution |
| :--- | :--- |
| Result list is empty or shows only drives | The Everything service is not running and Everything is not elevated. Enable the service under Tools > Options > General, or check **Run as administrator**. |
| Duplicated results | An NTFS volume has been added manually as a folder index. NTFS volumes are indexed automatically; remove the duplicate under Tools > Options > Folders. |
| Settings are not saved | Enable **Store settings and data in %APPDATA%\Everything** under Tools > Options > General. |
| Search returns nothing expected | Clear Match Case, Match Whole Word, Match Path, Match Diacritics, and Enable Regex in the Search menu. |
| Network drive not listed | Run Everything as a standard user with the service enabled, then restart the client from the tray icon. |
| Index appears stale | Tools > Options > Indexes > **Force Rebuild**. |

## Getting Started and Learning Resources
---

*   **Official documentation**: The [Everything support index](https://www.voidtools.com/support/everything) covers installation, search syntax, indexing, the service, plugins, and the SDK.
*   **FAQ**: The [voidtools FAQ](https://www.voidtools.com/faq) is the fastest reference for indexing behaviour, resource usage, and troubleshooting.
*   **Offline help**: CHM and HTML help packages are available for air-gapped or restricted environments.
*   **Forums**: The [voidtools forum](https://www.voidtools.com/forum) carries beta changelogs and the 1.5 upgrade guide.
*   **Source repositories**: The ES command line interface, HTTP server plugin, and ETP server plugin are published on [GitHub](https://github.com/voidtools).

> **Note**: The 1.5 branch is still labelled beta by voidtools and its search syntax is not backward compatible with 1.4 in all cases. For managed estates, deploying the 1.4 stable MSI with the Everything service enabled and the client running as a standard user is the most predictable configuration.

## References
---

- Everything support home: https://www.voidtools.com/support/everything
- voidtools downloads: https://www.voidtools.com/downloads
- voidtools FAQ: https://www.voidtools.com/faq
- Search syntax (1.5): https://www.voidtools.com/support/everything/search_syntax
- Command line interface (ES): https://www.voidtools.com/support/everything/command_line_interface
- Installing Everything: https://www.voidtools.com/support/everything/installing_everything
- Everything service: https://www.voidtools.com/support/everything/everything_service
- Everything SDK: https://www.voidtools.com/support/everything/sdk
- License: https://www.voidtools.com/License.txt
- Winget manifest (voidtools.Everything): https://github.com/microsoft/winget-pkgs/tree/master/manifests/v/voidtools/Everything

---

*Everything is developed and maintained by voidtools. Version information accurate as of August 2026.*