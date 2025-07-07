;;; package --- Summary

;;; Commentary:
;; Code to display a lightweight frame for fuzzily completing bookmarks.

;;; Code:
(eval-and-compile ;; Borrowed from https://xenodium.com/building-your-own-bookmark-launcher/
  (require 'seq)
  (require 'work-bookmarks)
  (require 'personal-bookmarks)

  (defun browser-bookmarks (bookmarks-var)
    "Return all bookmarks defined in BOOKMARKS-VAR"
    (let (links)
      (-map (lambda (link-cons)
	      (push (concat (car link-cons) " | " (cdr link-cons))
		    links))
	    bookmarks-var)
      (seq-sort 'string-greaterp links)))

  (comment
   (benchmark-run 1
     (browser-bookmarks work-bookmarks)))

  (defun open-bookmark ()
    (interactive)
    (browse-url (seq-elt
                 (split-string
                  (completing-read "Open: "
                                   (browser-bookmarks (if work-install
							  work-bookmarks
							personal-bookmarks)))
                  " | ")
                 1)))

  ;; TODO: Bind escape to close the minibuffer
  (defmacro present (&rest body)
    "Create a buffer with BUFFER-NAME and eval BODY in a basic frame."
    (declare (indent 1) (debug t))
    `(let* ((buffer (get-buffer-create (generate-new-buffer-name "*present*")))
            (frame (make-frame '((auto-raise . t)
                                 (font . "Hack Nerd Font 15")
                                 (top . 200)
                                 (height . 13)
                                 (width . 110)
                                 (internal-border-width . 20)
                                 (left . 0.33)
                                 (left-fringe . 0)
                                 (line-spacing . 3)
                                 (menu-bar-lines . 0)
                                 (minibuffer . only)
                                 (right-fringe . 0)
                                 (tool-bar-lines . 0)
                                 (undecorated . t)
                                 (unsplittable . t)
                                 (vertical-scroll-bars . nil)))))
       (select-frame frame)
       (select-frame-set-input-focus frame)
       (with-current-buffer buffer
         (condition-case nil
             (unwind-protect
                 ,@body
	       (delete-frame frame)
	       (kill-buffer buffer))
           (quit (delete-frame frame)
                 (kill-buffer buffer))))))

  (defun present-open-bookmark-frame ()
    (present (open-bookmark))))

(provide 'bookmark-frame)
;;; bookmark-frame.el ends here
