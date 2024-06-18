;;; alejandra-format.el --- Format nix files using alejandra

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
;; formatting for nix-mode files, using alejandra.

;;; Code:

(use-package reformatter)

(defgroup alejandra-format nil
  "Nix file formatting using Alejandra."
  :group 'nix)

(defcustom alejandra-format-command
  "alejandra"
  "Name of the alejandra executable."
  :group 'alejandra-format
  :type 'string)

(defcustom alejandra-format-arguments
  '("-q" "--" "-")
  "Arguments to pass to alejandra."
  :group 'alejandra-format
  :type '(repeat string))

;;;###autoload (autoload 'alejandra-format-buffer "alejandra-format" nil t)
;;;###autoload (autoload 'alejandra-format-region "alejandra-format" nil t)
;;;###autoload (autoload 'alejandra-format-on-save-mode "alejandra-format" nil t)
(reformatter-define
  alejandra-format
  :program alejandra-format-command
  :args alejandra-format-arguments
  :lighter " alejandra"
  :group 'alejandra-format)

(provide 'alejandra-format)

;;; alejandra-format.el ends here
