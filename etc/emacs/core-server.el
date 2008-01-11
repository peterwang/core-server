;; Core-serveR Emacs Configuration
;;(setenv "LANG" "tr_TR.UTF-8")
;;(setenv "LC_ALL" "tr_TR.UTF-8")

(if (null (getenv "CORESERVER_HOME"))
    (error "Environment variable CORESERVER_HOME is not set."))

(defun load-el (str)
  "Load the el file in the core-server base directory"
  (let ((file (concat (concat (getenv "CORESERVER_HOME") "etc/emacs/") str)))
    (load file)))

; IBUFFER
(autoload 'ibuffer "ibuffer" "List buffers." t)
(global-set-key (kbd "C-x C-b") 'ibuffer)
;;(column-number-mode)

;; PAREDIT
(load-el "paredit-beta.el")
;;(load-el "paredit-7.0b4.el")

(autoload 'enable-paredit-mode "paredit" 
  "Minor mode for pseudo-structurally editing Lisp code." t)
(add-hook 'lisp-mode-hook 'enable-paredit-mode)

;; Highlights Parenthesis
(show-paren-mode t)

;; SLIME
(add-to-list 'load-path (concat (getenv "CORESERVER_HOME") "lib/slime/slime/"))
(add-to-list 'load-path (concat (getenv "CORESERVER_HOME") "lib/slime/slime/contrib/"))
(require 'slime)
(add-hook 'slime-load-hook (lambda () 
			     (require 'slime-fuzzy)
			     (slime-fuzzy-init)))

(setq inferior-lisp-program "/usr/bin/sbcl --dynamic-space-size 1024"
      lisp-indent-function 'common-lisp-indent-function
      slime-complete-symbol-function 'slime-fuzzy-complete-symbol
      slime-startup-animation nil
      slime-net-coding-system 'utf-8-unix
      slime-multiprocessing t)

(global-set-key "\C-cs" 'slime-selector)
(defun save-and-load-and-compile () 
  (interactive) (save-buffer)
  (interactive) (slime-compile-and-load-file))

(add-hook 'slime-mode-hook (lambda ()
			     (slime-define-key "\C-c\C-k" 
					       'save-and-load-and-compile)))

(slime-setup '(slime-fancy slime-asdf))
;;(setq (get 'defmethod/cc 'common-lisp-indent-function) 'lisp-indent-defmethod
;;      (get 'defmethod/unit 'common-lisp-indent-function) 'lisp-indent-defmethod)

;; DARCSUM
(load-el "darcsum.el")

(defun core ()
  (interactive)
  (slime-connect "127.0.0.1" 4005)
  (slime-repl-set-package "core-server"))

(setq speedbar-track-mouse-flag t)

; MOUSE SCROLL
(mouse-wheel-mode 1)

; SLOPPY FOCUS
(setq mouse-autoselect-window t)

;; proper indentation
(setf *core-server-methods* '(defmethod/cc
			      defmethod/unit
			      defmethod/local
			      defmethod/remote))

(setf *core-server-functions* '(defun/cc))

(defun cl-indent (sym indent) ;; by Pierpaolo Bernardi
  (put sym 'common-lisp-indent-function
       (if (symbolp indent)
	   (get indent 'common-lisp-indent-function)
	   indent)))

(dolist (i *core-server-methods*)
  (cl-indent i 'defmethod))

(dolist (i *core-server-functions*)
  (cl-indent i 'defun))

; Function to run Tidy HTML parser on buffer
; NOTE: this requires external Tidy program
(defun tidy-buffer ()
  "Run Tidy HTML parser on current buffer."
  (interactive)
  (if (get-buffer "tidy-errs") (kill-buffer "tidy-errs"))
  (shell-command-on-region (point-min) (point-max)
                           ;;"tidy -f /tmp/tidy-errs -asxhtml -q -utf8 -i -wrap 72 -c"
                           "tidy -f /tmp/tidy-errs -asxhtml --doctype transitional --char-encoding utf8 --output-encoding utf8 --add-xml-decl y --indent-attributes y --gnu-emacs y --tidy-mark n -q -utf8 -i -w 0" t)
  (find-file-other-window "/tmp/tidy-errs")
  (other-window 1)
  (delete-file "/tmp/tidy-errs")
  (message "buffer tidy'ed"))

(define-skeleton coretal-insert-link
  "Make a dynamic link"
  "Link text: "
  '(progn 
     (setq anchor (skeleton-read "Page anchor:"))
     (setq page-name (buffer-name (current-buffer))))
  "<a href=\"" page-name "#" anchor "\" onclick=\"return coretal.loadPage('" anchor "');\">" str "</a>")
