;; Core-serveR Emacs Configuration
;;(setenv "LANG" "tr_TR.UTF-8")
;;(setenv "LC_ALL" "tr_TR.UTF-8")

(if (null (getenv "CORESERVER_HOME"))
    (error "Environment variable CORESERVER_HOME is not set."))

(defun load-el (str)
  "Load the el file in the core-server base directory"
  (load (concat (getenv "CORESERVER_HOME") "etc/emacs/" str)))

; IBUFFER
(autoload 'ibuffer "ibuffer" "List buffers." t)
(global-set-key (kbd "C-x C-b") 'ibuffer)
(column-number-mode)

;; PAREDIT
;;(load-el "paredit-beta.el")
(load-el "paredit-7.0b4.el")

(autoload 'enable-paredit-mode "paredit" 
  "Minor mode for pseudo-structurally editing Lisp code." t)
(add-hook 'lisp-mode-hook 'enable-paredit-mode)

;; Highlights Parenthesis
(show-paren-mode t)

;; SLIME
(add-to-list 'load-path (concat 
			 (getenv "CORESERVER_HOME"
				 "lib/slime/slime.el")))
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
(setq (get 'defmethod/cc 'common-lisp-indent-function) 'lisp-indent-defmethod
      (get 'defmethod/unit 'common-lisp-indent-function) 'lisp-indent-defmethod)

;; DARCSUM
(load-el "darcsum.el")