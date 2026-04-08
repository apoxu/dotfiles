;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Load keybindings
(load! "keybinds")

;; Fonts
;; (setq doom-font (font-spec :family "FiraCode Nerd Font" :size 16)
;;       doom-variable-pitch-font (font-spec :family "FiraCode Nerd Font")
;;       doom-symbol-font (font-spec :family "FiraCode Nerd Font")
;;       doom-big-font (font-spec :family "FiraCode Nerd Font" :size 19))

;; Theme.
(setq doom-theme 'doom-gruvbox)

;; Line Number.
(setq display-line-numbers-type t)

(setq org-directory "~/org/")

;; Enable pixel scroll by default. (when (and (>= emacs-major-version 28) (display-graphic-p))
(pixel-scroll-precision-mode 1)

;; Don't disturb me when quitting emacs.
(setq confirm-kill-emacs nil)

;; Enable eglot-x
(with-eval-after-load 'eglot
  (use-package! eglot-x
    :config
    (eglot-x-setup)))

;; Display mode-line under writeroom-mode.
(setq writeroom-mode-line-toggle-position 'mode-line-format)
(add-hook 'writeroom-mode-hook #'writeroom-toggle-mode-line)

(setq writeroom-width 60)

(unless (eq system-type 'android)
  (defun setup-zen-for-modes (modes)
    "Enable `+zen/toggle` when entering specified major MODES, even if deferred."
    (dolist (mode modes)
      (let* ((hook (intern (concat (symbol-name mode) "-hook")))
             (lib (symbol-file mode 'defun))
             (lib-name (when lib
                         (file-name-sans-extension
                          (file-name-nondirectory lib)))))
        (cond
         ((boundp hook)
          (add-hook hook #'+zen/toggle))
         (lib-name
          (eval-after-load lib-name
            `(add-hook ',hook #'+zen/toggle)))
         (t
          (message "[WARNING] Cannot find library for mode: %s" mode))))))

  (setup-zen-for-modes '(emacs-lisp-mode
                         rustic-mode
                         conf-mode
                         help-mode
                         helpful-mode
                         org-mode
                         sh-mode
                         autoconf-mode
                         makefile-bsdmake-mode
                         c-mode
                         c-ts-mode
                         ;;vterm-mode
                         fundamental-mode
                         nushell-mode
                         nxml-mode
                         yaml-ts-mode
                         dart-ts-mode
                         dart-mode
                         ibuffer-mode
                         treemacs-mode)))

;; let emacs itself use bash and then vterm use nushell
(when (executable-find "nu")
  (progn
    (setq shell-file-name (executable-find "bash"))
    (setq-default explicit-shell-file-name (executable-find "nu"))
    (when (modulep! :term vterm)
      (setq-default vterm-shell (executable-find "nu")))))

;; Use jk instead of escape
(after! evil-escape
  (setq evil-escape-key-sequence "jk"))

(setq pyim-cloudim 'baidu)
(setq projectile-project-root-files-top-down-p t)

;; eshell config
(setq +eshell-popup-window-parameters '((no-delete-other-windows . t)
                                        (window-height . 0.35)))

;; active hl-todo-mode under dart-mode
(add-hook 'dart-mode-hook #'hl-todo-mode)

;; outline
(advice-add 'consult-eglot-symbols :override #'consult-outline)

;; eldoc-mouse
(use-package! eldoc-mouse
  :hook eldoc-mode)

;; eshell
(use-package! aweshell)
(set-eshell-alias!
 "elispc" "*emacs -q --no-site-file --batch --load /Users/apollo/elispc/elispc.el -- $*")

;; rainbow brackets
(use-package! rainbow-delimiters
  :hook emacs-lisp-mode)

;; agent-shell
(use-package! agent-shell
  :config
  (setq agent-shell-opencode-environment
        (agent-shell-make-environment-variables :inherit-env t))
  ;; (setq agent-shell-opencode-default-model-id)
  (setq agent-shell-preferred-agent-config (agent-shell-opencode-make-agent-config))
  (evil-define-key 'insert agent-shell-mode-map (kbd "RET") #'newline)
  (evil-define-key 'normal agent-shell-mode-map (kbd "RET") #'comint-send-input)
  (add-hook 'diff-mode-hook
            (lambda ()
              (when (string-match-p "\\*agent-shell-diff\\*" (buffer-name))
                (evil-emacs-state)))))
