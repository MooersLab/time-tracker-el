![Version](https://img.shields.io/static/v1?label=time-tracker-el&message=0.0&color=brightcolor)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)


# Load events into a time tracking database from inside Emacs

**Problem address:** Org-mode in Emacs provides a time-logging feature underneath headlines for specific projects. 
The aggregation of this information across multiple projects is unwieldy when the number of projects exceeds half a dozen.

**Solution:** Store the events from hundreds and even thousands of projects over decades inside a single SQL light database.
The database, when opened in database viewing programs, is vulnerable to corruption by sticky mouse cursors dragging values from one cell to another.
The Emacs package `time-tracker.el` enables loading information about an event into the database from inside Emacs, thereby avoiding the mouse-dragging issue and minimizing context switching from other tasks being worked on in Emacs.

## Features: 

- Many of the fields are pre-populated, such as the date and the end time for the last event service as a default start time for the new event.
- Entry of the project number invokes loading the project name as the default for the project field. This avoids the entry of misspelled project names. Such misspellings can hamper the generation of reports.

## Planned features

- The generation of various reports.

## Status: very alpha

## Update history

|Version      | Changes                                                                                                                                                                         | Date                 |
|:-----------|:------------------------------------------------------------------------------------------------------------------------------------------|:--------------------|
| Version 0.1 |   Added badges, funding, and update table.  Initial commit.                                                                                                                | 7/15/2025  |

## Sources of funding

- NIH: R01 CA242845
- NIH: R01 AI088011
- NIH: P30 CA225520 (PI: R. Mannel)
- NIH: P20 GM103640 and P30 GM145423 (PI: A. West)
