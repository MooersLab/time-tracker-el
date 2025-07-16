![Version](https://img.shields.io/static/v1?label=time-tracker-el&message=0.0&color=brightcolor)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)


# Load events into time tracking database from inside Emacs

*Prolem address:* Org-mode in Emacs provides a time-logging feature underneath headlines for specific projects. 
The aggregating of this information across multiple projects is unwieldly when the number of projects exceeds a half dozen.

*Solution:* store the events from hundreds and even thousands of projects over decades inside of a single SQL light database.
The database when opened in database viewing programs is vulnerable to corruption by sticky mouse cursers dragging values from one cell to another.
The Emacs package `time-tracker.el` here enables the loading of the information about an event into the database from inside of Emacs to avoid the mouse dragging issue and to avoid contextt switching from other work that one is doing in Emacs.

## Features: 

- many of the fields are pre-populated such as the date and the end time for the last event service as a default start timefor the new event.
- entry of the project number invokes loading the project name as at the default for the projecting field. This avoids the entry of misspelled project names. Such misspellings can hamper the generation of reports.

## Planned features

- The generation of various reports

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
