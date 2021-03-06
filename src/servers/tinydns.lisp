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

(in-package :tr.gen.core.server)

;;+----------------------------------------------------------------------------
;;| TinyDNS Server
;;+----------------------------------------------------------------------------
;;
;; This file contains implementation of control server of TinyDNS
;;
;; DNS RFC's:
;; http://www.ietf.org/rfc/rfc1035.txt
;; http://www.ietf.org/rfc/rfc1034.txt

;;-----------------------------------------------------------------------------
;; Data File Parsers
;;-----------------------------------------------------------------------------
(defatom domainname-type? ()
  (or (alphanum? c) (= c #.(char-code #\-))))

(defrule nameserver-domainname? (res (acc (make-accumulator)) c)
  (:oom (:oom (:type domainname-type? c) (:collect c acc))	
	(:do (setq res (cons acc res)
		   acc (make-accumulator)))
	#\.)
  (:return (nreverse res)))

(defrule nameserver-hostname? ((acc (make-accumulator)) c)
  (:oom (:type domainname-type? c) (:collect c acc))
  (:return acc))

(defrule tinydns-ns? (domain ip host timestamp)
  #\. (:nameserver-domainname? domain)
  #\: (:ipv4address? ip)
  #\: (:nameserver-hostname? host)
  #\: (:fixnum? timestamp)
  (:return (list 'ns (cons host domain) ip timestamp)))

(defrule tinydns-a? (fqdn ip timestamp)
  #\= (:nameserver-domainname? fqdn)
  #\: (:ipv4address? ip)
  #\: (:fixnum? timestamp)
  (:return (list 'a fqdn ip timestamp)))

(defrule tinydns-alias? (fqdn ip timestamp)
  #\+ (:nameserver-domainname? fqdn)
  #\: (:ipv4address? ip)
  #\: (:fixnum? timestamp)
  (:return (list 'alias fqdn ip timestamp)))

(defrule tinydns-mx? (domain ip host timestamp)
  #\@ (:nameserver-domainname? domain)
  #\: (:ipv4address? ip)
  #\: (:nameserver-hostname? host)
  #\: #\: (:fixnum? timestamp)
  (:return (list 'mx (cons host domain) ip timestamp)))

(defrule tinydns-comment? ((acc (make-accumulator)) c)
  #\# (:zom (:type (or visible-char? space?) c) (:collect c acc))
  (:return (list 'comment acc)))

(defrule tinydns-txt? ((acc (make-accumulator)) c)
  #\' (:zom (:type (or visible-char? space?) c) (:collect c acc))
  (:return (list 'txt acc)))

(defrule tinydns-data? (acc (data '()))
  (:oom (:or (:tinydns-ns? acc)
	     (:tinydns-a? acc)
	     (:tinydns-alias? acc)
	     (:tinydns-mx? acc)
	     (:tinydns-comment? acc)
	     (:tinydns-txt? acc))
	(:do (push acc data))
	(:lwsp?))
  (:return (nreverse data)))

;;-----------------------------------------------------------------------------
;; Svstat Command
;;-----------------------------------------------------------------------------
(defcommand svstat (shell)
  ((svstat-pathname :host local :initform (whereis "svstat")))
  (:default-initargs :cmd +sudo+ :verbose nil))

(defrule svstat? ()
  (:oom (:not #\:) (:type octet?)) (:lwsp?) (:seq "up") (:return t))

(defmethod render-arguments ((self svstat))
  (list (s-v 'svstat-pathname)))
  
(defmethod run ((self svstat))
  (call-next-method)
  (svstat? (make-core-stream (command.output-stream self))))

;;-----------------------------------------------------------------------------
;; Server Implementation
;;-----------------------------------------------------------------------------
(defclass+ tinydns-server (server)
  ((svc-pathname :accessor tinydns-server.svc-pathname
		 :initarg :svc-pathame :initform (whereis "svc"))
   (svstat-pathname :accessor tinydns-server.svstat-pathname
		    :initarg :svscan-pathname :initform (whereis "svstat"))
   (root-pathname :accessor tinydns-server.root-pathname :initarg :root-pathname
		  :initform (make-pathname :directory '(:absolute "service" "tinydns")))
   (compiler-pathname :accessor tinydns-server.compiler-pathname :initarg :compiler-pathname
		      :initform (whereis "tinydns-data"))
   (domains :accessor tinydns-server.domains :initform nil)
   (%timestamp :initform (get-universal-time)))
  (:default-initargs :name "TinyDNS Server - Mix this class with your
server to manage TinyDNS server. See src/servers/tinydns.lisp for
implementation"))

(defmethod tinydns-server.data-pathname ((self tinydns-server))
  (merge-pathnames (make-pathname :directory '(:relative "root") :name "data")
		   (s-v 'root-pathname)))

(defun walk-tinydns-data-1 (data)
  (sort (reduce (lambda (acc atom)
		  (if (listp (cadr atom))
		      (cons (append (list (reverse (cadr atom)) (car atom)) (cddr atom)) acc)))
		data :initial-value nil)
	#'string< :key (lambda (a) (apply #'concatenate 'string (car a)))))

(defmethod tinydns-server.data ((self tinydns-server))
  (with-server-lock (self)
    (walk-tinydns-data-1
     (tinydns-data? (make-core-file-input-stream
		     (tinydns-server.data-pathname self))))))

(defmethod tinydns-server.domains ((self tinydns-server))
;; TODO: Fix cacheing, it doesnt work.
;; (if (or (null (s-v '%timestamp))
;; 	  (> (sb-posix:stat-mtime (sb-posix::stat (tinydns-server.data-pathname self)))
;; 	     (s-v '%timestamp)))
;;       (setf (s-v '%timestamp) (sb-posix:stat-mtime
;; 			       (sb-posix::stat (tinydns-server.data-pathname self)))
;; 	    (s-v 'domains) (tinydns-server.data self))
;;       (s-v 'domains))
  (tinydns-server.data self))

;;-----------------------------------------------------------------------------
;; Record Finders
;;-----------------------------------------------------------------------------
(defmethod find-record ((self tinydns-server) fqdn)
  (let ((fqdn (nreverse (nameserver-domainname? (make-core-stream fqdn)))))
    (reverse
     (reduce (lambda (acc atom)
	       (if (reduce (lambda (acc1 atom1)
			     (if (and acc1 (equal (car atom1) (cdr atom1)))
				 t
				 nil))
			   (mapcar #'cons (car atom) fqdn)
			   :initial-value t)		   
		   (cons (cons (cadr atom)
			       (cons (car atom) (cddr atom))) acc)
		   acc))
	     (tinydns-server.domains self) :initial-value nil))))

(defmacro defrecord-finder (type)
  `(defmethod ,(intern (format nil "FIND-~A" type)) ((self tinydns-server) fqdn)
     (reduce (lambda (acc atom)
	       (if (eq (car atom) ',type)
		   (cons (cdr atom) acc)
		   acc))
	     (find-record self fqdn) :initial-value nil)))

(defrecord-finder a)
(defrecord-finder alias)
(defrecord-finder ns)
(defrecord-finder mx)

;;-----------------------------------------------------------------------------
;; TinyDNS Management Commands
;;-----------------------------------------------------------------------------
(defcommand tinydns-add-mixin ()
  ((root :initform #P"/service/tinydns/root/")))

(defmethod render-arguments ((self tinydns-add-mixin))
  (list (slot-value self 'add-pathname)))

(defmethod run ((self tinydns-add-mixin))
  (with-current-directory (slot-value self 'root)
    (call-next-method)))

(defcommand tinydns.add-mx (tinydns-add-mixin shell)
  ((add-pathname :host local :initform #P"/service/tinydns/root/add-mx"))
  (:default-initargs :cmd +sudo+ :verbose nil))

(defcommand tinydns.add-host (tinydns-add-mixin shell)
  ((add-pathname :host local :initform #P"/service/tinydns/root/add-host"))
  (:default-initargs :cmd +sudo+ :verbose nil))

(defcommand tinydns.add-alias (tinydns-add-mixin shell)
  ((add-pathname :host local :initform #P"/service/tinydns/root/add-alias"))
  (:default-initargs :cmd +sudo+ :verbose nil))

(defcommand tinydns.add-ns (tinydns-add-mixin shell)
  ((add-pathname :host local :initform #P"/service/tinydns/root/add-ns"))
  (:default-initargs :cmd +sudo+ :verbose t))

;;-----------------------------------------------------------------------------
;; Implementation of Name-server Protocol
;;-----------------------------------------------------------------------------
(defmethod add-mx ((self tinydns-server) fqdn &optional ip)
  (with-server-lock (self)
    (tinydns.add-mx :add-pathname (merge-pathnames #P"root/add-mx"
						   (tinydns-server.root-pathname self))
		    :args (list fqdn ip))))

(defmethod add-host ((self tinydns-server) fqdn ip)
  (with-server-lock (self)
    (tinydns.add-host :add-pathname (merge-pathnames #P"root/add-host"
						     (tinydns-server.root-pathname self))
		      :args (list fqdn ip))))

(defmethod add-alias ((self tinydns-server) fqdn ip)
  (with-server-lock (self)
    (tinydns.add-alias :add-pathname (merge-pathnames #P"root/add-alias"
						      (tinydns-server.root-pathname self))
		       :args (list fqdn ip))))

(defmethod add-ns ((self tinydns-server) fqdn ip)
  (with-server-lock (self)
    (tinydns.add-ns :add-pathname (merge-pathnames #P"root/add-ns"
						      (tinydns-server.root-pathname self))
		    :args (list fqdn ip))))

;;-----------------------------------------------------------------------------
;; Implementation of Server Protocol
;;-----------------------------------------------------------------------------
(defmethod start ((self tinydns-server))
  (if (not (probe-file (tinydns-server.data-pathname self)))
      (error "Cannot access tinydns data file ~A" (tinydns-server.data-pathname self)))  
  (shell :cmd +sudo+ :args (list (s-v 'svc-pathname) "-u" (s-v 'root-pathname)))
  t)

(defmethod stop ((self tinydns-server))
  (shell :cmd +sudo+ :args (list (s-v 'svc-pathname) "-d" (s-v 'root-pathname)))
  (setf (s-v '%timestamp) nil (s-v 'domains) nil)
  t)

(defmethod status ((self tinydns-server))
  (svstat :svstat-pathname (s-v 'svstat-pathname) :args (list (s-v 'root-pathname))))

(deftrace tinydns-parsers
  '(fixnum? nameserver-domainname? ipv4address? nameserver-hostname? tinydns-ns?
    tinydns-a? tinydns-alias? tinydns-mx? tinydns-data?))
