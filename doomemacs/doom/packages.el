;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el
;;;

;; rolling update all pkgs
;; (unpin! t)

(package! eglot-x
  :recipe (:host github
           :repo "nemethf/eglot-x"
           :files ("*.el")))

(package! mode-minder
  :recipe (:host github
           :repo "jdtsmith/mode-minder"
           :files ("*.el")))

;; (package! dape-lldb-dap
;;   :recipe (:local-repo "~/dape-lldb-dap"))

;; (package! treesit-auto
;;   :recipe (:host github
;;            :repo "renzmann/treesit-auto"))

(package! just-mode
  :recipe (:host github
           :repo "leon-barrett/just-mode.el"
           :files ("*.el")))

(package! dape
  :recipe (:host github
           :repo "svaante/dape"))

(package! nushell-mode
  :recipe (:host github
           :repo "mrkkrp/nushell-mode"))

(package! eldoc-mouse
  :recipe (:host github
           :repo "huangfeiyu/eldoc-mouse"))

(package! aweshell
  :recipe (:host github
           :repo "manateelazycat/aweshell"))

(package! rainbow-delimiters)

(package! xwwp
  :recipe (:host github
           :repo "canatella/xwwp"))

;; agent-shell
(package! shell-maker)
(package! acp)
(package! agent-shell)
(package! agent-review
  :recipe (:host github
           :repo "nineluj/agent-review"
           :files ("*.el")))
