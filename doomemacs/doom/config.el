;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Load keybindings
(load! "keybinds")

;; Fonts
(setq doom-font (font-spec :family "FiraCode Nerd Font" :size 16)
      doom-variable-pitch-font (font-spec :family "FiraCode Nerd Font")
      doom-symbol-font (font-spec :family "FiraCode Nerd Font")
      doom-big-font (font-spec :family "FiraCode Nerd Font" :size 19))

;; Theme
(setq doom-theme 'doom-gruvbox-light)

;; Line Number
(setq display-line-numbers-type t)

(setq org-directory "~/org/")

;; Enable pixel scroll by default
(when (and (>= emacs-major-version 28) (display-graphic-p))
  (pixel-scroll-precision-mode 1))

;; Don't disturb me when quitting emacs
(setq confirm-kill-emacs nil)

(with-eval-after-load 'eglot
  (use-package! eglot-x
    :config
    (eglot-x-setup)))

;; (use-package! eldoc-box
;;   :hook
;;   (eglot-managed-mode . eldoc-box-help-at-point))
;; (add-hook 'eglot-managed-mode-hook #'eldoc-box-hover-mode t)

;;(add-to-list 'exec-path (format "%s%s" (string-trim-right (shell-command-to-string "brew --prefix --installed llvm")) "/bin"))
(use-package! dape
  :custom (dape-buffer-window-arrangment))

;; let emacs itself use bash and let vterm use nushell
(setq shell-file-name (executable-find "bash"))
(setq-default vterm-shell (executable-find "nu"))
(setq-default explicit-shell-file-name (executable-find "nu"))
