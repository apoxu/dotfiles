;;; $DOOMDIR/keybinds.el -*- lexical-binding: t; -*-

(map!
 (:leader
  :desc "Explorer" :g "e" #'+treemacs/toggle
  :prefix ("t" . "toggle/tabs")
  :desc "ace-jump-tabs" :g "a" #'centaur-tabs-ace-jump
  :prefix ("c")
  :desc "outline" :g "j" #'consult-outline))

;; unbind 'evil-record-macro', I don't use that
(map!
 :map evil-normal-state-map "q" nil)

;; use 'C-,' to open/close eshell
(global-set-key (kbd "C-,") 'aweshell-dedicated-toggle)
