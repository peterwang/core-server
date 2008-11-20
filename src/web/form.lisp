(in-package :core-server)

;; +----------------------------------------------------------------------------
;; | Form/Input Components
;; +----------------------------------------------------------------------------

;; +----------------------------------------------------------------------------
;; | Validting HTML Input
;; +----------------------------------------------------------------------------
(defcomponent <core:validating-input (<:input)
  ((validation-span-id :host remote :initform nil)
   (valid-class :host remote :initform "valid")
   (invalid-class :host remote :initform "invalid")
   (valid :host remote :initform nil)))

(defmethod/remote set-validation-message ((self <core:validating-input) message)
  (setf (slot-value (document.get-element-by-id self.validation-span-id)
		    'inner-h-t-m-l)
	message))

(defmethod/remote enable-or-disable-form ((self <core:validating-input))
  (setf valid (reduce (lambda (acc input)
			(if (typep input.valid 'undefined)
			    acc
			    (and acc input.valid)))
		      (self.form.get-elements-by-tag-name "INPUT")
		      t))

  (mapcar (lambda (input)
	    (when (and input.type (eq "SUBMIT" (input.type.to-upper-case)))
	      (if valid
		  (setf input.disabled false)
		  (setf input.disabled true)))
	    nil)
	  (self.form.get-elements-by-tag-name "INPUT")))

(defmethod/remote validate ((self <core:validating-input))
  t)

(defmethod/remote run-validator ((self <core:validating-input))
  (let ((result (validate self)))
    (cond
      ((typep result 'string)
       (setf self.valid nil)
       (set-validation-message self result)
       (add-class self self.invalid-class)
       (remove-class self self.valid-class)
       (enable-or-disable-form self))
      (t
       (setf self.valid t)
       (set-validation-message self "")
       (add-class self self.valid-class)
       (remove-class self self.invalid-class)
       (enable-or-disable-form self)))))

(defmethod/remote onchange ((self <core:validating-input) e)
  (run-validator self) t)

(defmethod/remote onkeydown ((self <core:validating-input) e)
  (run-validator self) t)

(defmethod/remote onkeyup ((self <core:validating-input) e)
  (run-validator self) t)

;; +----------------------------------------------------------------------------
;; | Default Value HTML Input
;; +----------------------------------------------------------------------------
(defcomponent <core:default-value-input (<:input)
  ((default-value :host remote :initform nil)))

(defmethod/remote adjust-default-value ((self <core:default-value-input))
  (cond
    ((equal self.default-value self.value)
     (setf self.value ""
;; 	   self.style.opacity 1.0
	   ))
    ((equal "" self.value)
     (setf self.value self.default-value
	   ;; self.style.opacity 0.5
	   ))))

(defmethod/remote onfocus ((self <core:default-value-input) e)
  (adjust-default-value self))

(defmethod/remote onblur ((self <core:default-value-input) e)
  (adjust-default-value self))

(defmethod/remote init ((self <core:default-value-input))
  (setf self.value self.default-value))

;; +----------------------------------------------------------------------------
;; | Email HTML Component
;; +----------------------------------------------------------------------------
(defcomponent <core:email-input (<core:default-value-input <core:validating-input)
  ())

(defmethod/remote validate-email ((self <core:email-input))
  (let ((expression (regex "/^[a-zA-Z0-9._-]+@([a-zA-Z0-9.-]+\.)+[a-zA-Z0-9.-]{2,4}$/")))
    (if (expression.test self.value)
	t
	"Your email is invalid")))

(defmethod/remote validate ((self <core:email-input))
  (validate-email self))

;; +----------------------------------------------------------------------------
;; | Password HTML Component
;; +----------------------------------------------------------------------------
(defcomponent <core:password-input (<core:default-value-input <core:validating-input)
  ((min-length :initform 6 :host remote)))

(defmethod/remote validate-password ((self <core:password-input))
  (cond
    ((or (null self.value) (< self.value.length self.min-length))
     "Your password is too short.")
    (t
     t)))

(defmethod/remote validate ((component <core:password-input))
  (validate-password component))
