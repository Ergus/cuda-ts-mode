;;; cuda-ts-mode.el ---  tree-sitter support for Cuda -*- lexical-binding: t; -*-

;; Copyright (C) 2025  Jimmy Aguilar Mena

;; Author: Jimmy Aguilar Mena <spacibba@aol.com>
;; URL: https://github.com/Ergus/cuda-ts-mode
;; Keywords: cuda languages tree-sitter
;; Version: 0.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;
;; This package provides `cuda-ts-mode' for Cuda files. A major cuda
;; mode with tree-sitter. This mode is actually very similar to the
;; c++-ts-mode.
;;
;; The tree-sitter cuda grammar is in
;; https://github.com/tree-sitter-grammars/tree-sitter-cuda
;;
;;; Code:

(require 'c-ts-mode)

(defun cuda-ts-mode--syntax-propertize (beg end)
  "Apply syntax text property to template delimiters between BEG and END.

< and > are usually punctuation, e.g., in ->.  But when used for
templates, they should be considered pairs.
The same happens when calling kernels <<< and >>>"
  (goto-char beg)
  (while (re-search-forward (rx (or "<" ">" "<<<" ">>>")) end t)
    (pcase (treesit-node-type
            (treesit-node-parent
             (treesit-node-at (match-beginning 0))))
      ((or "kernel_call_syntax"
           "template_argument_list")
       (put-text-property (match-beginning 0)
                          (match-end 0)
                          'syntax-table
                          (pcase (char-before)
                            (?< '(4 . ?>))
                            (?> '(5 . ?<))))))))

(defconst cuda-ts-mode--keywords
  '("__shared__" "__global__" "__local__" "__constant__"
    "__managed__" "__grid_constant__"
    "__device__" "__host__" "__forceinline__" "__noinline__")
  "Tree-sitter cuda keywords.")

;;;###autoload
(define-derived-mode cuda-ts-mode c-ts-base-mode "Cuda"
  "Major mode for editing Cuda, powered by tree-sitter.

This mode is independent from the classic cuda-mode.el, but inherits
most of the properties from c++-ts-mode like `c-ts-mode-indent-style',
`c-ts-mode-indent-offset' or `c-ts-mode-enable-doxygen'."

  (when (treesit-ready-p 'cuda)

    ;; Create a "cpp" parser which is actually a cuda parser. It’s
    ;; important to use ‘cpp’ here, so that the parser is labeled as a
    ;; cpp parser.
    (setq-local treesit-language-remap-alist '((cpp . cuda))   ;; This is the key trick
		treesit-primary-parser (treesit-parser-create 'cpp)
		syntax-propertize-function #'cuda-ts-mode--syntax-propertize
		treesit-simple-indent-rules (c-ts-mode--simple-indent-rules
					     'cpp c-ts-mode-indent-style)
		treesit-font-lock-settings (treesit-replace-font-lock-feature-settings
					    (treesit-font-lock-rules
					     :language 'cpp
					     :feature 'keyword
					     `([,@cuda-ts-mode--keywords
						,@(c-ts-mode--keywords 'cpp)] @font-lock-keyword-face))
					    (c-ts-mode--font-lock-settings 'cpp)))

    (treesit-major-mode-setup)

    (when (and c-ts-mode-enable-doxygen
               (treesit-ready-p 'doxygen t))
      (setq-local treesit-font-lock-settings
                  (append
                   treesit-font-lock-settings
                   c-ts-mode-doxygen-comment-font-lock-settings))
      (setq-local treesit-range-settings
                  (treesit-range-rules
                   :embed 'doxygen
                   :host 'cpp
                   :local t
                   `(((comment) @cap
                      (:match
                       ,c-ts-mode--doxygen-comment-regex @cap))))))))

(setf (alist-get 'cuda treesit-language-source-alist)  ;; Add the grammar source entry
	`("https://github.com/tree-sitter-grammars/tree-sitter-cuda" nil nil nil nil))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.cu[h]?\\'" . cuda-ts-mode))
