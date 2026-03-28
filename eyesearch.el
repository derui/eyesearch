;;; eyesearch.el --- Display isearch message on overlay  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 derui

;; Author: derui
;; Version: 0.1.0
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

;; EyeSearch provides a minor mode `eyesearch-mode' that displays the
;; current isearch message on an overlay near the isearch match, making
;; it easier to see what you are searching for without looking at the
;; minibuffer.

;;; Code:

(defgroup eyesearch nil
  "Display isearch message on overlay."
  :group 'isearch
  :prefix "eyesearch-")

(defcustom eyesearch-position 'next-line
  "Position of the eyesearch overlay relative to the line of the match.
`next-line' displays the message on the line after the match's line.
`previous-line' displays the message on the line before the match's line."
  :type
  '(choice (const :tag "Next line" next-line)
           (const :tag "Previous line" previous-line))
  :group 'eyesearch)

(defcustom eyesearch-format " [%s]"
  "Format string for the eyesearch overlay.
%s is replaced with the isearch message string."
  :type 'string
  :group 'eyesearch)

(defface eyesearch-overlay
  '((t :inherit isearch
       :weight bold))
  "Face used for the eyesearch overlay text."
  :group 'eyesearch)

(defvar-local eyesearch--overlay nil
  "The overlay used to display the isearch message.")

(defun eyesearch--delete-overlay ()
  "Delete the eyesearch overlay if it exists."
  (when (overlayp eyesearch--overlay)
    (delete-overlay eyesearch--overlay)
    (setq eyesearch--overlay nil)))

(defun eyesearch--make-overlay-string (message)
  "Create the display string for the overlay from MESSAGE."
  (let ((text (format eyesearch-format message)))
    (propertize text 'face 'eyesearch-overlay)))

(defun eyesearch--update ()
  "Update the eyesearch overlay with the current isearch state."
  (eyesearch--delete-overlay)
  (when (and isearch-mode
             isearch-overlay
             (overlay-buffer isearch-overlay)
             (not (string-empty-p isearch-string)))
    (let* ((padding
            (make-string
             (save-excursion
               (goto-char (overlay-start isearch-overlay))
               (current-column))
             ?\s))
           (overlay-text
            (eyesearch--make-overlay-string isearch-string)))
      (pcase eyesearch-position
        ('next-line
         (let ((eol (save-excursion
                      (goto-char (overlay-end isearch-overlay))
                      (line-end-position))))
           (setq eyesearch--overlay (make-overlay eol eol))
           (overlay-put eyesearch--overlay 'after-string
                        (concat "\n" padding overlay-text))
           (overlay-put eyesearch--overlay 'priority 1001)))
        ('previous-line
         (let ((bol (save-excursion
                      (goto-char (overlay-start isearch-overlay))
                      (line-beginning-position))))
           (setq eyesearch--overlay (make-overlay bol bol))
           (overlay-put eyesearch--overlay 'before-string
                        (concat padding overlay-text "\n"))
           (overlay-put eyesearch--overlay 'priority 1001)))))))

(defun eyesearch--isearch-end ()
  "Clean up the eyesearch overlay when isearch ends."
  (eyesearch--delete-overlay))

(defun eyesearch--setup-hooks ()
  "Set up hooks for eyesearch."
  (add-hook 'isearch-update-post-hook #'eyesearch--update nil t)
  (add-hook 'isearch-mode-end-hook #'eyesearch--isearch-end nil t))

(defun eyesearch--teardown-hooks ()
  "Remove hooks for eyesearch."
  (remove-hook 'isearch-update-post-hook #'eyesearch--update t)
  (remove-hook 'isearch-mode-end-hook #'eyesearch--isearch-end t)
  (eyesearch--delete-overlay))

;;;###autoload
(define-minor-mode eyesearch-mode
  "Minor mode to display isearch message on an overlay near the match.
When enabled, the current isearch string is displayed as an overlay
next to or below the isearch match, so you don't have to look at the
minibuffer."
  :lighter " EyeS"
  :group
  'eyesearch
  (if eyesearch-mode
      (eyesearch--setup-hooks)
    (eyesearch--teardown-hooks)))

;;;###autoload
(define-globalized-minor-mode global-eyesearch-mode
  eyesearch-mode
  (lambda () (eyesearch-mode 1))
  :group 'eyesearch)

(provide 'eyesearch)
;;; eyesearch.el ends here
