;;; $DOOMDIR/keybinds.el -*- lexical-binding: t; -*-

(map!
 (:leader
  :desc "Explorer" "e" #'+treemacs/toggle))

;; use 'C-,' to open/close vterm
(global-set-key (kbd "C-,") '+vterm/toggle)
