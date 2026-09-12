;;; main.lisp
;;;
;;; SPDX-License-Identifier: MIT
;;;
;;; Copyright (C) 2026 Colin Loeffler (that1guycolin)

(in-package #:lvl)

;;; Define objects & types
(defstruct remote-video-object
  status
  url
  method
  title
  artist
  studio)

(deftype download-status ()
  '(member :todo :done))

(deftype download-method ()
  '(member :yt-dlp :ffmpeg :streamlink :aria2 :convert))

(defparameter *remote-video-objects* '()
  "List of objects mapping video URLs to metadata about the video.
Each item contains the following keys:
`:status' - Always set to `:todo' (automatic when working in REPL).
            When a video downloads successfully, the value of this key is
            automatically updated to `:done'. In an REPL, the updated status is
            written to *logfile*, in a script, it's written to the file
            provided as an argument.
`:url'    - String containing the video URL.
            (TIP: Unless `:method' is `:yt-dlp', copying the url directly from
            the address bar will not work.)
`:method' - One of `:yt-dlp', `:ffmpeg', `:streamlink', `:aria2', `:convert'.
            Specifies the tool with which to process the video.
`:title'  - String containing the video title.
`:artist' - String containing actors in the video, separated by semi-colons.
            Example: \"Meryl Streep; George Clooney\"
`:studio' - String containing the production studio")

(defstruct local-video-object
  path
  title
  artist
  studio)

(defparameter *local-video-objects* '()
  "List of objects mapping local videos to their metadata.
Each item contains the following keys:
`:path'   - Full path to the video.
`:title'  - String containing the video title.
`:artist' - Semicolon-separated string of performers.
            Example: \"Meryl Streep; George Clooney\"
`:studio' - String containing the production studio.")

(defvar *db-extension* ".lvl.db.lisp"
  "Extension for database files containing *local-video-objects*.")

(defparameter *queue-lock* (sb-thread:make-mutex :name "download-queue-lock"))

(defvar *download-directory* (uiop:native-namestring "~/Videos/New/")
  "Directory into which videos are downloaded.")

(defvar *logfile* (uiop:native-namestring
                   (concat *download-directory* "downloaded_vids.txt"))
  "Information on the videos processed/downloaded is saved to this file.")


;;; Logfile functions
(defun new-video-to-logfile (rvo)
  "Write a `remote-video-object' (RVO) to `*logfile*'."
  (with-open-file
      (out *logfile*
           :direction :output
           :if-exists :append
           :if-does-not-exist :create)
    (with-standard-io-syntax (print rvo out))))

(defun remote-video-objects-same-url-p (rvo1 rvo2)
  "Return true if two `remote-video-objects' have the same URL."
  (let ((u1 (remote-video-object-url rvo1))
        (u2 (remote-video-object-url rvo2)))
    (string= u1 u2)))

(defun remote-objects-from-logfile ()
  "Read all `remote-video-objects' from `*logfile*'."
  (with-open-file
      (in *logfile*
          :direction :input
          :if-does-not-exist nil)
    (when in
      (with-standard-io-syntax
        (loop for obj = (read in nil :eof)
              until (eq obj :eof)
              when (remote-video-object-p obj)
                collect obj)))))

(defun update-logfile (rvo)
  "Update `*logfile*' with RVO, overwriting any existing entry for that video."
  (let* ((existing-objects (remote-objects-from-logfile))
         (found nil)
         (updated-objects
           (mapcar (lambda (obj)
                     (if (remote-video-objects-same-url-p obj rvo)
                         (progn (setf found t) rvo)
                         obj))
                   existing-objects)))
    (unless found
      (setf updated-objects (append updated-objects (list rvo))))
    (with-open-file
        (out *logfile*
             :direction :output
             :if-exists :supersede
             :if-does-not-exist :create)
      (with-standard-io-syntax
        (dolist (obj updated-objects)
          (print obj out))))))


;;; Queue Video Functions
(defun add-remote-video (method url title artist studio)
  "Prepare an online video to be downloaded.
Add the video to *remote-video-objects*. Basic video metadata is required as it
allows for proper saving & filing of the video."
  (check-type method download-method)
  (sb-thread:with-mutex (*queue-lock*)
    (let ((new-object
            (make-remote-video-object
             :status :todo
             :method method
             :url    url
             :title  title
             :artist artist
             :studio studio)))
      (unless (member new-object *remote-video-objects*)
        (pushnew new-object *remote-video-objects*)
        (new-video-to-logfile new-object)))))

(defun method-string-to-object (string)
  "When adding a video interactively, all user-input is returned as a string.
The `:method' field requires a type-validated object, so this function converts
the user-input string to an object."
  (cond
    ((or (string-equal string "yt-dlp")     (string-equal string ":yt-dlp"))
     :yt-dlp)
    ((or (string-equal string "ffmpeg")     (string-equal string ":ffmpeg"))
     :ffmpeg)
    ((or (string-equal string "streamlink") (string-equal string ":streamlink"))
     :streamlink)
    ((or (string-equal string "aria2")      (string-equal string ":aria2"))
     :aria2)
    ((or (string-equal string "convert")    (string-equal string ":convert"))
     :convert)
    (t (error "Unknown method: ~A" string))))

(defun iav ()
  "IAV is short for \"interactively-add-video\".
Prompt the user for the five properties required for a `remote-video-object',
then create the object and add it to *remote-video-objects* via the
`add-remote-video' function."
  (let ((method (progn (format t "Method: ") (finish-output)
                       (method-string-to-object              (read-line))))
        (url    (progn (format t "URL: ")    (finish-output) (read-line)))
        (title  (progn (format t "Title: ")  (finish-output) (read-line)))
        (artist (progn (format t "Artist: ") (finish-output) (read-line)))
        (studio (progn (format t "Studio: ") (finish-output) (read-line))))
    (add-remote-video method url title artist studio)))


;;; File Operations
(defun ensure-db-extension (file)
  "Ensure FILE ends with *db-extension*."
  (unless (uiop:string-suffix-p file *db-extension*)
    (error "~A does not end with ~A" file *db-extension*)))

(defun ensure-directory-/ (dir)
  "Ensure that DIR ends with a backslash."
  (if (uiop:string-suffix-p dir "/")
      dir
      (concatenate 'string dir "/")))

(defun get-title-from-file (file)
  "Return a video title no matter what.
First, try to use exiftool to get the title field from a video's metadata. If
that fails, generate a title based on the filename."
  (let* ((filepath (uiop:native-namestring file))
         (exif-title
           (trim (uiop:run-program
                  (list "exiftool" "-s3" "-title" filepath) :output :string)))
         (file-title
           (file-namestring (make-pathname :type nil :defaults filepath))))
    (if exif-title exif-title file-title)))

(defun make-local-video-object-from-file (file)
  "Manually add a local file to *local-video-objects*."
  (let* ((path   (uiop:native-namestring file))
         (title  (get-title-from-file path))
         (artist (trim (uiop:run-program (list "exiftool" "-s3" "-artist" path)
                                         :output :string)))
         (studio (trim (uiop:run-program (list "exiftool" "-s3" "-album" path)
                                         :output :string)))
         (local-object (make-local-video-object
                        :path   path
                        :title  title
                        :artist artist
                        :studio studio)))
    (unless (member local-object *local-video-objects*)
      (pushnew local-object *local-video-objects*))))

(defun save-local-videos (dbfile)
  "Save all current *local-video-objects* to DBFILE."
  (ensure-db-extension dbfile)
  (with-open-file
      (out dbfile
           :direction :output
           :if-exists :append
           :if-does-not-exist :create)
    (with-standard-io-syntax (print *local-video-objects* out))))

(defun smart-move-file (src dest)
  "Attempt a fast OS-level rename.
Fall back to a copy-and-delete strategy if a filesystem error occurs."
  (handler-case (rename-file src dest)
    (file-error ()
      (uiop:copy-file src dest)
      (delete-file src))))

(defun move-video (obj dir)
  "Act on a local-video-object.
Move the video from its current `:path' to a standard media library
folder-structure with DIR as root. If the object was a member of
*local-video-objects*, update the value of `:path' to its new path. If it was
not a member, add it to *local-video-objects*."
  (let* ((old-path  (local-video-object-path   obj))
         (ext       (pathname-type        old-path))
         (studio    (local-video-object-studio obj))
         (title     (local-video-object-title  obj))
         (clean-dir (uiop:native-namestring dir))
         (new-dir
           (concatenate 'string clean-dir "/" studio "/" title "/"))
         (new-path (concatenate 'string new-dir title "." ext)))
    (unless (equal old-path new-path)
      (ensure-directories-exist new-dir)
      (smart-move-file old-path new-path)
      (if (member obj *local-video-objects*)
          (setf (local-video-object-path obj) new-path)
          (pushnew obj *local-video-objects*)))))

(defun move-local-video-objects (dir)
  "Move all videos from *local-video-objects* to DIR via `move-video'."
  (ensure-directory-/ dir)
  (dolist (obj *local-video-objects*)
    (move-video obj (uiop:native-namestring dir)))
  (let ((local-db (concatenate 'string dir *db-extension*)))
    (save-local-videos local-db)))

;;; Directory Operations
(defun get-directory-videos (dir)
  "Return all .mp4 files in DIR."
  (let ((safe-dir (ensure-directory-/ dir)))
    (uiop:directory-files safe-dir "*.mp4")))

(defun save-videos-in-directory (dir db)
  "Save all videos in DIR to a specified DB file."
  (ensure-db-extension db)
  (let ((vid-objs '()))
    (dolist (vid (get-directory-videos dir))
      (pushnew (make-local-video-object-from-file vid) vid-objs))
    (with-open-file
        (out db
             :direction :output
             :if-exists :append
             :if-does-not-exist :create)
      (with-standard-io-syntax (print vid-objs out)))))

(defun ensure-directory-video-objects (dir)
  "Check if each .mp4 file in DIR is a member of *local-video-objects*.
If it is not, add it."
  (let* ((clean-dir (ensure-directory-/ dir))
         (vids (uiop:directory-files clean-dir "*.mp4")))
    (dolist (vid vids)
      (pushnew
       (make-local-video-object-from-file vid) *local-video-objects*))))

(defun move-all-in-directory (old-dir new-dir)
  "Move all videos in OLD-DIR to root NEW-DIR via `move-video'."
  (let* ((cln-old (ensure-directory-/ old-dir))
         (vids (uiop:directory-files cln-old "*.mp4"))
         (cln-new (uiop:native-namestring new-dir)))
    (dolist (vid vids)
      (let ((obj (make-local-video-object-from-file vid)))
        (move-video obj cln-new)))))


;;; Add Metadata Functions
(defun add-metadata-from-object (obj)
  "Use AtomicParsley to add metadata to a video file.
Uses the metadata contained in the video's `local-video-object'."
  (uiop:run-program
   (list "atomicparsley" (local-video-object-path obj)
         "--artist"      (local-video-object-artist obj)
         "--album"       (local-video-object-studio obj)
         "--title"       (local-video-object-title obj)
         "--overWrite")
   :output :interactive
   :error-output :interactive))

(defun add-metadata-from-filename (file)
  "Use AtomicParsley to add id3 metadata to FILE based on its filename.
Function assumes filename is formatted \"ARTIST - ALBUM - TITLE.ext\"."
  (let* ((filename (pathname-name file))
         (filepath (uiop:native-namestring file))
         (str-list (split " - " filename :omit-nulls t)))
    (destructuring-bind (artist studio title) str-list
      (uiop:run-program
       (list "atomicparsley" filepath "--artist" artist "--album" studio
             "--title" title "--overWrite")
       :output :interactive
       :error-output :interactive))))

(defun add-custom-metadata (file &key artist studio title)
  "Use AtomicParsley to add id3 metadata to FILE.
ARTIST, STUDIO, and TITLE are all possible metadata fields."
  (let ((filepath (uiop:native-namestring file)))
    (when artist
      (uiop:run-program
       (list "atomicparsley" filepath "--artist" artist "--overWrite")
       :output :interactive :error-output :interactive))
    (when studio
      (uiop:run-program
       (list "atomicparsley" filepath "--album"  studio "--overWrite")
       :output :interactive :error-output :interactive))
    (when title
      (uiop:run-program
       (list "atomicparsley" filepath "--title"  title  "--overWrite")
       :output :interactive :error-output :interactive))))


;;; Download Video Methods
(defun download-with-yt-dlp (video-url outfile)
  "Downloads VIDEO-URL using yt-dlp, and saves as OUTFILE."
  (format t "~&--- Starting Download ---~%")
  (format t "URL: ~A~%" video-url)
  (format t "Saving as: ~A~%" outfile)
  (uiop:run-program
   (list "yt-dlp" "-o" outfile video-url)
   :output :interactive
   :error-output :interactive))

(defun download-with-ffmpeg (video-url outfile)
  "Download an m3u8 or hls VIDEO-URL using FFmpeg, and saves\ as OUTFILE."
  (format t "~&--- Starting Download ---~%")
  (format t "URL: ~A~%" video-url)
  (format t "Saving as: ~A~%" outfile)
  (uiop:run-program
   (list "ffmpeg" "-hide_banner"
         "-protocol_whitelist" "file,http,https,tls,hls,tcp"
         "-v" "quiet" "-stats" "-i" video-url
         "-map" "0:v" "-map" "0:a" "-c" "copy"
         "-movflags" "+faststart" outfile)
   :output :interactive
   :error-output :interactive))

(defun download-with-streamlink (manifest-url outfile)
  "Download stream at MANIFEST-URL using streamlink.
Streamlink saves the output to a temporary .ts file, which FFmpeg then converts to OUTFILE."
  (format t "~&--- Starting Download ---~%")
  (format t "URL: ~A~%" manifest-url)
  (format t "Saving as: ~A~%" outfile)
  (let ((ts-file (concatenate 'string *download-directory* "temp.ts")))
    (uiop:run-program
     (list "streamlink" "-l" "none" "--force" "-o" ts-file "--url" manifest-url
           "--default-stream" "best")
     :output :interactive
     :error-output :interactive)
    (uiop:run-program
     (list "ffmpeg" "-hide_banner" "-v" "quiet" "-stats" "-f" "mpegts"
           "-i" ts-file "-map" "0:v" "-map" "0:a" "-c" "copy"
           "-movflags" "+faststart" outfile)
     :output :interactive
     :error-output :interactive)
    (uiop:delete-file-if-exists ts-file)))

(defun download-with-aria2 (video-url outfilename)
  "Download VIDEO-URL with aria2. Save to `*download-directory*' as OUTFILENAME."
  (format t "~&--- Starting Download ---~%")
  (format t "URL: ~A~%" video-url)
  (format t "Saving as: ~A~%"
          (concatenate 'string *download-directory* outfilename))
  (uiop:run-program
   (list "aria2c" "--max-connection-per-server=4" "--min-split-size=1M"
         "-d" *download-directory* "-o" outfilename video-url)
   :output :interactive
   :error-output :interactive))

(defun convert-video (input outfile)
  "Use ffmpeg to convert a .ts file (INPUT) to .mp4 (OUTFILE)."
  (format t "~&--- Starting Conversion ---~%")
  (format t "Source: ~A~%" input)
  (format t "Target: ~A~%" outfile)
  (uiop:run-program
   (list "ffmpeg" "-hide_banner" "-v" "quiet" "-stats"
         "-i" input "-map" "0:v" "-map" "0:a" "-c" "copy"
         "-movflags" "+faststart" outfile)
   :output :interactive
   :error-output :interactive))


;;; General Download Functions
(defun download-video (obj &optional script)
  "Download a remote video.  This function takes a remote video object as its
  only argument.  It uses the `:method' & `:link' fields to download the video,
  saving it to the `*download-directory*' as \"{title}.mp4\".  If `script' is
  non-nil, the function has been called from the download.lisp script; each
  *remote-video-objects*' `:status' value is updated to `:done'."
  (let* ((method   (remote-video-object-method obj))
         (link     (remote-video-object-url obj))
         (title    (remote-video-object-title obj))
         (filename (concatenate 'string title ".mp4"))
         (dir      *download-directory*)
         (file     (concatenate 'string dir filename))
         (artist   (remote-video-object-artist obj))
         (studio   (remote-video-object-studio obj))
         (local-object
           (make-local-video-object
            :path file :title title :artist artist :studio studio)))
    (handler-case
        (progn
          (case method
            (:yt-dlp     (download-with-yt-dlp     link file))
            (:ffmpeg     (download-with-ffmpeg     link file))
            (:streamlink (download-with-streamlink link file))
            (:aria2      (download-with-aria2      link filename))
            (:convert    (convert-video            link file))
            (otherwise   (error "Unknown method: ~A" method)))
          (setf (remote-video-object-status obj) :done)
          (add-metadata-from-object local-object)
          (pushnew local-object *local-video-objects*)
          (unless script (update-logfile obj)))
      (error (e)
        (format t "Download failed for ~A: ~A~%" link e)))))

(defun script/save-links (file)
  "Write the contents of *remote-video-objects* to FILE."
  (with-open-file (out file
                       :direction :output
                       :if-exists :supersede
                       :if-does-not-exist :create)
    (print *remote-video-objects* out)))

(defun script/process-file (file)
  "Process & download video objects from FILE.
When finished, set the status of the object to `:done' and save back to FILE."
  (if (null file)
      (format t "Usage: downloader-script.lisp <links-file>~%")
      (if (probe-file file)
          (progn
            (setf *remote-video-objects*
                  (with-open-file (in file)
                    (read in)))
            (dolist (object *remote-video-objects*)
              (download-video object t))
            (script/save-links file)
            (save-local-videos
             (concatenate 'string (uiop:getcwd) *db-extension*)))
          (format t "File '~a' does not exist.~%" file))))

(defun download-queued-videos ()
  "Start a background thread to process the download queue asynchronously."
  (sb-thread:make-thread
   (lambda ()
     (loop
       (let ((video (sb-thread:with-mutex (*queue-lock*)
                      (first (last *remote-video-objects*)))))
         (cond
           (video
            (progn
              (setf *remote-video-objects* (nbutlast *remote-video-objects*))
              (download-video video)))
           (t (sleep 1))))))
   :name "download-worker"))

                                        ; LocalWords:  Clooney iav
