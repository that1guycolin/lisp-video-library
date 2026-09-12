## Lisp-Video-Library

Manage your media library or download videos with cl.

**Note:** This project is under active development, as is this README.

### Downloading videos with a script

You will need a .lisp file of the following format.

```lisp
(
 (:status :todo ;; (always set the status as :todo)
	  :method ;; (one of :ffmpeg :streamlink :aria2 :yt-dlp :convert)
	  :url "https://the.videos/url"
	  :title "The title of the Video"
	  :artist "Actors appearing in the video"
	  :album "Main production studio")
 (:status :todo
	  :method :aria2
	  :url "https://fantastic.mr.fox"
	  :title "Fantastic Mr. Fox"
	  :artist "George Clooney; Meryl Streep"
	  :album "20th Century Fox")
 )
```

(NOTE: throughout the documentation, I'll refer to this file as `links.lisp`,
but you can call it whatever you want.)

```shell
sbcl --script src/downloader-script.lisp links.lisp
# Or, more simply:
./batch-video-download links.lisp
```

Emacs users may find the `easy-link.el` file useful for creating links files.

```elisp
;;; In Emacs M-:
(require 'easy-link.el) ;; RET
;; Then: M-x easy-link-insert-video RET
```

### Downloading videos in a lisp REPL (sly/slime)

```lisp
(require "asdf")
(asdf:load-system "lisp-video-library")
(iav) ;; Add videos interactively
(download-queued-videos) ;; Download the videos
```

### Author and License

`lisp-video-library` was written by Colin Loeffler (that1guycolin) and is
distributed under the terms of the MIT license.
