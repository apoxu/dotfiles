;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el
;;;
;;(unpin! t)

(package! eglot-x
  :recipe (:host github
           :repo "nemethf/eglot-x"
           :files ("*.el")))

(package! eldoc-box
  :recipe (:host github
           :repo "casouri/eldoc-box"
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

(package! dape
  :recipe (:host github
           :repo "svaante/dape"))
