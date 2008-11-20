;; +----------------------------------------------------------------------------
;; | Extra Components
;; +----------------------------------------------------------------------------
(in-package :core-server)

;; ----------------------------------------------------------------------------
;; Hilighter
;; ----------------------------------------------------------------------------
(defcomponent hilighter ()
  ((menu-query :host remote :accessor menu-query :initarg :menu-query
	       :initform ".menu a")
   (active-class :host remote :initarg :active-class :initform "active")
   (passive-class :host remote :initarg :passive-class :initform "")))

(defmethod/remote hilight ((self hilighter) anchor)
  (dolist (item (dojo.query this.menu-query))
    (if (= anchor (item.hash.substr 1))
	(setf item.parent-node.class-name this.active-class
	      item.class-name this.active-class)
	(setf item.parent-node.class-name this.passive-class
	      item.class-name this.passive-class))))

;; ----------------------------------------------------------------------------
;; Toaster Component
;; ----------------------------------------------------------------------------
(defcomponent toaster-component ()
  ((toaster :host remote :initform nil)))

(defmethod/remote toast ((self toaster-component) message)
  (if (= null this.toaster)
      (progn
	(dojo.require "dojox.widget.Toaster")
	(let ((div (document.create-element "div")))
	  (document.body.append-child div)
	  (setf this.toaster (new (dojox.widget.*toaster
				   (create :position-direction "br-left"
					   :message-topic "toasterTopic"
					   :duration 1000)
				   div))))))

  (dojo.publish "toasterTopic" (array message)))

;; (defcomponent dojo-widget (dom-element)
;;   ((dojo-type :initarg :dojo-type :initform (error "Please specify :dojo-type"))
;;    (dojo-args :initarg :dojo-args :initform '())))

;; (defmethod/local render ((self dojo-widget))
;;   (with-html-output (http-response.stream (context.response +context+))
;;     (<:p "This is a dojo widget.")))

;; (defmethod/cc send/ctor ((self dojo-widget) remote-slots local-methods remote-methods)
;; ;;;   (js:js*
;; ;;;    `(defun ,(class-name (class-of self)) ()
;; ;;; 	(let ((o (create ,@remote-slots ,@local-methods ,@remote-methods))
;; ;;; 	      (p (document.create-element o.tag)))
;; ;;; 	  (doeach (property o)
;; ;;; 	    (setf (slot-value p property) (slot-value o property)))
	  
;; ;;; 	  (if (= "function" (typeof o.render))		
;; ;;; 	      (setf p.inner-h-t-m-l (o.render)))
	  
;; ;;; ;;	  (dojo.require "dojo.xml.Parse")
;; ;;; 	  (dojo.require ,(format nil "~A" (js::symbol-to-js (slot-value self 'dojo-type))))
;; ;;; ;;; 	  (let ((parser (new (dojo.xml.*parse)))
;; ;;; ;;; 		(frag (parser.parse-element p nil t)))
;; ;;; ;;; 	    (.create-components (dojo.widget.get-parser) frag))
;; ;;; 	  (setf this.prototype
;; ;;; 		(new (,(slot-value self 'dojo-type) (create ,@(slot-value self 'dojo-args)) p)))
;; ;;; 	  (return this.prototype))))
;;   (error "fixme"))

;; (defmethod dom-element! ((stream core-stream) (element dojo-widget) &optional (indentation 0))
;;   (flet ((indent ()
;; 	   (dotimes (i indentation)
;; 	     (char! stream #\Space)
;; 	     (char! stream #\Space)))
;; 	 (child! (child)
;; 	   (if (stringp child)
;; 	       (string! stream child)
;; 	       (progn
;; 		 (char! stream #\Newline)
;; 		 (dom-element! stream child (+ indentation +indentation-increment+))))))
;;     (prog1 stream
;;       (indent)
;;       (char! stream #\<)
;;       (string! stream (tag element))
;;       (mapcar (lambda (attr)
;; 		(char! stream #\Space)
;; 		(string! stream (car attr))
;; 		(char! stream #\=)
;; 		(char! stream #\")
;; 		(string! stream (cdr attr))
;; 		(char! stream #\"))
;; 	      (attributes element))      
;;       (char! stream #\>)
      
;;       (dom-element! stream 
;; 		    (<:script :type "text/javascript"
;; 			      (with-call/cc (send/component element))))      
;;       (cond
;; 	((eq 0 (length (children element)))
;; 	 )
;; 	((eq 1 (length (children element)))
;; 	 (mapcar #'child! (children element)))
;; 	(t	 
;; 	 (mapcar #'child! (children element))
;; 	 (char! stream #\Newline)
;; 	 (indent)))
;;       (string! stream "</")
;;       (string! stream (tag element))
;;       (char! stream #\>))))


;; (defmacro defdojo (name supers slots &rest default-initargs)
;;   (let ((attributes (make-attributes attributes))
;; 	(symbol-package (symbol-package name)))
;;     `(prog1 (defclass ,name (dojo-element)
;; 	      ())
;;        (defun ,name (&rest args)
;; 	 (multiple-value-bind (attributes children) (tag-attributes args)
;; 	   (destructuring-bind (&key ,@attributes) attributes
;; 	     (validate-dom-tree
;; 	      (apply #'make-dom-element ,(symbol-name name)		     
;; 		     (remove-if (lambda (attr)
;; 				  (if (null (cdr attr))
;; 				      t))
;; 				(list ,@(mapcar (lambda (attr)
;; 						  `(cons ,(symbol-to-js attr) ,attr))
;; 						attributes)))
;; 		     children)))))
;;        (export ',name (find-package ,(package-name symbol-package))))))

;; (defcomponent <dijit::dialog (dojo-widget)
;;   ((xopen :host remote :initarg :xopen)
;;    (duration :host remote :initarg :duration)
;;    (title :host remote :initarg :title))
;;   (:default-initargs :dojo-type 'dijit.*Dialog :tag "DIV"))

;; ----------------------------------------------------------------------------
;; Form
;; ----------------------------------------------------------------------------

;; form component
(defcomponent web-form-component (toaster-component)
  ((form-id :host remote :initarg :form-id :initform "feedback"
	    :documentation "id of the form element")))

;; return form element
(defmethod/remote current-form ((self web-form-component))
  (return ($ this.form-id)))

;; send form as html
(defmethod/local sendform ((self web-form-component) form)
  (let ((f (format nil "<html><head><meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\"></head><body><div id=\"form\">~A</div></body></html>" (cl-ppcre::regex-replace-all "\\\\n" form ""))))
    (sendmail
     (application.server (application self)) ;; mail-sender
     (format nil "noreply@~A" (web-application.fqdn (application self))) ;; from
     (web-application.admin-email (application self)) ;; to
     "A form has been submitted." ;; subject
     f ;; html-message
     )))

;; add value attributes with current input values
(defmethod/remote setformvals ((self web-form-component))
  (.for-each (dojo.query "*" (this.get-form-id))
	     (lambda (i)
	       (case (i.tag-name.to-lower-case)
		 ("textarea"
		  (i.append-child (document.create-text-node i.value)))
		 ("input"
		  (case i.node-type
		    ("checkbox"
		     false)
		    ("radio"
		     (when i.checked
		       (i.set-attribute "checked" "true")))
		    (t
		     (i.set-attribute "value" i.value))))))))

;; initialize component, hook form's onsubmit
(defmethod/remote initialize ((self web-form-component) obj)
  (if (= null (this.current-form))
      (this.toast "Feedback div not found, aborting feedback component.")
      (let ((form (this.current-form)))
	(setf form.onsubmit
	      (lambda ()
		(let ((orig (.clone-node (obj.form) "deep")))
		  (.for-each (.filter (dojo.query "[type=radio]" (obj.get-form-id))
				      (lambda (e)
					(return e.checked))) 
			     (lambda (e)
			       (e.parent-node.replace-child (document.create-text-node "X") e)))
		  (obj.setformvals)
		  (obj.sendform form.inner-h-t-m-l)
		  (.parent-node.replace-child (obj.form) orig (obj.form))
		  (obj.toast "Form successfuly sent. Thank you.")
		  (return false)))))))

;; (defurl *test* "forms.can" ()
;;   (javascript/suspend
;;    (lambda ()
;;      (dojo "forms.can")
;;      (mapcar #'send/component (list (make-instance 'web-form-component)))
;;      (<:js
;;        `(progn
;;      	  (setf form (new (web-form-component)))
;;      	  (dojo.add-on-load (lambda ()
;;      			      (form.initialize form))))))))

;; ----------------------------------------------------------------------------
;; Social Share
;; ----------------------------------------------------------------------------
(defcomponent socialshare-component (toaster-component)
  ((socialshare-id :host remote :initarg :socialshare-id :initform "socialshare"
		   :documentation "id of the socialshare div element")))

(defmethod/remote make-link ((self socialshare-component) href text icon-url)
  (let ((a (document.create-element "A"))
	(img (document.create-element "IMG")))
    (a.set-attribute "href" href)
    (a.set-attribute "title" text)
    (img.set-attribute "src" icon-url)
    (img.set-attribute "alt" text)
    (setf img.border "0")
    (a.append-child img)
    (return a)))

;; reddit, delicious, stumbleupon, digg, dzone
(defmethod/remote make-type1-link ((self socialshare-component) base text icon url title)
  (return (this.make-link (+ base "?url=" (encode-u-r-i-component url) "&title=" title) text icon)))

;; yahoo, facebook
(defmethod/remote make-type2-link ((self socialshare-component) base text icon url title)
  (return (this.make-link (+ base "?u=" (encode-u-r-i-component url) "&t=" title) text icon)))

;; google
(defmethod/remote make-type3-link ((self socialshare-component) base text icon url title)
  (return (this.make-link (+ base "?op=edit&bkmk=" (encode-u-r-i-component url) "&title=" title) text icon)))

;; http://reddit.com/submit?url=...&title=...
(defmethod/remote make-reddit-link ((self socialshare-component) url title)
  (return (this.make-type1-link "http://reddit.com/submit"
				"reddit"
				"http://www.core.gen.tr/images/sociallinks/reddit.gif"
				url title)))

;; http://www.google.com/bookmarks/mark?op=edit&bkmk=<url>&title=<title>
(defmethod/remote make-google-link ((self socialshare-component) url title)
  (return (this.make-type3-link "http://www.google.com/bookmarks/mark"
                                "google"
				"http://www.core.gen.tr/images/sociallinks/google.jpg"
				url title)))

;; http://del.icio.us/post?url=...&title=...
(defmethod/remote make-delicious-link ((self socialshare-component) url title)
  (return (this.make-type1-link "http://del.icio.us/post"
				"del.icio.us"
				"http://www.core.gen.tr/images/sociallinks/delicious.gif"
				url title)))

;; http://www.stumbleupon.com/submit?url=...&title=...
(defmethod/remote make-stumbleupon-link ((self socialshare-component) url title)
  (return (this.make-type1-link "http://www.stumbleupon.com/submit"
				"stumbleupon"
				"http://www.core.gen.tr/images/sociallinks/stumbleupon.gif"
				url title)))

;; http://digg.com/submit?url=...&title=...
(defmethod/remote make-digg-link ((self socialshare-component) url title)
  (return (this.make-type1-link "http://digg.com/submit"
				"digg"
				"http://l.yimg.com/us.yimg.com/i/us/pps/digg.png" url title)))

;; http://www.dzone.com/links/add.html?url=...&title=...
(defmethod/remote make-dzone-link ((self socialshare-component) url title)
  (return (this.make-type1-link "http://www.dzone.com/links/add.html"
				"dzone"
				"http://l.yimg.com/us.yimg.com/i/us/pps/dzone.png"
				url title)))

;; http://www.facebook.com/sharer.php?u=...
(defmethod/remote make-facebook-link ((self socialshare-component) url title)
  (return (this.make-type2-link "http://www.facebook.com/sharer.php"
				"facebook"
				"http://www.core.gen.tr/images/sociallinks/facebook.gif"
				url title)))

;; http://myweb2.search.yahoo.com/myresults/bookmarklet?&u=...&t=....
(defmethod/remote make-yahoo-link ((self socialshare-component) url title)
  (return (this.make-type2-link "http://myweb2.search.yahoo.com/myresults/bookmarklet"
				"yahoo"
				"http://www.core.gen.tr/images/sociallinks/yahoo.jpg"
				url title)))

(defmethod/remote make-socialshare-box ((self socialshare-component))
  (let ((div (document.create-element "DIV")))
    (div.append-child (this.make-google-link window.location document.title))
    (div.append-child (this.make-facebook-link window.location document.title))
    (div.append-child (this.make-delicious-link window.location document.title))
    (div.append-child (this.make-reddit-link window.location document.title))
    (div.append-child (this.make-stumbleupon-link window.location document.title))
    (div.append-child (this.make-digg-link window.location document.title))
    (div.append-child (this.make-dzone-link window.location document.title))

    (div.append-child (this.make-yahoo-link window.location document.title))
    (return div)))

(defmethod/remote initialize ((self socialshare-component) obj)
  (aif ($ this.socialshare-id)
       (it.append-child (obj.make-socialshare-box))
       (obj.toast (+ "div id \"" obj.socialshare-id "\" not found."))))


;; ----------------------------------------------------------------------------
;; Feedback
;; ----------------------------------------------------------------------------
(defcomponent feedback-component (toaster-component)
  ((feedback-id :accessor feedback-id :host remote :initform "feedback")
   (greeting-text :accessor greeting-text :host remote :initarg :greeting-text
		  :initform "Please give us feedback to improve our site. Click here to enter.")
   (thank-text :accessor thank-text :host remote
	       :initform "Thank you for giving us feedback."
	       :initarg :thank-text)
   (feedback-from :accessor feedback-from :host local :initform "nospam@core.gen.tr")))

(defmethod/remote get-div ((self feedback-component))
  (return ($ (this.get-feedback-id))))

(defmethod/local feedback-form ((self feedback-component))
  (<:form
   (<:input :type "text" :id "feedback-text" :name "feedback-text")))

(defmethod/local send-feedback ((self feedback-component) feedback url)
  (prog1 'true
    (sendmail (application.server (application self))
	      (feedback-from self)
	      (web-application.admin-email (application self))
	      "Feedback"
	      (with-core-stream/cc (s "")
		(with-html-output s
		  (<:html
		   (<:head (<:title "Feedback"))
		   (<:body
		    (<:p (format nil "We have got a feedback for ~A." (web-application.fqdn (application self))))
		    (<:table
		     (<:tr
		      (<:td "Date:")
		      (<:td (time->string (get-universal-time) :long)))
		     (<:tr
		      (<:td "Url:")
		      (<:td url))
		     (<:tr
		      (<:td "Text:")
		      (<:td feedback))))))
		(return-stream s)))))

(defmethod/remote setup ((self feedback-component))
  (if (= "undefined" (typeof (this.get-div)))
      (this.toast "Feedback div not found, aborting feedback component."))
    
  (setf (slot-value (this.get-div) 'inner-h-t-m-l) "")
  (let ((form (this.feedback-form)))
    (.append-child (this.get-div) form)
    (let ((input ($ "feedback-text")))      
      (setf form.onsubmit (dojo.hitch this
				      (lambda ()
					(this.toast "Sending...")
					(this.send-feedback (escape input.value) (+ "" window.location))
					(this.setup)
					(this.toast (this.get-thank-text))
					(return false))))
      (setf input.value (this.get-greeting-text)
	    input.onfocus (dojo.hitch this
				      (lambda ()					
					(if (= (this.get-greeting-text) input.value)
					    (setf input.value ""))))))))

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