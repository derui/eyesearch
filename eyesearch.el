;;; eyesearch.el --- Visible-window-first isearch  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 derui

;; Author: derui
;; Version: 0.2.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience, search
;; URL: https://github.com/derui/eyesearch

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
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

;; EyeSearch enhances isearch by prioritizing matches visible in the
;; current window.  When you start searching, the first match jumped to
;; is the closest one to your cursor within the visible window.  If no
;; match is visible, it falls back to standard isearch behavior.
;;
;; This uses `isearch-search-fun-function', the official isearch
;; extension point.  All other isearch behavior (C-s/C-r cycling,
;; keybindings, regexp support) remains unchanged.

;;; Code:

(defgroup eyesearch nil
  "Visible-window-first isearch."
  :group 'isearch
  :prefix "eyesearch-")

(defvar-local eyesearch--original-search-fun nil
  "The original value of `isearch-search-fun-function' before eyesearch.")

(defvar-local eyesearch--last-string ""
  "The isearch string from the previous search-fun call.
Used to distinguish typing (string changed) from C-s/C-r repeat (string same).")

(defun eyesearch--find-closest-visible (string search-fun)
  "Find the closest visible match for STRING using SEARCH-FUN.
Scans the visible window for all matches and returns the position
of the match-end closest to point, or nil if none found.
Sets `match-data' to the closest match."
  (let ((win-end (window-end nil t))
        (origin (point))
        (closest-pos nil)
        (closest-dist most-positive-fixnum)
        (closest-match-data nil)
        (case-fold-search isearch-case-fold-search))
    (save-excursion
      (goto-char (window-start))
      (while (and (funcall search-fun string win-end t)
                  (<= (point) win-end))
        (let* ((match-start (match-beginning 0))
               (dist (abs (- match-start origin))))
          (when (< dist closest-dist)
            (setq
             closest-pos (point)
             closest-dist dist
             closest-match-data (match-data))))))
    (when closest-pos
      (set-match-data closest-match-data))
    closest-pos))

(defun eyesearch--make-search-fun (default-search-fun)
  "Return a search function that tries visible window first.
DEFAULT-SEARCH-FUN is the standard search function (e.g. `search-forward')."
  (lambda (string &optional bound noerror count)
    (if (and (not (string= string eyesearch--last-string))
             (not bound))
        ;; User is typing: search visible window first
        (let ((visible-pos
               (eyesearch--find-closest-visible
                string default-search-fun)))
          (setq eyesearch--last-string string)
          (if visible-pos
              (progn
                (goto-char visible-pos)
                (point))
            ;; No visible match, fall back to default
            (funcall default-search-fun string bound noerror count)))
      ;; C-s/C-r repeat or bounded search: default behavior
      (funcall default-search-fun string bound noerror count))))

(defun eyesearch--search-fun-function ()
  "Return the eyesearch search function for isearch.
This wraps the default search function to try visible matches first."
  (let ((default-fun
         (if eyesearch--original-search-fun
             (funcall eyesearch--original-search-fun)
           (isearch-search-fun-default))))
    (eyesearch--make-search-fun default-fun)))

(defun eyesearch--isearch-start ()
  "Reset state when isearch starts."
  (setq eyesearch--last-string ""))

(defun eyesearch--isearch-end ()
  "Clean up when isearch ends."
  (setq eyesearch--last-string ""))

(defun eyesearch--setup ()
  "Set up eyesearch in the current buffer."
  (setq eyesearch--original-search-fun isearch-search-fun-function)
  (setq-local isearch-search-fun-function
              #'eyesearch--search-fun-function)
  (add-hook 'isearch-mode-hook #'eyesearch--isearch-start nil t)
  (add-hook 'isearch-mode-end-hook #'eyesearch--isearch-end nil t))

(defun eyesearch--teardown ()
  "Remove eyesearch from the current buffer."
  (setq-local isearch-search-fun-function
              eyesearch--original-search-fun)
  (setq eyesearch--original-search-fun nil)
  (remove-hook 'isearch-mode-hook #'eyesearch--isearch-start t)
  (remove-hook 'isearch-mode-end-hook #'eyesearch--isearch-end t))

;;;###autoload
(define-minor-mode eyesearch-mode
  "Minor mode for visible-window-first isearch.
When enabled, the first match isearch jumps to is the closest one
within the visible window.  If no match is visible, falls back to
standard isearch.  All other isearch behavior is unchanged."
  :lighter " EyeS"
  :group
  'eyesearch
  (if eyesearch-mode
      (eyesearch--setup)
    (eyesearch--teardown)))

;;;###autoload
(define-globalized-minor-mode global-eyesearch-mode
  eyesearch-mode
  (lambda () (eyesearch-mode 1))
  :group 'eyesearch)

(provide 'eyesearch)
;;; eyesearch.el ends here
