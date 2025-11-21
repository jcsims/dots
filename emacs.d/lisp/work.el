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

(use-package apheleia
  :hook clojure-mode)

(use-package bazel
  :custom
  (bazel-buildifier-before-save t)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '((bazel-mode bazel-build-mode bazel-workspace-mode) . ("bazel-lsp")))))

(use-package graphql-mode)

(use-package environ)
(use-package splash
  :load-path "/Users/csims/code/work/stonehenge/development/emacs/"
  :custom
  (splash-stonehenge-dir "/Users/csims/code/work/stonehenge/")
  (splash-website-dir "/Users/csims/code/work/Website/"))

(use-package php-cs-fixer-format
  :load-path "./lisp"
  :custom (php-cs-fixer-format-arguments '("--config=/Users/csims/code/work/Website/.php-cs-fixer.php"))
  :hook ((php-mode) . php-cs-fixer-format-on-save-mode))

(use-package php-mode
  :hook (php-mode . eglot-ensure)
  :bind
  (:map php-mode-map
        ("C-c C-t C-n" . splash-website-test-class)
        ("C-c C-t C-t" . splash-website-test-method)))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(php-mode . ("intelephense" "--stdio"))))

(use-package ob-php
  :after ob
  :config (org-babel-do-load-languages 'org-babel-load-languages
                                       '((php . t))))

(use-package typescript-ts-mode
  :ensure f
  :hook ((typescript-ts-mode . eglot-ensure)))

(use-package obsidian
  :demand t
  :custom (obsidian-directory "~/notes/splash")
  :config
  (global-obsidian-mode)

  (require 'dash)
  (require 's)
  (require 'seq)
  (defun jcs/open-todays-meeting ()
    "Open an Obsidian meeting note from today."
    (interactive)
    (let* ((today-string (format-time-string "%Y-%m-%d"))
           (meeting-dir (expand-file-name "meetings" obsidian-directory))
           (choices (->> (directory-files-recursively meeting-dir "\.*.md$")
                         (seq-filter #'obsidian-file-p)
                         (seq-map (lambda (f) (file-relative-name f meeting-dir)))
                         (seq-filter (lambda (f) (s-starts-with? today-string f))))))
      (if choices
	  (let* ((file-name (completing-read "Select file: " choices)))
	    (message "Opening %s" file-name)
            (obsidian-find-file file-name))
        (message "No meeting files for today.")))))

(provide 'work)
;;; work.el ends here
