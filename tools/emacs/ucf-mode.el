;; ucf-mode.el --- major mode for editing Xilinx user constraint file (UCF) 
;; in Emacs

;; $Id: ucf-mode.el 5 2010-10-22 03:16:05Z ywu $

;; Copyright (C) 2007-2010 Jim Wu

;; Author: Jim Wu (jimwu88 at yahoo dot com)

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;; USAGE
;; =====
;; A major mode for editing Xilinx user constraint file (UCF).

;; Installation for setting up automatic UCF  mode:
;; Save this file in your load path, and add the following lines in your
;; .emacs (uncomment them first)
;; (setq auto-mode-alist (cons  '("\\.ucf\\'" . ucf-mode) auto-mode-alist))
;; (setq auto-mode-alist (cons  '("\\.ncf\\'" . ucf-mode) auto-mode-alist))
;; (add-hook 'ucf-mode-hook '(lambda () (font-lock-mode 1)))
;; (autoload 'ucf-mode "ucf-mode")

(defvar ucf-mode-map()
  "Keymap used in ucf mode.")

;; syntax table for ucf-mode
(defvar ucf-mode-syntax-table nil
  "Syntax table for ucf-mode")
  
(if ucf-mode-syntax-table
    ()
  (setq ucf-mode-syntax-table (make-syntax-table (standard-syntax-table)))
  (modify-syntax-entry ?_ "w" ucf-mode-syntax-table)
  ;; comments (// or #)
  (modify-syntax-entry ?/ ". 12" ucf-mode-syntax-table)
  (modify-syntax-entry ?# "<"    ucf-mode-syntax-table)
  (modify-syntax-entry ?\n ">"   ucf-mode-syntax-table)
)

(defvar ucf-mode-menu (make-sparse-keymap "UCF-Mode")
  "Keymap for UCF-mode's menu.")

(defconst ucf-font-lock-keywords-1
  (list 
   '("\\<\\(inst\\|net\\|pin\\|inst\\|loc\\|config\\|stepping\\|prohibit\\|dci_cascade\\|part\\)\\>" . font-lock-keyword-face)
   '("\\<\\(tnm_net\\|tnm\\|tpthru\\|timegrp\\|except\\|timespec\\|rising\\|falling\\)\\>" . font-lock-keyword-face)
   '("\\<\\(period\\|high\\|input_jitter\\|feedback\\|priority\\)\\>" . font-lock-keyword-face)
   '("\\<\\(offset\\|in\\|out\\|valid\\|before\\|after\\|reference_pin\\|from\\|to\\|thru\\|datapathonly\\)\\>" . font-lock-keyword-face)
   '("\\<\\(maxdelay\\|maxskew\\|clock_dedicated_route\\|tig\\|bel\\|nodelay\\)\\>" . font-lock-keyword-face)
   '("\\<\\(area_group\\|range\\|compression\\|implement\\|group\\)\\>" . font-lock-keyword-face)
   '("\\<\\(keep_hierarchy\\|optimize\\|lock_pins\\|group\\)\\>" . font-lock-keyword-face)
   '("\\<\\(place\\|mode\\|u_set\\|route\\)\\>" . font-lock-keyword-face)
   '("\\<\\(iostandard\\|drive\\|slew\\|diff_term\\|out_term\\|pullup\\|iobdelay\\)\\>" . font-lock-keyword-face)
   '("\\<\\(bypass\\|iob\\)\\>" . font-lock-keyword-face)
   '("\\<\\(rloc_origin\\|hu_set\\|rloc\\)\\>" . font-lock-keyword-face)
   '("\\<\\(ffs\\)\\>" . font-lock-keyword-face)

   '("\\<\\(true\\|false\\|none\\|closed\\|slow\\|fast\\|quietio\\|keeper\\|off\\|fixed\\)\\>" . font-lock-constant-face)

   '("\\<\\(phase_shift\\|deskew_adjust\\|clkout_phase_shift\\)\\>" . font-lock-variable-name-face)

   )
  "Minimal highlighting expressions for ucf mode.")

(defvar ucf-font-lock-keywords ucf-font-lock-keywords-1
  "Default highlighting expressions for UCF mode.")

;; begin of menu commands
;; insert TNM_NET
(defun ucf-insert-tnm-net ()
  "Insert TNM_NET"
  (interactive)
  (insert "NET net_name TNM_NET = tn_name;")
)

(defun ucf-insert-timegrp ()
  "Insert TIMEGRP"
  (interactive)
  (insert "TIMEGRP timegrp_name = tn_name0 tn_name1 EXCEPT tn_name2 tn_name3;")
)

;; insert period constraints
(defun ucf-insert-timespec-period ()
  "Insert TIEMSPEC PERIOD"
  (interactive)
  (insert "TIMESPEC TS_name = PERIOD tn_name frequency MHz HIGH percentage %;")
)

(defun ucf-insert-timespec-from-to ()
  "Insert TIEMSPEC FROM-TO"
  (interactive)
  (insert "TIMESPEC TS_name = FROM src_group TO dest_group value units;")
)

(defun ucf-insert-inst-area-group ()
  "Insert INST AREA_GROUP"
  (interactive)
  (insert "INST inst_name AREA_GROUP = area_group_name;")
)

(defun ucf-insert-timegrp-area-group ()
  "Insert TIMEGRP AREA_GROUP"
  (interactive)
  (insert "TIMEGRP timegrp_name AREA_GROUP = area_group_name;")
)

(defun ucf-insert-area-group-clock-region ()
  "Insert AREA_GROUP RANGE = CLOCKREGION"
  (interactive)
  (insert "AREA_GROUP area_group_name RANGE = CLOCKREGION_XmYn, CLOCKREGION_XiYj;")
)

(defun ucf-insert-area-group-slice ()
  "Insert AREA_GROUP RANGE = SLICE_XnYm"
  (interactive)
  (insert "AREA_GROUP area_group_name RANGE = SLICE_XmYn:SLICE_XiYj;")
)

(defun ucf-insert-inst-loc ()
  "Insert INST LOC"
  (interactive)
  (insert "INST inst_name AREA_GROUP = area_group_name;")
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ucf-setup-keymap ()
  "Set up keymap for UCF mode."
  (setq ucf-mode-map (make-sparse-keymap))
  (define-key ucf-mode-map [menu-bar ucf-mode]
    (cons "UCF-Mode" ucf-mode-menu))
  (let ((map ucf-mode-map))
  ;;(define-key map "\M-p" 'ucf-insert-period)
  ;;(define-key map "\M-a" 'ucf-insert-inst-area-group)
  ;;(define-key map "\M-t" 'ucf-insert-timegrp-area-group)
  ))

;; menu items
(define-key ucf-mode-menu [insert-inst-loc]
  '("Insert INST LOC" .  ucf-insert-inst-loc))

(define-key ucf-mode-menu [separator1]
  '("----" .  separator1))
;;--------------------------------------------------------

(define-key ucf-mode-menu [insert-area-group-slice]
  '("Insert AREA_GROUP RANGE = SLICE" .  ucf-insert-area-group-slice))

(define-key ucf-mode-menu [insert-area-group-clock-region]
  '("Insert AREA_GROUP RANGE = CLOCKREGION" .  ucf-insert-area-group-clock-region))

(define-key ucf-mode-menu [insert-timegrp-area-group]
  '("Insert TIMEGRP AREA_GROUP" .  ucf-insert-timegrp-area-group))

(define-key ucf-mode-menu [insert-inst-area-group]
  '("Insert INST AREA_GROUP" .  ucf-insert-inst-area-group))

(define-key ucf-mode-menu [separator0]
  '("----" .  separator0))
;;--------------------------------------------------------

(define-key ucf-mode-menu [insert-timespec-from-to]
  '("Insert TIMESPEC FROM-TO" .  ucf-insert-timespec-from-to))

(define-key ucf-mode-menu [insert-timespec-period]
  '("Insert TIMESPEC PERIOD" .  ucf-insert-timespec-period))

(define-key ucf-mode-menu [insert-timggrp]
  '("Insert TIMGGRP" .  ucf-insert-timegrp))

(define-key ucf-mode-menu [insert-tnm-net]
  '("Insert TNM_NET" .  ucf-insert-tnm-net))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun ucf-mode()
  "Major mode for editing UCF code."
  (interactive)
  (kill-all-local-variables)
  (setq major-mode 'ucf-mode)
  (setq mode-name "UCF Mode")

  (set (make-local-variable 'font-lock-keywords-case-fold-search) t)
  (set-syntax-table ucf-mode-syntax-table)
  (set (make-local-variable 'font-lock-defaults) '((ucf-font-lock-keywords) nil (font-lock-keywords-case-fold-search)))

  (or ucf-mode-map
      (ucf-setup-keymap))
  (use-local-map ucf-mode-map)

  (run-hooks 'ucf-mode-hook)
)

(provide 'ucf-mode)

