;;; eyesearch-test.el --- Tests for eyesearch  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests for eyesearch.el using ERT.

;;; Code:

(require 'ert)
(require 'eyesearch (expand-file-name "eyesearch.el"
                                       (file-name-directory
                                        (or load-file-name
                                            buffer-file-name
                                            default-directory))))

;;; Double-activation recursion bug

(ert-deftest eyesearch-test-double-activation-no-recursion ()
  "Activating eyesearch-mode twice must not cause infinite recursion.
When `eyesearch--setup' runs a second time, `eyesearch--original-search-fun'
must not point to `eyesearch--search-fun-function' itself."
  (with-temp-buffer
    (insert "hello world hello world")
    (goto-char (point-min))
    ;; Activate twice
    (eyesearch-mode 1)
    (eyesearch-mode 1)
    (should (not (eq eyesearch--original-search-fun
                     #'eyesearch--search-fun-function)))
    (eyesearch-mode -1)))

(ert-deftest eyesearch-test-double-activation-search-fun-works ()
  "Search function must not recurse infinitely after double activation."
  (with-temp-buffer
    (insert "hello world hello world")
    (goto-char (point-min))
    (let ((isearch-forward t)
          (isearch-regexp nil)
          (isearch-regexp-function nil))
      (eyesearch-mode 1)
      (eyesearch-mode 1)
      ;; Calling the search-fun-function should return a function, not blow the stack
      (let ((fun (eyesearch--search-fun-function)))
        (should (functionp fun))
        ;; Set last-string so it takes the C-s repeat (default) path
        (setq eyesearch--last-string "hello")
        (should (funcall fun "hello" nil nil 1)))
      (eyesearch-mode -1))))

(ert-deftest eyesearch-test-teardown-restores-original ()
  "Deactivating eyesearch-mode must restore the original search fun."
  (with-temp-buffer
    (let ((orig isearch-search-fun-function))
      (eyesearch-mode 1)
      (should (eq isearch-search-fun-function
                  #'eyesearch--search-fun-function))
      (eyesearch-mode -1)
      (should (eq isearch-search-fun-function orig)))))

(ert-deftest eyesearch-test-single-activation-works ()
  "Basic single activation should work correctly."
  (with-temp-buffer
    (insert "foo bar foo baz")
    (goto-char (point-min))
    (let ((isearch-forward t)
          (isearch-regexp nil)
          (isearch-regexp-function nil))
      (eyesearch-mode 1)
      ;; Set last-string so it takes the C-s repeat (default) path
      (setq eyesearch--last-string "foo")
      (let ((fun (eyesearch--search-fun-function)))
        (should (functionp fun))
        (should (funcall fun "foo" nil nil 1)))
      (eyesearch-mode -1))))

(provide 'eyesearch-test)
;;; eyesearch-test.el ends here
