;;; script.lisp
;;; SPDX-License-Identifier: MIT
;;;
;;; Copyright (C) 2026 Colin Loeffler (that1guycolin)

;;; Script to download videos defined in a valid `links.lisp` file. Usage:
;;;     sbcl --script script.lisp links.lisp
;;; where `links.lisp` is the path to the file containing
;;; "lvl:remote-video-object"s.

(let ((file (car (uiop:command-line-arguments))))

  ;; Make sure argument was provided
  (unless (boundp file)
    (sb-int:simple-parse-error "No argument provided
Usage: sbcl --script script.lisp FILE"))

  ;; Ensure FILE exists
  (unless (uiop:file-exists-p file)
    (file-error "~A does not exist" file))

  ;; Process FILE
  (asdf:load-system "lisp-video-library")
  (lvl:script/process-file file))
