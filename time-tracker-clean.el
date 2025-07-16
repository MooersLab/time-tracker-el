;;; time-tracker.el --- Track time spent on projects  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Blaine Mooers

;; Author: Blaine Mooers
;; Version: 0.1
;; Package-Requires: ((emacs "27.1") (dash "2.18.0") (s "1.12.0"))
;; Keywords: convenience, tools
;; URL: https://github.com/MooersLab/time-tracker

;;; Commentary:

;; This package provides functionality for tracking time spent on projects
;; by adding entries to a SQLite database.  It offers an efficient workflow
;; with smart defaults based on previous entries.
;;
;; Features:
;; - Smart defaults for date, start time, and project ID
;; - Project directory verification from a project database
;; - Activity categorization (G-generative, E-editing, S-support)
;; - Display of recent time entries
;; - Interactive input via the minibuffer
;;
;; Usage:
;; M-x time-tracker-add-entry

;;; Code:

(require 'dash)
(require 's)

;; Check for sqlite support
(defvar time-tracker--use-sqlite3 nil
  "Whether to use sqlite3.el instead of sqlite.el.")

(cond
 ((featurep 'sqlite)
  (setq time-tracker--use-sqlite3 nil))
 ((featurep 'sqlite3)
  (setq time-tracker--use-sqlite3 t))
 ((require 'sqlite nil t)
  (setq time-tracker--use-sqlite3 nil))
 ((require 'sqlite3 nil t)
  (setq time-tracker--use-sqlite3 t))
 (t
  (error "Time Tracker requires SQLite support. Either use Emacs 29+ (built-in) or install sqlite.el/sqlite3.el package")))

;;; Customization

(defgroup time-tracker nil
  "Time tracking using SQLite database."
  :group 'tools
  :prefix "time-tracker-")

(defcustom time-tracker-db-path "~/6003TimeTracking/cb/mytime.db"
  "Path to the time tracker SQLite database."
  :type 'string
  :group 'time-tracker)

(defcustom time-tracker-projects-db-path "~/6003TimeTracking/cb/tenKprojects.db"
  "Path to the project directory database."
  :type 'string
  :group 'time-tracker)

(defcustom time-tracker-table-name "zTimeSpent"
  "Name of the time tracking table in the database."
  :type 'string
  :group 'time-tracker)

(defcustom time-tracker-projects-table-name "tenKprojects"
  "Name of the projects table in the projects database."
  :type 'string
  :group 'time-tracker)

(defcustom time-tracker-recent-entries-limit 20
  "Number of recent entries to display."
  :type 'integer
  :group 'time-tracker)

;;; Internal variables

(defvar time-tracker--db nil
  "Database connection to the time tracker database.")

(defvar time-tracker--projects-db nil
  "Database connection to the projects database.")

;; SQLite adapter functions to abstract away differences between sqlite.el and sqlite3.el
(defun time-tracker--sqlite-open (db-path)
  "Open a connection to the SQLite database at DB-PATH."
  (message "Using SQLite implementation: %s" (if time-tracker--use-sqlite3 "sqlite3.el" "sqlite.el"))
  (if time-tracker--use-sqlite3
      (progn
        (message "Opening database with sqlite3.el: %s" db-path)
        (sqlite3-open db-path))
    (message "Opening database with sqlite.el: %s" db-path)
    (sqlite-open db-path)))

(defun time-tracker--sqlite-close (db)
  "Close the SQLite database connection DB."
  (if time-tracker--use-sqlite3
      (sqlite3-close db)
    (sqlite-close db)))

(defun time-tracker--sqlite-select (db query &optional params)
  "Execute SELECT QUERY against DB with optional PARAMS."
  (if time-tracker--use-sqlite3
      (let ((result (sqlite3-select db query params)))
        result)
    (sqlite-select db query)))

(defun time-tracker--sqlite-execute (db query &optional params)
  "Execute SQLite QUERY against DB with optional PARAMS."
  (if time-tracker--use-sqlite3
      (sqlite3-execute db query params)
    (sqlite-execute db query params)))

(defun time-tracker--connect-db ()
  "Connect to the time tracker database."
  (message "Attempting to connect to time tracker database at: %s" time-tracker-db-path)
  (when time-tracker--db
    (message "Closing existing database connection")
    (time-tracker--sqlite-close time-tracker--db))
  (if (file-exists-p time-tracker-db-path)
      (progn
        (message "Database file exists, opening connection")
        (condition-case err
            (progn
              (setq time-tracker--db
                    (time-tracker--sqlite-open time-tracker-db-path))
              (message "Database connection established"))
          (error
           (message "Error opening database: %s" (error-message-string err))
           (error "Could not open database: %s" (error-message-string err)))))
    (message "Database file does not exist: %s" time-tracker-db-path)
    (error "Time tracker database file does not exist: %s" time-tracker-db-path)))

(defun time-tracker--connect-projects-db ()
  "Connect to the projects database."
  (when time-tracker--projects-db
    (time-tracker--sqlite-close time-tracker--projects-db))
  (if (file-exists-p time-tracker-projects-db-path)
      (setq time-tracker--projects-db
            (time-tracker--sqlite-open time-tracker-projects-db-path))
    (message "Warning: Projects database file does not exist: %s" time-tracker-projects-db-path)
    (setq time-tracker--projects-db nil)))

(defun time-tracker--ensure-connected ()
  "Ensure database connections are established."
  (message "Ensuring database connections...")
  (message "Current connection status: time-tracker--db=%s, time-tracker--projects-db=%s"
           (if time-tracker--db "connected" "not connected")
           (if time-tracker--projects-db "connected" "not connected"))

  (unless time-tracker--db
    (message "Time tracker database not connected, connecting now...")
    (time-tracker--connect-db))

  (unless time-tracker--projects-db
    (message "Projects database not connected, connecting now...")
    (time-tracker--connect-projects-db))

  (message "Connection check complete: time-tracker--db=%s, time-tracker--projects-db=%s"
           (if time-tracker--db "connected" "not connected")
           (if time-tracker--projects-db "connected" "not connected")))

(defun time-tracker--get-last-entry ()
  "Get information from the most recent entry in the database."
  (time-tracker--ensure-connected)
  (let* ((query (format "SELECT DateDashed, End, ProjectID, ProjectDirectory FROM %s ORDER BY id DESC LIMIT 1"
                        time-tracker-table-name))
         (result (condition-case err
                     (time-tracker--sqlite-select time-tracker--db query)
                   (error
                    (message "Error getting last entry: %s" (error-message-string err))
                    nil))))
    (if result
        (let ((row (car result)))
          `((date . ,(nth 0 row))
            (end-time . ,(nth 1 row))
            (project-id . ,(nth 2 row))
            (project-directory . ,(nth 3 row))))
      `((date . nil)
        (end-time . nil)
        (project-id . nil)
        (project-directory . nil)))))

(defun time-tracker--get-project-directory (project-id)
  "Look up the project directory based on PROJECT-ID from the projects database."
  (time-tracker--ensure-connected)
  (when time-tracker--projects-db
    (let* ((query (format "SELECT ProjectDirectory FROM %s WHERE ProjectID = %s"
                          time-tracker-projects-table-name
                          project-id))
           (result (condition-case err
                       (time-tracker--sqlite-select time-tracker--projects-db query)
                     (error
                      (message "Error querying project database: %s" (error-message-string err))
                      nil))))
      (when result
        (let ((row (car result)))
          (nth 0 row))))))

(defun time-tracker--get-recent-entries ()
  "Get the most recent entries from the database."
  (time-tracker--ensure-connected)
  (let* ((query (format "SELECT * FROM %s ORDER BY id DESC LIMIT %d"
                        time-tracker-table-name
                        time-tracker-recent-entries-limit))
         (result (condition-case err
                     (time-tracker--sqlite-select time-tracker--db query)
                   (error
                    (message "Error getting recent entries: %s" (error-message-string err))
                    nil))))
    result))

(defun time-tracker--get-table-columns ()
  "Get the column names from the time tracker table."
  (time-tracker--ensure-connected)
  (let* ((query (format "PRAGMA table_info(%s)" time-tracker-table-name))
         (result (condition-case err
                     (time-tracker--sqlite-select time-tracker--db query)
                   (error
                    (message "Error getting table columns: %s" (error-message-string err))
                    nil)))
         (columns '()))
    (when result
      (dolist (row result)
        (let ((col-name (nth 1 row))
              (col-type (nth 2 row)))
          (unless (or (string= col-name "id")
                      (and col-type (string-match-p "VIRTUAL" col-type)))
            (push col-name columns))))
      (nreverse columns))))

(defun time-tracker--add-entry (entry-data)
  "Add a new ENTRY-DATA to the database."
  (time-tracker--ensure-connected)
  (let* ((columns (time-tracker--get-table-columns))
         (column-names (s-join ", " columns))
         (placeholders (s-join ", " (make-list (length columns) "?")))
         (values (mapcar (lambda (col) (cdr (assoc (intern col) entry-data))) columns))
         (query (format "INSERT INTO %s (%s) VALUES (%s)"
                        time-tracker-table-name
                        column-names
                        placeholders)))
    (condition-case err
        (progn
          (time-tracker--sqlite-execute time-tracker--db query values)
          ;; Get the last inserted ID (handle both sqlite.el and sqlite3.el)
          (let ((last-id-query "SELECT last_insert_rowid()")
                (last-id nil))
            (setq last-id
                  (if time-tracker--use-sqlite3
                      (caar (time-tracker--sqlite-select time-tracker--db last-id-query))
                    (caar (time-tracker--sqlite-select time-tracker--db last-id-query))))
            (message "Entry added successfully with ID: %s" last-id)))
      (error
       (message "Error adding entry: %s" (error-message-string err))
       nil))))

;;; Display functions

(defun time-tracker--display-recent-entries ()
  "Display the most recent entries in the database."
  (let* ((entries (time-tracker--get-recent-entries))
         (query (format "PRAGMA table_info(%s)" time-tracker-table-name))
         (columns-info (condition-case err
                           (time-tracker--sqlite-select time-tracker--db query)
                         (error
                          (message "Error getting column info: %s" (error-message-string err))
                          nil)))
         (column-names (when columns-info (mapcar (lambda (col) (nth 1 col)) columns-info)))
         (buffer (get-buffer-create "*Time Tracker Entries*")))

    (if (and entries column-names)
        (with-current-buffer buffer
          (erase-buffer)
          (insert "Most recent time entries:\n")
          (insert (make-string 100 ?-) "\n")

          ;; Insert header
          (insert (s-join " | " column-names) "\n")
          (insert (make-string 100 ?-) "\n")

          ;; Insert rows in reverse order (oldest to newest)
          (dolist (row (nreverse entries))
            (insert (s-join " | " (mapcar (lambda (val) (if val (format "%s" val) "")) row)) "\n"))

          (insert (make-string 100 ?-) "\n")
          (display-buffer buffer))
      (message "No entries found or error retrieving data."))))

;;; Interactive functions

(defun time-tracker--read-time (prompt &optional default)
  "Read a time value with PROMPT and DEFAULT, ensuring HH:MM format."
  (let ((time-string (read-string (if default
                                       (format "%s [%s]: " prompt default)
                                     (format "%s: " prompt))
                                  nil nil default)))
    (if (string-empty-p time-string)
        default
      (if (string-match-p "^\\([0-1][0-9]\\|2[0-3]\\):[0-5][0-9]$" time-string)
          time-string
        (user-error "Time must be in HH:MM format")))))

(defun time-tracker--read-date (prompt default)
  "Read a date with PROMPT and DEFAULT, ensuring YYYY-MM-DD format."
  (let ((date-string (read-string (format "%s [%s]: " prompt default)
                                  nil nil default)))
    (if (string-empty-p date-string)
        default
      (if (string-match-p "^[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}$" date-string)
          date-string
        (user-error "Date must be in YYYY-MM-DD format")))))

(defun time-tracker--read-project-id (prompt &optional default)
  "Read a project ID with PROMPT and DEFAULT."
  (let* ((input (read-string (if default
                                 (format "%s [%s]: " prompt default)
                               (format "%s: " prompt))
                             nil nil default))
         (project-id (if (string-empty-p input)
                         default
                       (string-to-number input))))
    (if (= project-id 0)
        (user-error "Project ID must be a valid integer")
      project-id)))

;;;###autoload
(defun time-tracker-add-entry ()
  "Add a new time tracking entry interactively."
  (interactive)

  ;; Ensure we've loaded SQLite support
  (message "Checking for SQLite support...")
  (cond
   ((featurep 'sqlite)
    (message "Found sqlite.el")
    (setq time-tracker--use-sqlite3 nil))
   ((featurep 'sqlite3)
    (message "Found sqlite3.el")
    (setq time-tracker--use-sqlite3 t))
   ((require 'sqlite nil t)
    (message "Loaded sqlite.el")
    (setq time-tracker--use-sqlite3 nil))
   ((require 'sqlite3 nil t)
    (message "Loaded sqlite3.el")
    (setq time-tracker--use-sqlite3 t))
   (t
    (message "No SQLite implementation found")
    (error "SQLite support is required but not available")))

  (message "Database paths: time-tracker-db-path=%s, time-tracker-projects-db-path=%s"
           time-tracker-db-path time-tracker-projects-db-path)

  ;; Ensure database connections
  (message "Connecting to databases...")
  (condition-case err
      (time-tracker--ensure-connected)
    (error
     (message "Database connection error: %s" (error-message-string err))
     (error "Failed to connect to database: %s" (error-message-string err))))

  (message "Displaying recent entries...")
  ;; Display recent entries
  (time-tracker--display-recent-entries)

  (message "Getting last entry info...")
  ;; Get the information from the most recent entry
  (let* ((last-entry (time-tracker--get-last-entry))
         (default-date (or (cdr (assoc 'date last-entry))
                           (format-time-string "%Y-%m-%d")))
         (default-start-time (cdr (assoc 'end-time last-entry)))
         (default-project-id (cdr (assoc 'project-id last-entry)))
         (entry-data '()))

    (message "Collecting entry data...")
    ;; Date (with default as the last entry date or today)
    (push (cons 'DateDashed
                (time-tracker--read-date "Date (YYYY-MM-DD)" default-date))
          entry-data)

    ;; Start time with default as the end time of the last entry
    (push (cons 'Start
                (time-tracker--read-time "Start time (HH:MM)" default-start-time))
          entry-data)

    ;; End time
    (push (cons 'End
                (time-tracker--read-time "End time (HH:MM)" nil))
          entry-data)

    ;; Project ID
    (let ((project-id (time-tracker--read-project-id
                       "Project ID (integer)"
                       (when default-project-id
                         (if (numberp default-project-id)
                             (number-to-string default-project-id)
                           default-project-id)))))
      (push (cons 'ProjectID project-id) entry-data)

      ;; Look up the project directory based on the project ID
      (let ((project-directory (time-tracker--get-project-directory project-id)))
        (if project-directory
            (progn
              (message "Found project directory: %s" project-directory)
              (let ((input (read-string (format "Project Directory [%s]: " project-directory)
                                        nil nil project-directory)))
                (push (cons 'ProjectDirectory (if (string-empty-p input)
                                                 project-directory
                                               input))
                      entry-data)))
          ;; If not found in projects database, use default from last entry if available
          (let ((default-project-directory (cdr (assoc 'project-directory last-entry))))
            (if default-project-directory
                (progn
                  (message "Project ID not found in projects database.")
                  (let ((input (read-string (format "Project Directory [%s]: " default-project-directory)
                                            nil nil default-project-directory)))
                    (push (cons 'ProjectDirectory (if (string-empty-p input)
                                                     default-project-directory
                                                   input))
                          entry-data)))
              (push (cons 'ProjectDirectory (read-string "Project Directory: ")) entry-data))))))

    ;; Description
    (push (cons 'Description (read-string "Description: ")) entry-data)

    ;; Activity with options
    (push (cons 'Activity (completing-read "Activity: "
                                          '("G" "E" "S" "none")
                                          nil nil nil nil "none"
                                          "G generative writing, E editing, S support activity"))
          entry-data)

    (message "Adding entry to database...")
    ;; Add the entry to the database
    (time-tracker--add-entry entry-data)))

;;;###autoload
(defun time-tracker-diagnose ()
  "Run diagnostics on the time-tracker setup."
  (interactive)
  (with-current-buffer (get-buffer-create "*Time Tracker Diagnostics*")
    (erase-buffer)
    (org-mode)
    (insert "* Time Tracker Diagnostics\n\n")

    ;; Check Emacs version
    (insert "** Emacs Version\n")
    (insert (format "Emacs version: %s\n\n" emacs-version))

    ;; Check SQLite support
    (insert "** SQLite Support\n")
    (insert (format "sqlite.el loaded: %s\n" (featurep 'sqlite)))
    (insert (format "sqlite3.el loaded: %s\n" (featurep 'sqlite3)))
    (insert (format "time-tracker--use-sqlite3: %s\n\n" time-tracker--use-sqlite3))

    ;; Check database paths
    (insert "** Database Paths\n")
    (insert (format "time-tracker-db-path: %s\n" time-tracker-db-path))
    (insert (format "Expanded path: %s\n" (expand-file-name time-tracker-db-path)))
    (insert (format "File exists: %s\n\n" (file-exists-p time-tracker-db-path)))

    (insert (format "time-tracker-projects-db-path: %s\n" time-tracker-projects-db-path))
    (insert (format "Expanded path: %s\n" (expand-file-name time-tracker-projects-db-path)))
    (insert (format "File exists: %s\n\n" (file-exists-p time-tracker-projects-db-path)))

    ;; Check table names
    (insert "** Table Names\n")
    (insert (format "time-tracker-table-name: %s\n" time-tracker-table-name))
    (insert (format "time-tracker-projects-table-name: %s\n\n" time-tracker-projects-table-name))

    ;; Try to connect
    (insert "** Connection Test\n")
    (condition-case err
        (progn
          (insert "Attempting to connect to time tracker database...\n")
          (let ((db (if time-tracker--use-sqlite3
                        (sqlite3-open (expand-file-name time-tracker-db-path))
                      (sqlite-open (expand-file-name time-tracker-db-path)))))
            (insert "Connection successful!\n")
            (condition-case err2
                (progn
                  (insert "Attempting to query database...\n")
                  (let ((result (if time-tracker--use-sqlite3
                                    (sqlite3-select db (format "SELECT COUNT(*) FROM %s" time-tracker-table-name))
                                  (sqlite-select db (format "SELECT COUNT(*) FROM %s" time-tracker-table-name)))))
                    (insert (format "Query successful! Found %s entries.\n" (car (car result)))))
                (error (insert (format "Error querying database: %s\n" (error-message-string err2))))))
          (insert "\n"))
      (error (insert (format "Error connecting to database: %s\n\n" (error-message-string err)))))

    ;; Provide recommendations
    (insert "** Recommendations\n")
    (cond
     ((not (or (featurep 'sqlite) (featurep 'sqlite3)))
      (insert "- Install a SQLite package with: M-x package-install RET sqlite RET\n"))
     ((not (file-exists-p time-tracker-db-path))
      (insert (format "- The database file does not exist at: %s\n" time-tracker-db-path))
      (insert "- Check the path or create the database file\n"))
     (t
      (insert "- If you're still having issues, check database permissions\n")
      (insert "- Try using absolute paths instead of relative paths\n")
      (insert "- Check if the SQLite binary is installed on your system\n")))

    (switch-to-buffer-other-window (current-buffer))
    (goto-char (point-min)))))

(provide 'time-tracker)
;;; time-tracker.el ends here
