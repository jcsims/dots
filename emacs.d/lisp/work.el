;;; package --- Summary

;;; Commentary:
;; Code I use for work.

;;; Code:
(eval-after-load 'magit
  (lambda ()
    ;; I so rarely use tags, and this takes ~500ms in a magit buffer on a work
    ;; repo!
    (remove-hook 'magit-status-headers-hook #'magit-insert-tags-header)))

(use-package terraform-mode
  :custom (terraform-format-on-save t))

(use-package cljstyle-format
  :after (clojure-mode)
  :hook (clojure-mode . cljstyle-format-on-save-mode))

(use-package graphql-mode)

(use-package environ)
(use-package splash
  :after cider
  :load-path "/Users/csims/code/work/stonehenge/development/emacs/"
  :custom
  (splash-stonehenge-dir "/Users/csims/code/work/stonehenge/"))

(use-package php-mode
  :hook ((php-mode . eglot-ensure))
  :config
  (setq website-dir (expand-file-name "~/code/work/Website"))

  (defun website-test-class ()
    (interactive)
    (let ((class-path (file-relative-name (buffer-file-name) website-dir)))
      (compile (concat "docker exec -t app php artisan test " class-path))))

  (defun website-test-method ()
    (interactive)
    (let ((class-path (file-relative-name (buffer-file-name) website-dir))
          (filter (thing-at-point 'symbol)))
      (compile (concat "docker exec -t app php artisan test " class-path " --filter " filter))))

  (defun website-test-case (case)
    (interactive
     (list
      (let* ((prompt "Run case: ")
             (input (read-from-minibuffer prompt nil nil nil nil)))
        input)))
    (let ((class-path (file-relative-name (buffer-file-name) website-dir))
          (filter (thing-at-point 'symbol))
          (escaped-case
           (replace-regexp-in-string (regexp-quote "$") "\\$" case nil
                                     'literal)))
      (compile (concat "docker exec -t app php artisan test " class-path " --filter " filter "@'" escaped-case "'")))))

(use-package ob-php
  :after ob
  :config (org-babel-do-load-languages 'org-babel-load-languages
				       '((php . t))))

(eval-and-compile ;; Borrowed from https://xenodium.com/building-your-own-bookmark-launcher/
  (require 'org-roam-id)
  (require 'org-element)
  (require 'seq)

  (defun browser-bookmarks (org-file)
    "Return all links from ORG-FILE."
    (with-temp-buffer
      (let (links)
        (insert-file-contents org-file)
        (org-mode)
        (org-element-map (org-element-parse-buffer) 'link
          (lambda (link)
            (let* ((raw-link (org-element-property :raw-link link))
                   (content (org-element-contents link))
                   (title (substring-no-properties (or (seq-first content) raw-link))))
	      (push (concat title
                            " | "
                            (propertize raw-link 'face 'whitespace-space))
                    links)))
          nil nil 'link)
        (seq-sort 'string-greaterp links))))

  (comment
   (benchmark-run 1
     (browser-bookmarks
      (car (org-roam-id-find "DECD703F-028C-4414-ADAD-0910F8283CD8")))))

  (defun open-bookmark ()
    (interactive)
    (browse-url (seq-elt
                 (split-string
                  (completing-read "Open: "
                                   (browser-bookmarks
                                    (car (org-roam-id-find "DECD703F-028C-4414-ADAD-0910F8283CD8"))))
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
       ;; (set-face-attribute 'ivy-current-match frame
       ;;                     :background "#2a2a2a"
       ;;                     :foreground 'unspecified)
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

(provide 'work)
;;; work.el ends here
