;; -------------------------------------------------------------------------
;; [Core-serveR] Hello World Web Example
;; -------------------------------------------------------------------------
;; Load the file with C-c C-l and visit, 
;; http://localhost:8080/hello/

;; -------------------------------------------------------------------------
;; Define a new namespace
;; -------------------------------------------------------------------------
(defpackage :hello
  (:use :cl :core-server :arnesi))

;; -------------------------------------------------------------------------
;; Switch to new namespace
;; -------------------------------------------------------------------------
(in-package :hello)

;; -------------------------------------------------------------------------
;; Hello Application Definition
;; -------------------------------------------------------------------------
(defapplication hello-application (http-application)
  ()
  (:default-initargs :fqdn "hello" :admin-email "aycan@core.gen.tr"))

;; -------------------------------------------------------------------------
;; Define 'page' function which gets body as a parameter
;; -------------------------------------------------------------------------
(defun/cc page (body)
  (<:html
   (<:head (<:title "Core Server - Hello Example"))
   (<:body body)))

;; -------------------------------------------------------------------------
;; Create a handler via defhandler
;; -------------------------------------------------------------------------
(defhandler "index" ((self hello-application))
  (page (<:h1 "Hello, World!")))

;; -------------------------------------------------------------------------
;; Create an application instance
;; -------------------------------------------------------------------------
(defparameter *hello* (make-instance 'hello-application))

;; -------------------------------------------------------------------------
;; Register application to [core-serveR]
;; -------------------------------------------------------------------------
(register *server* *hello*)

;; -------------------------------------------------------------------------
;; This example is less then 15 LoC.
;; -------------------------------------------------------------------------
