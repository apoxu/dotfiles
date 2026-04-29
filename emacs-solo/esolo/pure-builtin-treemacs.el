;;; pure-builtin-treemacs.el --- Pure built-in Treemacs-like sidebar -*- lexical-binding: t; -*-

;; 目标：在 Emacs 30.2 中只依赖内置包，尽可能复刻 Treemacs 的常用工作流。
;; 用法：把本文件 load 到 init.el，或直接把内容复制进 init.el。

(require 'button)
(require 'cl-lib)
(require 'dired)
(require 'project)
(require 'seq)
(require 'subr-x)
(require 'tab-line)
(require 'vc)
(require 'filenotify nil t)

(defgroup pure-builtin-treemacs nil
  "A Treemacs-like project tree implemented with built-in Emacs packages."
  :group 'convenience
  :prefix "pure-builtin-treemacs-")

(defcustom pure-builtin-treemacs-buffer-name "*Pure Builtin Treemacs*"
  "Name of the sidebar tree buffer."
  :type 'string)

(defcustom pure-builtin-treemacs-width 42
  "Width of the left sidebar window."
  :type 'integer)

(defcustom pure-builtin-treemacs-enable-tab-line t
  "Whether buffers opened from the tree should enable `tab-line-mode'."
  :type 'boolean)

(defcustom pure-builtin-treemacs-roots nil
  "Explicit workspace roots.
When nil, the tree follows the current `project.el' project root or VC root."
  :type '(choice (const :tag "Auto current project" nil)
                 (repeat :tag "Explicit roots" directory)))

(defcustom pure-builtin-treemacs-hide-dotfiles t
  "Whether dotfiles should be hidden in the tree."
  :type 'boolean)

(defcustom pure-builtin-treemacs-ignored-names
  '(".git" ".hg" ".svn" ".DS_Store" "node_modules" ".direnv" ".venv"
    "target" "dist" "build")
  "Directory or file basenames that are hidden from the tree."
  :type '(repeat string))

(defcustom pure-builtin-treemacs-show-vc-state t
  "Whether to show built-in VC status markers beside files."
  :type 'boolean)

(defcustom pure-builtin-treemacs-vc-state-limit 200
  "Maximum number of files whose VC state is queried during one refresh.
Set this to nil to query every visible file, but large Git repositories may
block the UI because built-in VC queries are synchronous."
  :type '(choice (const :tag "No limit" nil)
                 integer))

(defcustom pure-builtin-treemacs-watch-files nil
  "Whether to refresh visible directories through `file-notify' when possible."
  :type 'boolean)

(defcustom pure-builtin-treemacs-max-watched-directories 64
  "Maximum number of visible directories that may receive file notification watches.
Large project trees can expose thousands of visible directories after expansion.
Installing all watches synchronously can block the Emacs UI, so watches are
disabled by default and capped when explicitly enabled."
  :type 'integer)

(defcustom pure-builtin-treemacs-follow-add-missing-root t
  "Whether follow mode should add the current file's project root to explicit roots."
  :type 'boolean)

(defcustom pure-builtin-treemacs-state-file
  (locate-user-emacs-file "pure-builtin-treemacs-state.el")
  "File used to persist roots and expansion state."
  :type 'file)

(defcustom pure-builtin-treemacs-save-session-enabled t
  "Whether to persist roots and expanded directories on Emacs exit."
  :type 'boolean)

(defvar pure-builtin-treemacs--expanded (make-hash-table :test #'equal))
(defvar pure-builtin-treemacs--watchers (make-hash-table :test #'equal))
(defvar pure-builtin-treemacs--rendered-dirs nil)
(defvar pure-builtin-treemacs--auto-root nil)
(defvar pure-builtin-treemacs--current-file nil)
(defvar pure-builtin-treemacs--vc-state-count 0)
(defvar pure-builtin-treemacs--refresh-timer nil)
(defvar pure-builtin-treemacs--follow-timer nil)
(defvar pure-builtin-treemacs--watch-timer nil)
(defvar pure-builtin-treemacs--fixing-window-width nil)
(defvar pure-builtin-treemacs--rendering nil)

(defface pure-builtin-treemacs-root-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for project root lines.")

(defface pure-builtin-treemacs-directory-face
  '((t :inherit dired-directory))
  "Face for directory lines.")

(defface pure-builtin-treemacs-current-file-face
  '((t :inherit highlight))
  "Face for the file currently followed by the tree.")

(defface pure-builtin-treemacs-vc-modified-face
  '((t :inherit warning))
  "Face for modified VC entries.")

(defface pure-builtin-treemacs-vc-added-face
  '((t :inherit success))
  "Face for added VC entries.")

(defvar pure-builtin-treemacs-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'pure-builtin-treemacs-visit-at-point)
    (define-key map (kbd "<tab>") #'pure-builtin-treemacs-toggle-at-point)
    (define-key map (kbd "TAB") #'pure-builtin-treemacs-toggle-at-point)
    (define-key map (kbd "o") #'pure-builtin-treemacs-open-in-editor-window)
    (define-key map (kbd "O") #'pure-builtin-treemacs-open-in-other-window)
    (define-key map [remap find-file] #'pure-builtin-treemacs-find-file)
    (define-key map (kbd "g") #'pure-builtin-treemacs-refresh)
    (define-key map (kbd "q") #'pure-builtin-treemacs-quit)
    (define-key map (kbd "a") #'pure-builtin-treemacs-add-current-project)
    (define-key map (kbd "A") #'pure-builtin-treemacs-import-known-projects)
    (define-key map (kbd "s") #'pure-builtin-treemacs-switch-root)
    (define-key map (kbd "r") #'pure-builtin-treemacs-remove-root-at-point)
    (define-key map (kbd "f") #'pure-builtin-treemacs-follow-current-file)
    (define-key map (kbd "H") #'pure-builtin-treemacs-toggle-dotfiles)
    (define-key map (kbd "n") #'pure-builtin-treemacs-create-file)
    (define-key map (kbd "N") #'pure-builtin-treemacs-create-directory)
    (define-key map (kbd "R") #'pure-builtin-treemacs-rename)
    (define-key map (kbd "D") #'pure-builtin-treemacs-delete)
    (define-key map (kbd "y") #'pure-builtin-treemacs-copy-path)
    (define-key map (kbd "v") #'pure-builtin-treemacs-vc-dir)
    (define-key map (kbd "d") #'pure-builtin-treemacs-dired)
    (define-key map (kbd "F") #'pure-builtin-treemacs-project-find-file)
    (define-key map (kbd "/") #'pure-builtin-treemacs-project-search)
    (define-key map (kbd "C") #'pure-builtin-treemacs-collapse-all)
    (define-key map (kbd "?") #'describe-mode)
    map)
  "Keymap used by `pure-builtin-treemacs-mode'.")

(define-derived-mode pure-builtin-treemacs-mode special-mode "PureTree"
  "Pure built-in project tree.

Main keys:
RET/TAB  toggle directory or open file in the main editor window
o/O      open file/directory in the main editor window / another window
g        refresh
f        reveal current file
a/A      add current project / import known projects
s/r      switch root / remove root
n/N/R/D  create file / create directory / rename / delete
v/d/F//  vc-dir / dired / project-find-file / project-find-regexp
H        toggle dotfiles
C        collapse all
q        close sidebar"
  (setq-local truncate-lines t)
  (setq-local buffer-read-only t))

(defun pure-builtin-treemacs--normalize-dir (dir)
  "Return DIR as an absolute directory name."
  (file-name-as-directory (expand-file-name dir)))

(defun pure-builtin-treemacs--normalize-file (file)
  "Return FILE as an absolute file name."
  (expand-file-name file))

(defun pure-builtin-treemacs--current-root (&optional dir)
  "Return the best project root for DIR."
  (let* ((base (pure-builtin-treemacs--normalize-dir (or dir default-directory)))
         (project (project-current nil base)))
    (pure-builtin-treemacs--normalize-dir
     (or (and project (project-root project))
         (let ((default-directory base))
           (vc-root-dir))
         base))))

(defun pure-builtin-treemacs--workspace-roots ()
  "Return normalized roots that should be rendered."
  (let ((roots (or pure-builtin-treemacs-roots
                   (list (or pure-builtin-treemacs--auto-root
                             (pure-builtin-treemacs--current-root))))))
    (cl-remove-duplicates
     (cl-remove-if-not #'file-directory-p
                       (mapcar #'pure-builtin-treemacs--normalize-dir roots))
     :test #'equal)))

(defun pure-builtin-treemacs--root-name (root)
  "Return a short display name for ROOT."
  (or (ignore-errors
        (let ((project (project-current nil root)))
          (and project (project-name project))))
      (file-name-nondirectory (directory-file-name root))
      root))

(defun pure-builtin-treemacs--expanded-p (dir default)
  "Return whether DIR is expanded.  DEFAULT is used when no state exists."
  (let ((state (gethash (pure-builtin-treemacs--normalize-dir dir)
                        pure-builtin-treemacs--expanded :unset)))
    (if (eq state :unset)
        default
      (eq state :open))))

(defun pure-builtin-treemacs--set-expanded (dir open)
  "Set DIR expansion state to OPEN."
  (puthash (pure-builtin-treemacs--normalize-dir dir)
           (if open :open :closed)
           pure-builtin-treemacs--expanded))

(defun pure-builtin-treemacs--toggle-expanded (dir default)
  "Toggle expansion state for DIR, whose default expansion state is DEFAULT."
  (pure-builtin-treemacs--set-expanded
   dir
   (not (pure-builtin-treemacs--expanded-p dir default))))

(defun pure-builtin-treemacs--hidden-name-p (name)
  "Return non-nil when NAME should be hidden."
  (or (member name '("." ".."))
      (member name pure-builtin-treemacs-ignored-names)
      (and pure-builtin-treemacs-hide-dotfiles
           (string-prefix-p "." name))))

(defun pure-builtin-treemacs--children (dir)
  "Return visible children of DIR, sorted with directories first."
  (let ((children
         (cl-remove-if
          (lambda (path)
            (pure-builtin-treemacs--hidden-name-p
             (file-name-nondirectory (directory-file-name path))))
          (ignore-errors
            (directory-files dir t directory-files-no-dot-files-regexp t)))))
    (sort children
          (lambda (a b)
            (let ((adir (file-directory-p a))
                  (bdir (file-directory-p b))
                  (aname (downcase (file-name-nondirectory (directory-file-name a))))
                  (bname (downcase (file-name-nondirectory (directory-file-name b)))))
              (cond
               ((and adir (not bdir)) t)
               ((and (not adir) bdir) nil)
               (t (string-lessp aname bname))))))))

(defun pure-builtin-treemacs--vc-tag (path)
  "Return a short VC status marker for PATH."
  (when (and pure-builtin-treemacs-show-vc-state
             (not (file-directory-p path))
             (or (not pure-builtin-treemacs-vc-state-limit)
                 (< pure-builtin-treemacs--vc-state-count
                    pure-builtin-treemacs-vc-state-limit)))
    (cl-incf pure-builtin-treemacs--vc-state-count)
    (pcase (ignore-errors (vc-state path))
      ('edited (propertize " [M]" 'face 'pure-builtin-treemacs-vc-modified-face))
      ('added (propertize " [A]" 'face 'pure-builtin-treemacs-vc-added-face))
      ('unregistered (propertize " [?]" 'face 'shadow))
      ('removed (propertize " [D]" 'face 'pure-builtin-treemacs-vc-modified-face))
      ('missing (propertize " [!]" 'face 'pure-builtin-treemacs-vc-modified-face))
      ('conflict (propertize " [C]" 'face 'error))
      (_ ""))))

(defun pure-builtin-treemacs--line-path ()
  "Return the file path stored at point."
  (or (get-text-property (point) 'pure-builtin-treemacs-path)
      (get-text-property (line-beginning-position) 'pure-builtin-treemacs-path)))

(defun pure-builtin-treemacs--line-root ()
  "Return the workspace root stored at point."
  (or (get-text-property (point) 'pure-builtin-treemacs-root)
      (get-text-property (line-beginning-position) 'pure-builtin-treemacs-root)))

(defun pure-builtin-treemacs--insert-button-line (text path root face action)
  "Insert TEXT as a clickable line for PATH under ROOT with FACE and ACTION."
  (let ((start (point)))
    (insert-text-button
     text
     'follow-link t
     'help-echo path
     'action action
     'face face)
    (insert "\n")
    (add-text-properties
     start (1- (point))
     `(pure-builtin-treemacs-path ,path
       pure-builtin-treemacs-root ,root
       mouse-face highlight))))

(defun pure-builtin-treemacs--insert-node (path root depth current-file seen)
  "Insert PATH under ROOT at DEPTH.  CURRENT-FILE is highlighted.
SEEN prevents symlink cycles."
  (let* ((dirp (file-directory-p path))
         (norm (if dirp
                   (pure-builtin-treemacs--normalize-dir path)
                 (pure-builtin-treemacs--normalize-file path)))
         (name (file-name-nondirectory (directory-file-name norm)))
         (expanded (and dirp (pure-builtin-treemacs--expanded-p norm nil)))
         (marker (if dirp (if expanded "[-]" "[+]") "   "))
         (indent (make-string (* depth 2) ?\s))
         (suffix (cond
                  ((and dirp (file-symlink-p norm)) "/@")
                  (dirp "/")
                  ((file-symlink-p norm) "@")
                  (t "")))
         (vc (pure-builtin-treemacs--vc-tag norm))
         (face (cond
                ((and current-file (equal current-file norm))
                 'pure-builtin-treemacs-current-file-face)
                (dirp 'pure-builtin-treemacs-directory-face)
                (t 'default)))
         (text (concat indent marker " " name suffix vc)))
    (when dirp
      (push norm pure-builtin-treemacs--rendered-dirs))
    (pure-builtin-treemacs--insert-button-line
     text norm root face
     (lambda (_button) (pure-builtin-treemacs-visit-path norm)))
    (when (and dirp expanded)
      (let ((real (ignore-errors (file-truename norm))))
        ;; 核心防护：展开符号链接目录时避免递归回父目录导致树无限渲染。
        (if (and real (member real seen))
            (let ((cycle-start (point)))
              (insert (make-string (* (1+ depth) 2) ?\s)
                      "    [symlink cycle]\n")
              (add-text-properties cycle-start (1- (point)) '(face shadow)))
          (dolist (child (pure-builtin-treemacs--children norm))
            (pure-builtin-treemacs--insert-node
             child root (1+ depth) current-file
             (if real (cons real seen) seen))))))))

(defun pure-builtin-treemacs--insert-root (root current-file)
  "Insert ROOT and its children."
  (let* ((norm (pure-builtin-treemacs--normalize-dir root))
         (expanded (pure-builtin-treemacs--expanded-p norm t))
         (marker (if expanded "[-]" "[+]"))
         (name (pure-builtin-treemacs--root-name norm))
         (text (format "%s %s  %s" marker name norm)))
    (push norm pure-builtin-treemacs--rendered-dirs)
    (pure-builtin-treemacs--insert-button-line
     text norm norm 'pure-builtin-treemacs-root-face
     (lambda (_button)
       (pure-builtin-treemacs--toggle-expanded norm t)
       (pure-builtin-treemacs-refresh)))
    (when expanded
      (dolist (child (pure-builtin-treemacs--children norm))
        (pure-builtin-treemacs--insert-node
         child norm 1 current-file
         (let ((real (ignore-errors (file-truename norm))))
           (if real (list real) nil)))))
    (insert "\n")))

(defun pure-builtin-treemacs--goto-path (path)
  "Move point to PATH in the tree buffer."
  (let ((pos (point-min))
        found)
    (while (and (not found) (< pos (point-max)))
      (when (equal (get-text-property pos 'pure-builtin-treemacs-path) path)
        (setq found pos))
      (setq pos (or (next-single-property-change
                     pos 'pure-builtin-treemacs-path nil (point-max))
                    (point-max))))
    (when found
      (goto-char found)
      (beginning-of-line)
      t)))

(defun pure-builtin-treemacs--install-watchers (dirs)
  "Install file notification watchers for visible DIRS."
  (pure-builtin-treemacs--clear-watchers)
  (when (and pure-builtin-treemacs-watch-files
             (fboundp 'file-notify-add-watch))
    (dolist (dir (seq-take (cl-remove-duplicates dirs :test #'equal)
                           pure-builtin-treemacs-max-watched-directories))
      (when (and (file-directory-p dir)
                 (not (file-remote-p dir))
                 (not (gethash dir pure-builtin-treemacs--watchers)))
        (let ((watch (ignore-errors
                       (file-notify-add-watch
                        dir '(change attribute-change)
                        #'pure-builtin-treemacs--file-event))))
          (when watch
            (puthash dir watch pure-builtin-treemacs--watchers)))))))

(defun pure-builtin-treemacs--schedule-watchers (dirs)
  "Schedule file notification watchers for DIRS.
This work is intentionally delayed until idle time because some backends block
noticeably while installing watches."
  (when (timerp pure-builtin-treemacs--watch-timer)
    (cancel-timer pure-builtin-treemacs--watch-timer))
  (if pure-builtin-treemacs-watch-files
      (setq pure-builtin-treemacs--watch-timer
            (run-with-idle-timer
             1.0 nil
             (lambda (scheduled-dirs)
               (setq pure-builtin-treemacs--watch-timer nil)
               (when (get-buffer pure-builtin-treemacs-buffer-name)
                 (pure-builtin-treemacs--install-watchers scheduled-dirs)))
             (copy-sequence dirs)))
    (pure-builtin-treemacs--clear-watchers)))

(defun pure-builtin-treemacs--clear-watchers ()
  "Remove all file notification watchers used by this tree."
  (maphash (lambda (_dir watch)
             (ignore-errors (file-notify-rm-watch watch)))
           pure-builtin-treemacs--watchers)
  (clrhash pure-builtin-treemacs--watchers))

(defun pure-builtin-treemacs--file-event (_event)
  "Handle a file notification event by debouncing refresh."
  (pure-builtin-treemacs--schedule-refresh))

(defun pure-builtin-treemacs--schedule-refresh ()
  "Schedule a tree refresh after a short idle delay."
  (when (timerp pure-builtin-treemacs--refresh-timer)
    (cancel-timer pure-builtin-treemacs--refresh-timer))
  (setq pure-builtin-treemacs--refresh-timer
        (run-with-idle-timer
         0.25 nil
         (lambda ()
           (setq pure-builtin-treemacs--refresh-timer nil)
           (when (get-buffer pure-builtin-treemacs-buffer-name)
             (pure-builtin-treemacs-refresh))))))

(defun pure-builtin-treemacs-refresh ()
  "Refresh the tree buffer."
  (interactive)
  (let* ((buf (get-buffer-create pure-builtin-treemacs-buffer-name))
         (current-file (or pure-builtin-treemacs--current-file
                           (and buffer-file-name
                                (pure-builtin-treemacs--normalize-file buffer-file-name))))
         (remembered-path (and (get-buffer pure-builtin-treemacs-buffer-name)
                               (with-current-buffer pure-builtin-treemacs-buffer-name
                                 (pure-builtin-treemacs--line-path))))
         (roots (pure-builtin-treemacs--workspace-roots))
         (pure-builtin-treemacs--rendered-dirs nil)
         (pure-builtin-treemacs--vc-state-count 0)
         (pure-builtin-treemacs--rendering t))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (pure-builtin-treemacs-mode)
        (erase-buffer)
        (insert (propertize "Pure Builtin Treemacs\n" 'face 'bold))
        (insert (propertize "RET/TAB open  g refresh  f follow  ? help\n\n" 'face 'shadow))
        (if roots
            (dolist (root roots)
              (pure-builtin-treemacs--insert-root root current-file))
          (insert "No project root found.\n"))
        (goto-char (point-min))
        (when remembered-path
          (pure-builtin-treemacs--goto-path remembered-path))))
    (pure-builtin-treemacs--schedule-watchers pure-builtin-treemacs--rendered-dirs)
    buf))

(defun pure-builtin-treemacs--display-buffer ()
  "Display the tree buffer as a left side window."
  (let ((win (display-buffer-in-side-window
              (pure-builtin-treemacs-refresh)
              `((side . left)
                (slot . 0)
                (window-width . ,pure-builtin-treemacs-width)
                (window-parameters . ((no-delete-other-windows . t)))))))
    (set-window-dedicated-p win t)
    (set-window-parameter win 'window-size-fixed 'width)
    (pure-builtin-treemacs--fix-window-width win)
    win))

(defun pure-builtin-treemacs--fix-window-width (&optional window)
  "Restore the sidebar WINDOW to `pure-builtin-treemacs-width'."
  (unless pure-builtin-treemacs--fixing-window-width
    (let* ((win (or window
                    (get-buffer-window pure-builtin-treemacs-buffer-name
                                       (selected-frame))))
           (delta (and (window-live-p win)
                       (- pure-builtin-treemacs-width
                          (window-total-width win)))))
      (when (and delta (/= delta 0))
        (let ((pure-builtin-treemacs--fixing-window-width t))
          ;; Help/quit-window may rebalance side windows.  Temporarily lift the
          ;; preserved-size constraint, restore the target width, then preserve it
          ;; again for later window configuration changes.
          (window-preserve-size win t nil)
          (ignore-errors
            (window-resize win delta t 'safe))
          (let ((remaining (- pure-builtin-treemacs-width
                              (window-total-width win))))
            (unless (= remaining 0)
              (ignore-errors
                (adjust-window-trailing-edge win remaining t))))
          (window-preserve-size win t t))))))

(defun pure-builtin-treemacs--fix-window-width-after-configuration-change ()
  "Keep the sidebar width stable after Help and other windows close."
  (when (get-buffer-window pure-builtin-treemacs-buffer-name
                           (selected-frame))
    (run-with-idle-timer 0 nil #'pure-builtin-treemacs--fix-window-width)))

(defun pure-builtin-treemacs-open ()
  "Open or refresh the pure built-in Treemacs sidebar."
  (interactive)
  (setq pure-builtin-treemacs--auto-root (pure-builtin-treemacs--current-root))
  (select-window (pure-builtin-treemacs--display-buffer)))

(defun pure-builtin-treemacs-toggle ()
  "Toggle the pure built-in Treemacs sidebar."
  (interactive)
  (let ((win (get-buffer-window pure-builtin-treemacs-buffer-name)))
    (if (window-live-p win)
        (delete-window win)
      (pure-builtin-treemacs-open))))

(defun pure-builtin-treemacs-quit ()
  "Close the sidebar window."
  (interactive)
  (let ((win (get-buffer-window pure-builtin-treemacs-buffer-name)))
    (when (window-live-p win)
      (delete-window win))))

(defun pure-builtin-treemacs-visit-path (path)
  "Visit PATH.  Directories are toggled; files are opened in the editor window."
  (interactive)
  (cond
   ((not path)
    (user-error "No tree entry at point"))
   ((file-directory-p path)
    (pure-builtin-treemacs--toggle-expanded
     path
     (member (pure-builtin-treemacs--normalize-dir path)
             (pure-builtin-treemacs--workspace-roots)))
    (pure-builtin-treemacs-refresh))
   (t
    (pure-builtin-treemacs-open-path-in-editor-window path))))

(defun pure-builtin-treemacs-visit-at-point ()
  "Visit the path stored at point."
  (interactive)
  (pure-builtin-treemacs-visit-path (pure-builtin-treemacs--line-path)))

(defun pure-builtin-treemacs-toggle-at-point ()
  "Toggle the directory stored at point."
  (interactive)
  (let ((path (pure-builtin-treemacs--line-path)))
    (unless (and path (file-directory-p path))
      (user-error "No directory at point"))
    (pure-builtin-treemacs-visit-path path)))

(defun pure-builtin-treemacs-open-in-editor-window ()
  "Open the path at point in the main editor window."
  (interactive)
  (pure-builtin-treemacs-open-path-in-editor-window
   (pure-builtin-treemacs--line-path)))

(defun pure-builtin-treemacs-open-in-other-window ()
  "Open the path at point in another window without replacing the tree."
  (interactive)
  (let ((path (pure-builtin-treemacs--line-path)))
    (unless path
      (user-error "No tree entry at point"))
    (if (file-directory-p path)
        (dired-other-window path)
      (find-file-other-window path))))

(defun pure-builtin-treemacs--root-for-file (file)
  "Return an existing or inferred workspace root for FILE."
  (or (cl-find-if
       (lambda (root)
         (file-in-directory-p file root))
       (pure-builtin-treemacs--workspace-roots))
      (pure-builtin-treemacs--current-root (file-name-directory file))))

(defun pure-builtin-treemacs--main-window-file ()
  "Return a file from the selected buffer or the first non-sidebar window."
  (or buffer-file-name
      (cl-loop for win in (window-list (selected-frame) 'nomini)
               unless (eq (window-buffer win)
                          (get-buffer pure-builtin-treemacs-buffer-name))
               thereis (buffer-file-name (window-buffer win)))))

(defun pure-builtin-treemacs--editor-window ()
  "Return the main non-sidebar window used for opened files."
  (or (cl-loop for win in (window-list (selected-frame) 'nomini)
               unless (or (eq (window-buffer win)
                              (get-buffer pure-builtin-treemacs-buffer-name))
                          (window-dedicated-p win))
               return win)
      (user-error "No reusable editor window found")))

(defun pure-builtin-treemacs--show-buffer-in-editor-window (buffer)
  "Show BUFFER in the main editor window without creating a new window."
  (let ((win (pure-builtin-treemacs--editor-window)))
    (when pure-builtin-treemacs-enable-tab-line
      (with-current-buffer buffer
        (tab-line-mode 1)))
    (set-window-buffer win buffer)
    (select-window win)
    buffer))

(defun pure-builtin-treemacs-open-path-in-editor-window (path)
  "Open PATH in the main editor window.
This reuses the existing editor window so `tab-line-mode' can represent the
opened buffer as another tab instead of creating a new Emacs window."
  (unless path
    (user-error "No tree entry at point"))
  (let* ((normalized (if (file-directory-p path)
                         (pure-builtin-treemacs--normalize-dir path)
                       (pure-builtin-treemacs--normalize-file path)))
         (buffer (if (file-directory-p normalized)
                     (dired-noselect normalized)
                   (find-file-noselect normalized))))
    (unless (file-directory-p normalized)
      (setq pure-builtin-treemacs--current-file normalized))
    (pure-builtin-treemacs--show-buffer-in-editor-window buffer)))

(defun pure-builtin-treemacs--ensure-root (root)
  "Ensure ROOT is present when explicit roots are configured."
  (let ((norm (pure-builtin-treemacs--normalize-dir root)))
    (cond
     (pure-builtin-treemacs-roots
      (when (and pure-builtin-treemacs-follow-add-missing-root
                 (not (member norm (pure-builtin-treemacs--workspace-roots))))
        (setq pure-builtin-treemacs-roots
              (append (pure-builtin-treemacs--workspace-roots) (list norm)))))
     (t
      (setq pure-builtin-treemacs--auto-root norm)))
    (pure-builtin-treemacs--set-expanded norm t)
    norm))

(defun pure-builtin-treemacs--expand-path (root file)
  "Expand all directories from ROOT down to FILE."
  (let* ((norm-root (pure-builtin-treemacs--normalize-dir root))
         (dir (if (file-directory-p file)
                  (pure-builtin-treemacs--normalize-dir file)
                (file-name-directory (pure-builtin-treemacs--normalize-file file)))))
    (pure-builtin-treemacs--set-expanded norm-root t)
    (while (and dir
                (file-in-directory-p dir norm-root)
                (not (equal dir norm-root)))
      (pure-builtin-treemacs--set-expanded dir t)
      (setq dir (file-name-directory (directory-file-name dir))))))

(defun pure-builtin-treemacs-follow-current-file (&optional file)
  "Reveal FILE or the current buffer file in the tree."
  (interactive)
  (let ((target (or file (pure-builtin-treemacs--main-window-file))))
    (unless target
      (user-error "Current buffer has no file"))
    (setq target (if (file-directory-p target)
                     (pure-builtin-treemacs--normalize-dir target)
                   (pure-builtin-treemacs--normalize-file target)))
    (setq pure-builtin-treemacs--current-file target)
    (let* ((root (pure-builtin-treemacs--ensure-root
                  (pure-builtin-treemacs--root-for-file target)))
           (buf (pure-builtin-treemacs-refresh))
           (win (get-buffer-window buf)))
      (pure-builtin-treemacs--expand-path root target)
      (setq buf (pure-builtin-treemacs-refresh))
      (unless (window-live-p win)
        (setq win (pure-builtin-treemacs--display-buffer)))
      (with-current-buffer buf
        (pure-builtin-treemacs--goto-path target))
      (when (window-live-p win)
        (set-window-point win (with-current-buffer buf (point)))))))

(defun pure-builtin-treemacs--maybe-follow ()
  "Debounced hook used by `pure-builtin-treemacs-follow-mode'."
  (let ((file buffer-file-name))
    (when (and file
               (not pure-builtin-treemacs--rendering)
               (get-buffer-window pure-builtin-treemacs-buffer-name))
      (when (timerp pure-builtin-treemacs--follow-timer)
        (cancel-timer pure-builtin-treemacs--follow-timer))
      (setq pure-builtin-treemacs--follow-timer
            (run-with-idle-timer
             0.2 nil
             (lambda (f)
               (setq pure-builtin-treemacs--follow-timer nil)
               (when (file-exists-p f)
                 (pure-builtin-treemacs-follow-current-file f)))
             file)))))

(define-minor-mode pure-builtin-treemacs-follow-mode
  "Global mode that keeps the sidebar focused on the current file."
  :global t
  :lighter " PureTreeFollow"
  (if pure-builtin-treemacs-follow-mode
      (progn
        (add-hook 'buffer-list-update-hook #'pure-builtin-treemacs--maybe-follow)
        (add-hook 'after-save-hook #'pure-builtin-treemacs--maybe-follow))
    (remove-hook 'buffer-list-update-hook #'pure-builtin-treemacs--maybe-follow)
    (remove-hook 'after-save-hook #'pure-builtin-treemacs--maybe-follow)))

(defun pure-builtin-treemacs-add-current-project ()
  "Add the current project root to the explicit workspace root list."
  (interactive)
  (let ((root (pure-builtin-treemacs--current-root)))
    (setq pure-builtin-treemacs-roots
          (cl-remove-duplicates
           (append (pure-builtin-treemacs--workspace-roots) (list root))
           :test #'equal))
    (pure-builtin-treemacs--set-expanded root t)
    (pure-builtin-treemacs-refresh)
    (message "Added root: %s" root)))

(defun pure-builtin-treemacs-import-known-projects ()
  "Use `project.el' known projects as explicit workspace roots."
  (interactive)
  (setq pure-builtin-treemacs-roots
        (cl-remove-duplicates
         (cl-remove-if-not #'file-directory-p
                           (mapcar #'pure-builtin-treemacs--normalize-dir
                                   (project-known-project-roots)))
         :test #'equal))
  (dolist (root pure-builtin-treemacs-roots)
    (pure-builtin-treemacs--set-expanded root t))
  (pure-builtin-treemacs-refresh)
  (message "Imported %d known projects" (length pure-builtin-treemacs-roots)))

(defun pure-builtin-treemacs-switch-root (root)
  "Switch the tree to a single ROOT."
  (interactive
   (let* ((known (project-known-project-roots))
          (default (car (pure-builtin-treemacs--workspace-roots)))
          (choice (if known
                      (completing-read "Switch root: " known nil nil nil nil default)
                    (read-directory-name "Switch root: " default nil t))))
     (list choice)))
  (let ((norm (pure-builtin-treemacs--normalize-dir root)))
    (setq pure-builtin-treemacs-roots (list norm))
    (setq pure-builtin-treemacs--auto-root norm)
    (pure-builtin-treemacs--set-expanded norm t)
    (pure-builtin-treemacs-open)))

(defun pure-builtin-treemacs-remove-root-at-point ()
  "Remove the root associated with the current tree line."
  (interactive)
  (let ((root (pure-builtin-treemacs--line-root)))
    (unless root
      (user-error "No root at point"))
    (unless pure-builtin-treemacs-roots
      (user-error "Auto root mode has no explicit root to remove; use q to close or s to switch"))
    (setq pure-builtin-treemacs-roots
          (cl-remove (pure-builtin-treemacs--normalize-dir root)
                     (pure-builtin-treemacs--workspace-roots)
                     :test #'equal))
    (pure-builtin-treemacs-refresh)
    (message "Removed root: %s" root)))

(defun pure-builtin-treemacs-toggle-dotfiles ()
  "Toggle visibility of dotfiles."
  (interactive)
  (setq pure-builtin-treemacs-hide-dotfiles
        (not pure-builtin-treemacs-hide-dotfiles))
  (pure-builtin-treemacs-refresh)
  (message "Dotfiles are now %s"
           (if pure-builtin-treemacs-hide-dotfiles "hidden" "visible")))

(defun pure-builtin-treemacs-collapse-all ()
  "Collapse all workspace roots and directories."
  (interactive)
  (clrhash pure-builtin-treemacs--expanded)
  (dolist (root (pure-builtin-treemacs--workspace-roots))
    (pure-builtin-treemacs--set-expanded root nil))
  (pure-builtin-treemacs-refresh))

(defun pure-builtin-treemacs--target-directory ()
  "Return the directory relevant to point."
  (let ((path (pure-builtin-treemacs--line-path)))
    (cond
     ((and path (file-directory-p path)) path)
     (path (file-name-directory path))
     (t (car (pure-builtin-treemacs--workspace-roots))))))

(defun pure-builtin-treemacs-create-file (file)
  "Create FILE under the current tree directory."
  (interactive
   (list (read-file-name "Create file: "
                         (pure-builtin-treemacs--target-directory))))
  (when (file-exists-p file)
    (user-error "File already exists: %s" file))
  (make-directory (file-name-directory file) t)
  (write-region "" nil file nil 'silent)
  (pure-builtin-treemacs-follow-current-file file)
  (message "Created file: %s" file))

(defun pure-builtin-treemacs-create-directory (dir)
  "Create DIR under the current tree directory."
  (interactive
   (list (read-directory-name "Create directory: "
                              (pure-builtin-treemacs--target-directory))))
  (make-directory dir t)
  (pure-builtin-treemacs--set-expanded dir t)
  (pure-builtin-treemacs-follow-current-file dir)
  (message "Created directory: %s" dir))

(defun pure-builtin-treemacs-rename (new-name)
  "Rename the file or directory at point to NEW-NAME."
  (interactive
   (let ((path (pure-builtin-treemacs--line-path)))
     (unless path
       (user-error "No tree entry at point"))
     (list (read-file-name "Rename to: " (file-name-directory path)
                           nil nil (file-name-nondirectory
                                    (directory-file-name path))))))
  (let ((old-name (pure-builtin-treemacs--line-path)))
    (rename-file old-name new-name 1)
    (remhash (pure-builtin-treemacs--normalize-dir old-name)
             pure-builtin-treemacs--expanded)
    (when (file-directory-p new-name)
      (pure-builtin-treemacs--set-expanded new-name t))
    (pure-builtin-treemacs-follow-current-file new-name)
    (message "Renamed %s to %s" old-name new-name)))

(defun pure-builtin-treemacs-delete ()
  "Delete the file or directory at point after confirmation."
  (interactive)
  (let ((path (pure-builtin-treemacs--line-path)))
    (unless path
      (user-error "No tree entry at point"))
    (when (member (pure-builtin-treemacs--normalize-dir path)
                  (pure-builtin-treemacs--workspace-roots))
      (user-error "Refusing to delete a workspace root; use r to remove it from the tree"))
    (when (yes-or-no-p (format "Delete %s? " path))
      (if (file-directory-p path)
          (delete-directory path t)
        (delete-file path))
      (pure-builtin-treemacs-refresh)
      (message "Deleted: %s" path))))

(defun pure-builtin-treemacs-copy-path ()
  "Copy the file path at point."
  (interactive)
  (let ((path (pure-builtin-treemacs--line-path)))
    (unless path
      (user-error "No tree entry at point"))
    (kill-new path)
    (message "Copied: %s" path)))

(defun pure-builtin-treemacs-find-file (file)
  "Read FILE and open it in the main editor window."
  (interactive
   (list (read-file-name "Find file: "
                         (pure-builtin-treemacs--target-directory))))
  (pure-builtin-treemacs-open-path-in-editor-window file))

(defun pure-builtin-treemacs-dired ()
  "Open Dired for the directory relevant to point in the main editor window."
  (interactive)
  (pure-builtin-treemacs-open-path-in-editor-window
   (pure-builtin-treemacs--target-directory)))

(defun pure-builtin-treemacs-vc-dir ()
  "Open built-in `vc-dir' for the root relevant to point in the editor window."
  (interactive)
  (let ((root (or (pure-builtin-treemacs--line-root)
                  (car (pure-builtin-treemacs--workspace-roots)))))
    (unless root
      (user-error "No project root"))
    (select-window (pure-builtin-treemacs--editor-window))
    (vc-dir root)))

(defun pure-builtin-treemacs-project-find-file ()
  "Run `project-find-file' from the root relevant to point in the editor window."
  (interactive)
  (let ((default-directory (or (pure-builtin-treemacs--line-root)
                               (car (pure-builtin-treemacs--workspace-roots)))))
    (select-window (pure-builtin-treemacs--editor-window))
    (when pure-builtin-treemacs-enable-tab-line
      (tab-line-mode 1))
    (call-interactively #'project-find-file)))

(defun pure-builtin-treemacs-project-search ()
  "Run `project-find-regexp' from the root relevant to point."
  (interactive)
  (let ((default-directory (or (pure-builtin-treemacs--line-root)
                               (car (pure-builtin-treemacs--workspace-roots)))))
    (select-window (pure-builtin-treemacs--editor-window))
    (call-interactively #'project-find-regexp)))

(defun pure-builtin-treemacs--expanded-alist ()
  "Return expansion hash table as an alist."
  (let (items)
    (maphash (lambda (k v) (push (cons k v) items))
             pure-builtin-treemacs--expanded)
    items))

(defun pure-builtin-treemacs-save-session ()
  "Persist roots and expansion state to `pure-builtin-treemacs-state-file'."
  (interactive)
  (when pure-builtin-treemacs-save-session-enabled
    (make-directory (file-name-directory pure-builtin-treemacs-state-file) t)
    (with-temp-file pure-builtin-treemacs-state-file
      (prin1 `(:roots ,pure-builtin-treemacs-roots
               :auto-root ,pure-builtin-treemacs--auto-root
               :expanded ,(pure-builtin-treemacs--expanded-alist)
               :hide-dotfiles ,pure-builtin-treemacs-hide-dotfiles)
             (current-buffer)))))

(defun pure-builtin-treemacs-load-session ()
  "Load persisted roots and expansion state."
  (interactive)
  (when (file-readable-p pure-builtin-treemacs-state-file)
    (condition-case err
        (let ((state (with-temp-buffer
                       (insert-file-contents pure-builtin-treemacs-state-file)
                       (read (current-buffer)))))
          (setq pure-builtin-treemacs-roots (plist-get state :roots))
          (setq pure-builtin-treemacs--auto-root (plist-get state :auto-root))
          (setq pure-builtin-treemacs-hide-dotfiles
                (plist-get state :hide-dotfiles))
          (clrhash pure-builtin-treemacs--expanded)
          (dolist (item (plist-get state :expanded))
            (when (file-exists-p (car item))
              (puthash (car item) (cdr item)
                       pure-builtin-treemacs--expanded))))
      (error
       (message "Failed to load pure-builtin-treemacs session: %S" err)))))

;;; Global user-facing keybindings.
(global-set-key (kbd "C-c t t") #'pure-builtin-treemacs-toggle)
(global-set-key (kbd "C-c t f") #'pure-builtin-treemacs-follow-current-file)
(global-set-key (kbd "C-c t a") #'pure-builtin-treemacs-add-current-project)
(global-set-key (kbd "C-c t A") #'pure-builtin-treemacs-import-known-projects)
(global-set-key (kbd "C-c t s") #'pure-builtin-treemacs-switch-root)
(global-set-key (kbd "C-c t v") #'pure-builtin-treemacs-vc-dir)

;; 自动加载上次会话，并在退出 Emacs 时保存。只写入 user-emacs-directory 下的状态文件。
(pure-builtin-treemacs-load-session)
(add-hook 'window-configuration-change-hook
          #'pure-builtin-treemacs--fix-window-width-after-configuration-change)
(add-hook 'kill-emacs-hook #'pure-builtin-treemacs-save-session)

(provide 'pure-builtin-treemacs)
;;; pure-builtin-treemacs.el ends here
