;;; lisp-video-library.asd
;;;
;;; SPDX-License-Identifier: MIT
;;;
;;; Copyright (C) 2026 Colin Loeffler (that1guycolin)

(asdf:defsystem "lisp-video-library"
  :description "Manage the videos in your media library with cl."
  :author      "Colin Loeffler (that1guycolin)"
  :license     "MIT"
  :version     "0.1.0"
  :depends-on  ("str")
  :components ((:file "src/package")
               (:file "src/main"
                :depends-on ("src/package"))))

