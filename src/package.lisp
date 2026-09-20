;;; package.lisp
;;;
;;; SPDX-License-Identifier: MIT
;;;
;;; Copyright (C) 2026 Colin Loeffler (that1guycolin)

(defpackage #:lvl
  (:use #:cl)
  (:documentation "Manage the videos in your media library with cl.")
  (:import-from #:str #:trim #:split #:concat)
  (:export #:*remote-video-objects* #:*local-video-objects*
           #:set-local-variables #:iav #:add-remote-video
           #:download-queued-videos #:script/process-file))

(in-package #:lvl)
