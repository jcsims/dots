;;; php-cs-fixer-format.el --- Format PHP files using php-cs-fixer

;; Copyright (C) 2024 Chris Sims <chris@jcsi.ms>

;; Author: Chris Sims <chris@jcsi.ms>
;; Package-Requires: ((emacs "24.4") (reformatter "0.7"))
;; Package-Version: TODO
;; Keywords: formatting
;; URL: TODO
;; Version: 0.1

;; This program is free software; you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free Software
;; Foundation; either version 2 of the License, or (at your option) any later
;; version.

;; This program is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;; FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
;; details.

;; You should have received a copy of the GNU General Public License along with
;; this program; if not, write to the Free Software Foundation, Inc., 51
;; Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

;;; Commentary:

;; This is a simple package making use of reformatter to provide on-save buffer
;; formatting for php-mode files, using php-cs-fixer.

;;; Code:

(require 'reformatter)

(defgroup php-cs-fixer-format nil
  "PHP file formatting using php-cs-fixer."
  :group 'php)

(defcustom php-cs-fixer-format-command
  "php-cs-fixer"
  "Name of the php-cs-fixer executable."
  :group 'php-cs-fixer-format
  :type 'string)

(defcustom php-cs-fixer-format-arguments
  nil
  "Arguments to pass to php-cs-fixer."
  :group 'php-cs-fixer-format
  :type '(repeat string))

;;;###autoload (autoload 'php-cs-fixer-format-buffer "php-cs-fixer-format" nil t)
;;;###autoload (autoload 'php-cs-fixer-format-region "php-cs-fixer-format" nil t)
;;;###autoload (autoload 'php-cs-fixer-format-on-save-mode "php-cs-fixer-format" nil t)
(reformatter-define
  php-cs-fixer-format
  :program php-cs-fixer-format-command
  :stdin nil
  :stdout nil
  :args (append '("fix" "-q") php-cs-fixer-format-arguments (list input-file))
  :lighter " php-cs-fixer"
  :group 'php-cs-fixer-format)

(provide 'php-cs-fixer-format)

;;; php-cs-fixer-format.el ends here
