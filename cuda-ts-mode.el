;;; cuda-ts-mode.el ---  tree-sitter support for Cuda -*- lexical-binding: t; -*-

;; Copyright (C) 2025  Jimmy Aguilar Mena

;; Author: Jimmy Aguilar Mena <spacibba@aol.com>
;; URL: https://github.com/chachi/cuda-mode
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

;; I need this extra code to replace the 'cpp key with 'cuda
(defconst cuda-ts-mode--simple-indent-rules
  (let ((cpp-rules (c-ts-mode--simple-indent-rules
		    'cpp c-ts-mode-indent-style)))
    `((cuda . ,(alist-get 'cpp cpp-rules))))
  "Tree-sitter indentation settings.")

;; Cuda grammar seems not to support "virtual" as a node
;; the c-ts-mode c-ts-mode--test-virtual-named-p hardcodes cpp which
;; then fails to compile treesit-font-lock-rules when calling
;; treesit-validate-font-lock-rules
(defconst cuda-ts-mode--keywords
  (append (c-ts-mode--keywords 'cpp)
	  `("__shared__" "__global__" "__local__" "__constant__"
	    "__managed__" "__grid_constant__"
	    "__device__" "__host__" "__forceinline__" "__noinline__" "virtual"))
  "Tree-sitter cuda keywords.")

;; This is actually a copy of c-ts-mode--font-lock-settings
;; There should be a better method to do this without manually copying it.
(defconst cuda-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :default-language 'cuda

   :feature 'keyword
   `([,@cuda-ts-mode--keywords] @font-lock-keyword-face
     (auto) @font-lock-keyword-face
     (this) @font-lock-keyword-face
     )

   :feature 'comment
   `(((comment) @font-lock-doc-face
      (:match ,(rx bos "/**") @font-lock-doc-face))
     (comment) @font-lock-comment-face)

   :feature 'preprocessor
   `((preproc_directive) @font-lock-preprocessor-face

     (preproc_def
      name: (identifier) @font-lock-variable-name-face)

     (preproc_ifdef
      name: (identifier) @font-lock-variable-name-face)

     (preproc_function_def
      name: (identifier) @font-lock-function-name-face)

     (preproc_params
      (identifier) @font-lock-variable-name-face)

     (preproc_defined
      "defined" @font-lock-preprocessor-face
      "(" @font-lock-preprocessor-face
      (identifier) @font-lock-variable-name-face
      ")" @font-lock-preprocessor-face)
     [,@c-ts-mode--preproc-keywords] @font-lock-preprocessor-face)

   :feature 'constant
   `((true) @font-lock-constant-face
     (false) @font-lock-constant-face
     (null) @font-lock-constant-face)

   :feature 'operator
   `([,@c-ts-mode--operators ,@c-ts-mode--c++-operators] @font-lock-operator-face
     "!" @font-lock-negation-char-face)

   :feature 'string
   `((string_literal) @font-lock-string-face
     (system_lib_string) @font-lock-string-face
     (raw_string_literal) @font-lock-string-face)

   :feature 'literal
   `((number_literal) @font-lock-number-face
     (char_literal) @font-lock-constant-face)

   :feature 'type
   `((primitive_type) @font-lock-type-face
     (type_identifier) @font-lock-type-face
     (sized_type_specifier) @font-lock-type-face
     (type_qualifier) @font-lock-type-face
     (qualified_identifier
      scope: (namespace_identifier) @font-lock-constant-face)
     (operator_cast) type: (type_identifier) @font-lock-type-face
     (namespace_identifier) @font-lock-constant-face
     [,@c-ts-mode--type-keywords] @font-lock-type-face)

   :feature 'definition
   ;; Highlights identifiers in declarations.
   `((destructor_name (identifier) @font-lock-function-name-face)
     (declaration
      declarator: (_) @c-ts-mode--fontify-declarator)

     (field_declaration
      declarator: (_) @c-ts-mode--fontify-declarator)

     (function_definition
      declarator: (_) @c-ts-mode--fontify-declarator)
     ;; When a function definition has preproc directives in its body,
     ;; it can't correctly parse into a function_definition.  We still
     ;; want to highlight the function_declarator correctly, hence
     ;; this rule.  See bug#63390 for more detail.
     ((function_declarator) @c-ts-mode--fontify-declarator
      (:pred c-ts-mode--top-level-declarator
             @c-ts-mode--fontify-declarator))

     (parameter_declaration
      declarator: (_) @c-ts-mode--fontify-declarator)

     (enumerator
      name: (identifier) @font-lock-property-name-face))

   :feature 'assignment
   ;; TODO: Recursively highlight identifiers in parenthesized
   ;; expressions, see `c-ts-mode--fontify-declarator' for
   ;; inspiration.
   '((assignment_expression
      left: (identifier) @font-lock-variable-name-face)
     (assignment_expression
      left: (field_expression field: (_) @font-lock-property-use-face))
     (assignment_expression
      left: (pointer_expression
             (identifier) @font-lock-variable-name-face))
     (assignment_expression
      left: (subscript_expression
             (identifier) @font-lock-variable-name-face))
     (init_declarator declarator: (_) @c-ts-mode--fontify-declarator))

   :feature 'function
   '((call_expression
      function:
      [(identifier) @font-lock-function-call-face
       (field_expression field: (field_identifier) @font-lock-function-call-face)]))

   :feature 'variable
   '((identifier) @c-ts-mode--fontify-variable)

   :feature 'label
   '((labeled_statement
      label: (statement_identifier) @font-lock-constant-face))

   :feature 'error
   '((ERROR) @c-ts-mode--fontify-error)

   :feature 'escape-sequence
   :override t
   '((escape_sequence) @font-lock-escape-face)

   :feature 'property
   '((field_identifier) @font-lock-property-use-face)

   :feature 'bracket
   '((["(" ")" "[" "]" "{" "}"]) @font-lock-bracket-face)

   :feature 'delimiter
   '((["," ":" ";"]) @font-lock-delimiter-face)

   :feature 'emacs-devel
   :override t
   `(((call_expression
       (call_expression function: (identifier) @fn)
       @c-ts-mode--fontify-DEFUN)
      (:match "\\`DEFUN\\'" @fn))

     ((function_definition type: (_) @for-each-tail)
      @c-ts-mode--fontify-for-each-tail
      (:match ,c-ts-mode--for-each-tail-regexp @for-each-tail))))
  "Tree-sitter font-lock settings.")



;;;###autoload
(define-derived-mode cuda-ts-mode c++-ts-mode "Cuda"
  "Major mode for editing Cuda, powered by tree-sitter.

This mode is independent from the classic cuda-mode.el"
  (when (and (treesit-ready-p 'cuda)
	     (not (assoc "cuda" treesit-language-remap-alist)))

    ;;(push '("cuda" . "c++") treesit-language-remap-alist)
    (setq-local syntax-propertize-function
                #'cuda-ts-mode--syntax-propertize)

    (setq-local treesit-primary-parser (treesit-parser-create 'cuda)
		treesit-simple-indent-rules cuda-ts-mode--simple-indent-rules
		treesit-font-lock-settings cuda-ts-mode--font-lock-settings)

    (treesit-major-mode-setup)

    ))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.cu[h]?\\'" . cuda-ts-mode))
