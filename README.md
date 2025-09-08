# Log Archive Tool

A simple CLI utility to archive and rotate logs on Unix-like systems.  
It compresses a log directory into a timestamped `tar.gz`, stores it in an archive directory, and maintains a history log.  
Optionally, it can also delete archives older than a given number of days.

---

## Features
- Archive logs from any directory (default `/var/log`)
- Creates compressed archives with timestamped names:

- Keeps a history file with timestamp, source, archive path, and size
- Supports custom output directory
- Optional retention policy (`--retain <days>`) to delete old archives
- Safe excludes (does not re-archive archives)

---

## Requirements
- Unix-based system (Linux, macOS, BSD)
- `tar` available in PATH
- Run with `sudo` if archiving system logs (`/var/log`)

---

## Installation
Clone the repo and make the script executable:

```bash
git clone https://github.com/yourname/Log-Archive-Tool.git
cd Log-Archive-Tool
chmod +x log-archive.sh
sudo mv log-archive.sh /usr/local/bin/log-archive

---

## Project Source

This project is part of the [Log Archive Tool project on roadmap.sh](https://roadmap.sh/projects/log-archive-tool)
