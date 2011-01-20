;; +-------------------------------------------------------------------------
;; | HTML Editors
;; +-------------------------------------------------------------------------
(in-package :core-server)

;; --------------------------------------------------------------------------
;; Ck Editor
;; --------------------------------------------------------------------------
(defcomponent ckeditor-component ()
  ((instance :host remote)
   (target :host remote)
   (config :host remote
	   :initform (jobject
		      :base-path "http://www.coretal.net/js/ckeditor/"))))

(defmethod/remote get-data ((self ckeditor-component))
  (let* ((instance (instance self))
	 (foo (event () (.get-data instance))))
    (foo)))

(defmethod/remote call-component ((self ckeditor-component))
  (_debug (list "ckeditor-config" (config self)))
  (let* ((textarea (target self))
	 (editor (-c-k-e-d-i-t-o-r.replace textarea (config self)))
	 (form (slot-value textarea 'form)))
    (setf (instance self) editor)
    (setf (slot-value form 'submit)
	  (event (e)
	    (let ((data (.get-data editor)))
	      (try (.destroy editor) (:catch (err) nil))
	      (with-call/cc
		(make-web-thread
		 (lambda ()
		   (answer-component self data)))))
	    (return false)))
    (call-next-method self)))

(defmethod/remote destroy ((self ckeditor-component))  
  (let ((foo (event (e) (try (.destroy e) (:catch (err) nil)))))
    (foo (instance self))
    (delete-slot self 'instance)
    (remove-css "http://www.coretal.net/style/ckeditor.css")
    (call-next-method self)))

(defmethod/remote init ((self ckeditor-component))
  (load-css "http://www.coretal.net/style/ckeditor.css")
  (load-javascript "http://www.coretal.net/js/ckeditor/ckeditor.js"
   (lambda ()
     (and (not (null -c-k-e-d-i-t-o-r))
	  (not (null (slot-value -c-k-e-d-i-t-o-r 'replace)))))))

;; (defvar +fck-image-extensions+ '("bmp" "gif" "jpeg" "jpg" "png" "psd" "tif" "tiff"))
;; (defvar +fck-flash-extensions+ '("swf" "fla"))
;; (defvar +fck-media-extensions+
;;   '("aiff" "asf" "avi" "bmp" "fla" "flv" "gif" "jpeg" "jpg"
;;     "mid" "mov" "mp3" "mp4" "mpc" "mpeg" "mpg" "png" "qt"
;;     "ram" "rm" "rmi" "rmvb" "swf" "tif" "tiff" "wav" "wma" "wmv"))

;; ;; TODO: fix this
;; (defun/cc handle-fck-browse (path publish-path)
;;   (let ((stream (http-response.stream (context.response +context+))))
;;     (labels ((send-error (number &optional message)
;; 	       (string! stream (format nil "<Error number=\"~A\"" number))
;; 	       (if message (format nil "text=\"~A\"" message))
;; 	       (string! stream (format nil "/>~%")))
;; 	     (folder-pathname (folder)
;; 	       (merge-pathnames			      
;; 		(make-pathname :directory (list :relative folder))
;; 		(make-pathname :directory (pathname-directory (pathname path)))))
;; 	     (files-by-extensions (folder-pathname exts)
;; 	       (reduce #'(lambda (acc atom)
;; 			   (append
;; 			    (directory
;; 			     (pathname
;; 			      (format nil "~A*.~A" folder-pathname atom)))
;; 			    acc))
;; 		       exts :initial-value nil)) 
;; 	     (files (folder-pathname type)
;; 	       (string! stream (format nil "<Files>~%"))
;; 	       (mapcar #'(lambda (file)
;; 			   (when (pathname-name file)
;; 			     (string! stream
;; 				      (concatenate 'string
;; 						   "<File name=\""
;; 						   (pathname-name file) "." (pathname-type file)
;; 						   "\" size=\"" (format nil "~D"
;; 									(round
;; 									 (/ (sb-posix:stat-size (sb-posix:stat file))
;; 									    1000)))
;; 						   "\" url=\"" publish-path))
;; 			     (mapcar #'(lambda (path)
;; 					 (string! stream (concatenate 'string path "/")))
;; 				     (reverse
;; 				      (set-difference
;; 				       (pathname-directory file)
;; 				       (pathname-directory (pathname path))
;; 				       :test #'equal)))
;; 			     (string! stream
;; 				      (concatenate 'string (pathname-name file) "." (pathname-type file) "\"/>" ~%))))
;; 		       (cond
;; 			 ((equal type "Flash") (files-by-extensions folder-pathname +fck-flash-extensions+))
;; 			 ((equal type "Image") (files-by-extensions folder-pathname +fck-image-extensions+))
;; 			 ((equal type "Media") (files-by-extensions folder-pathname +fck-media-extensions+))
;; 			 (t (directory (pathname (format nil "~A*.*" folder-pathname))))))
;; 	       (string! stream (concatenate 'string "</Files>" ~%)))
;; 	     (folders (folder-pathname)	       
;; 	       (string! stream (concatenate 'string "<Folders>" ~%))
;; 	       (mapcar #'(lambda (dir)
;; 			   (string! stream (concatenate 'string "<Folder name=\""
;; 							(car (reverse (pathname-directory dir))) "\"/>" ~%)))
;; 		       (directory
;; 			(make-pathname :directory (pathname-directory folder-pathname)
;; 				       :name :wild)))
;; 	       (string! stream (concatenate 'string "</Folders>" ~%)))
;; 	     (create-folder (folder new-folder)
;; 	       (let ((new-folder (make-pathname :directory (append (pathname-directory folder)
;; 								   (list new-folder)))))
;; 		 (if (probe-file new-folder)
;; 		     (send-error 101)
;; 		     (progn
;; 		       (ensure-directories-exist new-folder)
;; 		       (if (not (probe-file new-folder))
;; 			   (send-error 102))))))
;; 	     (create-file (folder file)
;; 	       ;; (setf (get-header (context.response *context*) "Content-Type") "text/html; charset=utf-8")
;; 	       ;; 	     (if (rfc2388:mime-part-p file)		 
;; 	       ;; 		 (progn
;; 	       ;; 		   (save-mime-file
;; 	       ;; 		    file
;; 	       ;; 		    (make-pathname :directory (pathname-directory folder)
;; 	       ;; 				   :name (pathname-name (pathname (get-mime-filename file)))
;; 	       ;; 				   :type (pathname-type (pathname (get-mime-filename file)))))
;; 	       ;; 		   (<:script
;; 	       ;; 		    (<:js `(window.parent.*on-upload-completed 0 "" ,(get-mime-filename file) ""))))
;; 	       ;; 		 (<:script
;; 	       ;; 		  (<:js `(window.parent.*on-upload-completed 1 "" "" "Error."))))
;; 	       ;; 	     (flush-request-response *context*)
;; 	       (format t "creating file:~A in folder:~A" file folder)
;; 	       (return-from handle-fck-browse nil)))
;;       (with-query ((command "Command") (type "Type")) (context.request +context+)      
;; 	(if (equal command "FileUpload")
;; 	    (with-query ((folder "CurrentFolder") (file "NewFile")) (context.request +context+)
;; 	      (create-file (folder-pathname folder) file)))
      
;; 	(xml/suspend
;; 	 (lambda (stream)	   
;; 	   (string! stream (format nil "<?xml version=\"1.0\" encoding=\"utf-8\" ?>~%
;; <Connector command=\"~A\" resourceType=\"~A\">~%" command type))

;; 	   ;;      (describe (context.request *context*))
	     
;; 	   (with-query ((folder "CurrentFolder")) (context.request +context+)
;; 	     (string! stream (format nil "<CurrentFolder path=\"~A\" url=\"\"/>~%" folder))
;; 	     (cond
;; 	       ((equal command "GetFolders")	   
;; 		(folders (folder-pathname folder)))
;; 	       ((equal command "GetFoldersAndFiles")	   
;; 		(folders (folder-pathname folder))
;; 		(files (folder-pathname folder) type))
;; 	       ((equal command "CreateFolder")
;; 		(with-query ((new-folder "NewFolderName")) (context.request +context+)
;; 		  (create-folder (folder-pathname folder) new-folder)))
;; 	       (t (send-error 1 "Error.")))
;; 	     (string! stream "</Connector>"))))))))

;; (defcomponent fckeditor-component ()
;;   ())

;; (defmethod/local fck-editor-config-url ((self fckeditor-component))
;;   (action/url ()
;;     (javascript/suspend
;;      (lambda (stream)
;;        (let ((path (format nil "~Aeditor/skins/silver/" +fckeditor-path+)))
;; 	 (with-js (path) stream
;; 	   (setf (aref *f-c-k-config.*toolbar-sets "CoreDefault")
;; 		 (array
;; 		  (array "Save" "Undo" "Redo" "-")
;; 		  (array "Cut" "Copy" "Paste" "PasteText" "PasteWord")
;; 		  (array "Bold" "Italic" "Underline" "StrikeThrough")
;; 		  (array "OrderedList" "UnorderedList" "-" "Outdent" "Indent" "Blockquote")
;; 		  (array "JustifyLeft" "JustifyCenter" "JustifyRight" "JustifyFull")
;; 		  (array "TextColor" "BGColor")
;; 		  (array "Image" "Flash" "Table" "Rule")
;; 		  (array "Link" "Unlink" "Anchor")
;; 		  (array "SpecialChar" "ShowBlocks" "-" "Source")
;; 		  "/"
;; 		  (array "FontFormat" "Style" "FontName" "FontSize"))
;; 		 *f-c-k-config.*skin-path path
;; 		 *f-c-k-config.*toolbar-can-collapse false)))))))

;; (defmethod/local fck-editor-browser-url ((self fckeditor-component))
;;   (action/url ()
;;    (handle-fck-browse (format nil "/var/www/~A/" (web-application.fqdn (application self)))    
;; 		      (format nil "/~A/" (web-application.fqdn (application self))))))

;; (defjsmacro fckeditor-path ()
;;   +fckeditor-path+)

;; (defjsmacro fckeditor-url ()
;;   `(+ ,+fckeditor-path+ "fckeditor.js"))

;; (defjsmacro fckeditor-browser-url ()
;;   `(+ ,+fckeditor-path+ "editor/filemanager/browser/default/browser.html?Connector="))

;; (defmethod/remote create-fck-editor ((self fckeditor-component) id width height)  
;;   (if (= "undefined" (typeof *f-c-keditor))
;;       (dojo.xhr-get (create :url (fckeditor-url)
;; 			    :sync t
;; 			    :handle-as "javascript")))
;;   (if (= "undefined" (typeof *f-c-k-editor))
;;       (let ((script (document.create-element "script")))
;; 	(setf script.src (fckeditor-url))
;; 	(.append-child (aref (document.get-elements-by-tag-name "head") 0) script)))
;;   (let ((fck (new (*f-c-keditor id width height)))
;; 	(config (slot-value fck '*config))
;; 	(browse-path (+ (fckeditor-browser-url)
;; 			base-url
;; 			(.replace
;; 			 (.replace (.replace (this.fck-editor-browser-url) "&" "%26") "&" "%26")
;; 			 "?" "%3F"))))
	  
;;     (setf fck.*toolbar-set "CoreDefault"
;; 	  fck.*base-path (fckeditor-path)
;; 	  config.*custom-configurations-path (+ base-url (this.fck-editor-config-url))
;; 	  config.*link-browser-u-r-l browse-path
;; 	  config.*image-browser-u-r-l browse-path
;; 	  config.*flash-browser-r-u-l browse-path
;; 	  config.*link-upload false
;; 	  config.*image-upload false
;; 	  config.*flash-upload false)
;;     (return fck)))

;; Core Server: Web Application Server

;; Copyright (C) 2006-2008  Metin Evrim Ulu, Aycan iRiCAN

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
