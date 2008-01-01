(in-package :core-server)

;; Component Procotol
(defclass component ()
  ((local-args :accessor component.local-args :initarg :local-args :initform '())
   (remote-args :accessor component.remote-args :initarg :remote-args :initform '())
   (application :accessor application :initarg :application :initform nil)))

(defmethod application ((self component))
  (or (s-v 'application) (application +context+)))

(defgeneric/cc send/component (component)
  (:documentation "Send component to remote."))

(eval-when (:execute :compile-toplevel :load-toplevel)
  (defvar +component-registry+ (make-hash-table :test #'equal)))

(defun methods-of-class (name type)
  (let ((lst))
    (mapcar (lambda (atom)
	      (pushnew atom lst))
	    (reduce #'append
		    (mapcar (lambda (atom)
			      (getf (gethash (class-name atom) +component-registry+) type))
			    (cons (find-class name) (class-superclasses (find-class name))))
		    :initial-value nil))
    lst))

(defun local-methods-of-class (name) (methods-of-class name :local-methods))

(defun remote-methods-of-class (name) (methods-of-class name :remote-methods))

(defun local-slots-of-class (name)
  (getf (gethash name +component-registry+) :local-args))

(defun remote-slots-of-class (name)
  (getf (gethash name +component-registry+) :remote-args))

(defun proxy-method-name (name)
  (intern (string-upcase (format nil "~A-proxy" name)) (find-package :core-server)))

(defun proxy-getter-name (name)
  (intern (string-upcase (format nil "get-~A" name)) (find-package :core-server)))

(defun proxy-setter-name (name)
  (intern (string-upcase (format nil "set-~A" name)) (find-package :core-server)))

(defun client-type-for-slot (name slot)
  (any #'(lambda (atom)
	   (cdr (assoc slot (getf (gethash (class-name atom) +component-registry+) :client-types))))
       (cons (find-class name) (class-superclasses (find-class name)))))

(defun add-local-method-for-class (name method-name)
  (setf (getf (gethash name +component-registry+) :local-methods)
	(cons method-name
	      (remove method-name
		      (getf (gethash name +component-registry+) :local-methods)))))

(defun add-remote-method-for-class (name method-name)
  (setf (getf (gethash name +component-registry+) :remote-methods)
	(cons method-name
	      (remove method-name
		      (getf (gethash name +component-registry+) :remote-methods)))))

(defmacro defmethod/local (name ((self class-name) &rest args) &body body)  
  (add-local-method-for-class class-name name)
  `(progn
     (defgeneric/cc ,name (,class-name ,@args))
     (defgeneric/cc ,(proxy-method-name name) (,class-name))
;;     (export ',(proxy-method-name name))
     (defmethod/cc ,(proxy-method-name name) ((,self ,class-name))
       `(lambda ,',args
	  (return
	    (funcall
	     ,(action/url ,(mapcar (lambda (arg) (list arg (js::symbol-to-js arg))) args)
		(let ,(mapcar (lambda (arg) `(,arg (json-deserialize ,arg))) args)
		  (json/suspend
		   (lambda ()
		     (if (typep *yaclml-stream* 'core-stream)
			 (json! *yaclml-stream* (apply (symbol-function ',name) (list ,self ,@args)))
			 (format *yaclml-stream* "~A"
				 (test-return s (json! s (apply (symbol-function ',name) (list ,self ,@args))))))))))
	     ,',(if args		    
		    (cons 'create (reduce #'append
					  (mapcar (lambda (arg)
						    `(,(make-keyword arg) ,arg))
						  args)
					  :initial-value nil)))))))
     (defmethod/cc ,name ((,self ,class-name) ,@args) ,@body)))

(defmacro defmethod/remote (name ((self class-name) &rest args) &body body)
  (let ((arg-names (arnesi:extract-argument-names args :allow-specializers t)))
    (add-remote-method-for-class class-name name)    
    `(progn       
       (defgeneric/cc ,name (,class-name ,@args))
       (defgeneric/cc ,(proxy-method-name name) (,class-name))
;;       (export ',(proxy-method-name name))
       (defmethod/cc ,(proxy-method-name name) ((,self ,class-name))	      
	 `(lambda ,',arg-names
	    ,',(cons 'progn body)))
       (defmethod/cc ,name ((,self ,class-name) ,@args)
	 (javascript/suspend
	  (lambda ()
	    (<:js
	     `(funcall ,(action/url ((result "result")) (answer (json-deserialize result)))
		       (create :result (serialize (,',name this ,,@args)))))))))))

(defun serialize-to-parenscript (type object)
  (ecase type
    (primitive object)
    (object
     (etypecase object
       (list
	`(create ,@(if (and (listp (car object)) (not (null (caar object))))
		       (reduce (lambda (acc atom)
				 (cons (make-keyword (car atom))
				       (cons (cdr atom) acc)))
			       object :initial-value nil)
		       object)))
       (hash-table
	`(create ,@(let (acc)
                     (maphash (lambda (k v) (push (list (make-keyword k) v) acc)) object)
		     (reduce #'append acc :initial-value nil))))))
    (array `(array ,@object))))

(defmethod/cc send/component ((self component))
  (let ((class-name (class-name (class-of self))))
    (flet ((local-slots ()
	     (reduce (lambda (acc slot)
		       (cons (make-keyword slot) (cons 'null acc)))
		     (reverse (mapcar #'car (local-slots-of-class class-name)))
		     :initial-value nil))
	   (remote-slots ()
	     (reduce (lambda (acc slot)
		       (cons (make-keyword slot)
			     (cons (serialize-to-parenscript
				    (client-type-for-slot class-name slot)
				    (if (slot-boundp self slot)
					(slot-value self slot)))
				   acc)))
		     (reverse (mapcar #'car (remote-slots-of-class class-name)))
		     :initial-value nil))	   
	   (local-methods ()
	     (reduce (lambda (acc method)
		       (cons (make-keyword method)
			     (cons (funcall
				    (symbol-function
				     (proxy-method-name method)) self)
				   acc)))
		     (local-methods-of-class class-name)
		     :initial-value nil))
	   (remote-methods ()
	     (reduce (lambda (acc method)
		       (cons (make-keyword method)
			     (cons (funcall (symbol-function
					     (proxy-method-name method)) self) acc)))
		     (remote-methods-of-class class-name)
		     :initial-value nil)))
      (send/ctor self (remote-slots) (local-methods) (remote-methods)))))

(defmethod/cc send/ctor ((self component) remote-slots local-methods remote-methods)
  (<:js
   `(setf ,(class-name (class-of self))
	  (lambda ()
	    (setf this.prototype (create ;; ,@(local-slots)
				  ,@remote-slots
				  ,@local-methods ,@remote-methods))
	    (return this.prototype)))))

(defmacro defcomponent (name supers slots &rest default-initargs)
  (labels ((clazz-name (name)
	     (intern (string-upcase (format nil "~A" name))))
	   (gen-class (name &optional direction)
	     (case direction
	       ((to view send)
		(clazz-name (format nil "~A-~A" name 'send)))
	       ((from form receive)
		(clazz-name (format nil "~A-~A" name 'receive)))
	       (t
		(clazz-name (format nil "~A" name)))))
	   (filter-slot (slot-def)
	     (when (or (eq 'local (getf (cdr slot-def) :host)) (eq 'both (getf (cdr slot-def) :host)))
	       (unless (getf (cdr slot-def) :initarg)
		 (setf (getf (cdr slot-def) :initarg) (make-keyword (car slot-def)))))
	     (unless (getf (cdr slot-def) :accessor)
	       (setf (getf (cdr slot-def) :accessor) (car slot-def)))
	     (remf (cdr slot-def) :host)
	     (remf (cdr slot-def) :client-type)
	     slot-def)
	   (remote-slot (acc slot-def)
	     (if (or (eq (getf (cdr slot-def) :host) 'remote)
		     (eq (getf (cdr slot-def) :host) 'both))
		 (cons (list (car slot-def) (getf (cdr slot-def) :initform)) acc)
		 acc))
	   (local-slot (acc slot-def)
	     (if (or (eq (getf (cdr slot-def) :host) 'local) (eq (getf (cdr slot-def) :host) 'both))
		 (cons (list (car slot-def) (getf (cdr slot-def) :initform)) acc)
		 acc))
	   (local-args (slotz)
	     (let ((args (append
			  (nreverse (reduce #'local-slot slotz :initial-value nil))
			  (reduce #'(lambda (acc super)
				      (append acc (getf (gethash super +component-registry+)
							:local-args)))
				  supers :initial-value nil)))
		   (super-args
		    (reduce #'append (mapcar #'class-default-initargs supers))))
 	       (setf args		     
		     (reduce
		      #'(lambda (acc arg)
			  (let ((value (cadr (assoc (car arg) super-args :test #'string=))))
			    (if value
				(cons (list (car arg) value) acc)
				(cons arg acc))))
		      args :initial-value nil))
	       (reduce #'(lambda (acc arg)
			   (let ((value (getf (cdar default-initargs) (make-keyword (car arg)))))
			     (if value
				 (cons (list (car arg) value) acc)
				 (cons arg acc))))
		       args :initial-value nil)))
	   (remote-args (slotz)
	     (let ((args (append
			  (nreverse (reduce #'remote-slot slotz :initial-value nil))
			  (reduce #'(lambda (acc super)
				      (append acc (getf (gethash super +component-registry+)
							:remote-args)))
				  supers :initial-value nil)))
		   (super-args
		    (reduce #'append (mapcar #'class-default-initargs supers))))
 	       (setf args		     
		     (reduce
		      #'(lambda (acc arg)
			  (let ((value (cadr (assoc (car arg) super-args
						    :test #'string=))))
			    (if value
				(cons (list (car arg) value) acc)
				(cons arg acc))))
		      args :initial-value nil))
	       (reduce #'(lambda (acc arg)
			   (let ((value (getf (cdar default-initargs)
					      (make-keyword (car arg)))))
			     (if value
				 (cons (list (car arg) value) acc)
				 (cons arg acc))))
		       args :initial-value nil)))
	   (function-key-args (slotz)
	     (reduce #'(lambda (acc slot-def)			 
			 (cons (make-keyword (car slot-def))
			       (cons (car slot-def) acc)))
		     (local-args slotz) :initial-value nil))
	   (filter-default-initargs (lst)
	     (nreverse (reduce #'(lambda (acc item)
				   (if (or (eq item :default-initargs)
					   (eq item :local-args)
					   (eq item :remote-args))
				       acc
				       (cons item acc)))
			       lst :initial-value nil)))
	   (client-type (slot)
	     (cons (car slot) (or (getf (cdr slot) :client-type) 'primitive))))
    (setf (getf (gethash name +component-registry+) :local-args) (local-args slots)
	  (getf (gethash name +component-registry+) :remote-args) (remote-args slots)
	  (getf (gethash name +component-registry+) :client-types) (mapcar #'client-type slots))
    `(eval-when (:compile-toplevel :execute :load-toplevel)
       (prog1 
	   (defclass ,name (,@supers component)
	     ,(mapcar #'filter-slot (copy-tree slots))
	     (:default-initargs ,@(filter-default-initargs (car default-initargs)))
	     ,@(cdr default-initargs))
	 (defun/cc ,(intern (string-upcase name)) (&key ,@(local-args slots))
	   (send/component
	    (apply #'make-instance ',name (list ,@(function-key-args slots)))))
	 ,@(mapcar (lambda (slot)
		     `(progn
			(defmethod/local ,(proxy-getter-name (car slot)) ((self ,name))
			  (slot-value self ',(car slot)))
			(defmethod/local ,(proxy-setter-name (car slot)) ((self ,name) value)
			  (setf (slot-value self ',(car slot)) value))))
		   (local-args slots))
	 ,@(mapcar (lambda (slot)
		     `(progn
			(defmethod/remote ,(proxy-getter-name (car slot)) ((self ,name))
			  (return (slot-value this ',(car slot))))
			(defmethod/remote ,(proxy-setter-name (car slot)) ((self ,name) value)			
			  (setf (slot-value this ',(car slot)) value)
			  (return (slot-value this ',(car slot))))))
		   (remote-args slots))))))

(defun/cc dojo (&optional base-url (debug t))
  (<:js
   `(progn
      (defun load-javascript (url)
	  (let ((request nil))
	    (cond
	      (window.*x-m-l-http-request ;; Gecko
	       (setf request (new (*x-m-l-http-request))))
	      (window.*active-x-object ;; Internettin Explorer
	       (try (setf request (new (*active-x-object "Msxml2.XMLHTTP")))
		    (:catch (error)
		      (setf request (new (*active-x-object "Microsoft.XMLHTTP")))))))
	    (if (= null request)
		(throw (new (*error "Cannot Load Javascript, -core-server 1.0"))))
	    (setf req request)
	    (request.open "GET" url false)
	    (request.send null)
	    (if (= 200 request.status)
		(return (eval (+ "{" request.response-text "}"))))
	    (return nil)))
      (when (= "undefined" (typeof dojo))
	(setf dj-config (create :base-url ,+dojo-path+ :is-debug ,debug))      
	(dolist (src (array "bootstrap.js" "loader.js" "hostenv_browser.js" "loader_xd.js"))	
	  (load-javascript (+ ,+dojo-path+ "_base/_loader/" src)))
	(load-javascript (+ ,+dojo-path+ "_base.js")))
      (setf base-url ,(if (and +context+ base-url)
			  (format nil "/~A/~A"
				  (web-application.fqdn (application +context+))
				  base-url)))
      (defun serialize (value) (return (dojo.to-json value)))
      (defun funcall (url parameters)
	(let (result)
	  (debug "server.funcall " url)
	  (when (dojo.is-object parameters)
	    (doeach (param parameters)
		    (setf (slot-value parameters param)
			  (serialize (slot-value parameters param)))))
	  (dojo.xhr-post
	   (create :url (+ base-url url)
		   :handle-as "text"
		   :sync t
		   :timeout 10
		   :content parameters
		   :load (lambda (json args)
;;			   (debug json)
			   (setf result (eval (+ "{" json "}"))))
		   :error (lambda (err args)
			    (throw (new (*error (+ "Funcall error: " url ", " err)))))))
	  (return result))))))
