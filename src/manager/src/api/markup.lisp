(in-package :manager)

;; -------------------------------------------------------------------------
;; Data Definitions
;; -------------------------------------------------------------------------
;; +xml-namespaces-table+
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defclass <core-server:markup+ (xml+)
    ()
    (:default-initargs :namespace "coreServer"
		       :schema "http://labs.core.gen.tr/2012/API/")))

(defclass+ <core-server:markup (xml)
  ()
  (:metaclass <core-server:markup+))

;; +------------------------------------------------------------------------
;; | Core-Server Markup Definition: defcore-server-tag
;; +------------------------------------------------------------------------
(defmacro defapi-tag (name &rest attributes)  
  `(progn
     (defclass+ ,name (<core-server:markup)
       (,@(mapcar (lambda (attr) (list attr :print nil :host 'remote))
		  attributes))
       (:metaclass <core-server:markup+)
       (:tag ,@(string-downcase (symbol-name name)))
       (:attributes ,@attributes))
     (find-class+ ',name)))

(defapi-tag <core-server:response)
(defapi-tag <core-server:authentication status)
(defapi-tag <core-server:user name id last-update)
(defapi-tag <core-server:error code)