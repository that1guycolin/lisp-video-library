;;; lvl-remote-video.el --- EZ Lisp Links -*- lexical-binding: t -*-

;; Author: Colin Loeffler
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.01"))
;; Homepage: https://github.com/that1guycolin/lisp-video-library
;; Keywords: lisp multimedia

;; This file is not part of GNU Emacs

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; Easily create a Lisp object that can be used by downloader.lisp.

;;; Code:
(defun easy-link-insert-video (url method title artist studio)
  "Create a link block for use with lisp-video-library downloader.lisp.
Requires URL (link to video (not website link)); METHOD by which video
will be downloaded, options are ffmpeg, yt-dlp, streamlink, aria2, or convert;
TITLE of the video; video ARTIST and video STUDIO."
  (interactive
   (list
    (read-string "URL: ")
    (completing-read "Method: " '(:ffmpeg :yt-dlp :streamlink :aria2
                                          :convert))
    (read-string "Title: ")
    (read-string "Artist: ")
    (read-string "Studio: ")))

  (insert "(#S(lvl:remote-video-object"
          "\n:status :todo"
          "\n:method " method
          "\n:url \"" url "\""
          "\n:title \"" title "\""
          "\n:artist \"" artist "\""
          "\n:studio \"" studio "\"))"))


(provide 'lvl-remote-video)
;;; lvl-remote-video.el ends here
