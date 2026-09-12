;;; downloader-script.lisp
;;;
;;; SPDX-License-Identifier: MIT
;;;
;;; Copyright (C) 2026 Colin Loeffler (that1guycolin)

(in-package #:lisp-video-library)

(let* ((args (uiop:command-line-arguments))
       (data-file (pathname (first args))))
  (if (null data-file)
      (format t "Usage: downloader.lisp <links-file>~%")
      (script/process-file *data-file*)))
