;;;; cl-yesql.lisp

(defpackage #:cl-yesql
  (:use #:cl #:alexandria #:serapeum
    #:cl-yesql/queryfile
    #:cl-yesql/statement)
  (:nicknames #:yesql)
  (:import-from #:overlord)
  (:import-from #:esrap
    #:parse)
  (:export
   #:parse-query
   #:parse-queries

   #:query
   #:query-name #:query-id
   #:annotation #:query-annotation
   #:query-docstring
   #:query-statement
   #:query-vars #:query-args

   #:yesql-static-exports

   #:yesql

   #:yesql-reader #:read-module))

(defpackage #:cl-yesql-user
  (:use))

(in-package #:cl-yesql)

;;; "cl-yesql" goes here. Hacks and glory await!

(defclass query ()
  ((name :initarg :name :type string :reader query-name)
   (annotation :initarg :annotation :type annotation :reader query-annotation)
   (docstring :type string :reader query-docstring
              :initarg :docstring)
   (statement :type (or string list) :initarg :statement
              :reader query-statement))
  (:default-initargs
   :statement (required-argument 'statement)
   :name (required-argument 'name)
   :annotation :rows))

(defmethod query-vars ((self query))
  (statement-vars (query-statement self)))

(defconst positional-args
  (loop for i from 0 to 50
        collect (intern (fmt "?~a" i) :cl-yesql)))

(defun positional-arg? (arg)
  (memq arg positional-args))

(defmethod statement-vars ((statement list))
  (mvlet* ((symbols (filter #'symbolp statement))
           (positional keywords (partition #'positional-arg? symbols)))
    (assert (equal positional (nub positional)))
    (append positional (nub keywords))))

(defconst no-docs "No docs.")

(defun make-query (&rest args &key docstring statement &allow-other-keys)
  (apply #'make 'query
         :docstring (or docstring no-docs)
         :statement (etypecase statement
                      (list statement)
                      (string (parse-statement statement)))
         (remove-from-plist args :docstring :statement)))

(defmethod print-object ((self query) stream)
  (print-unreadable-object (self stream :type t)
    (with-slots (name annotation statement docstring) self
      (format stream "~s ~s ~s~@[ ~s~]"
              name
              annotation
              statement
              docstring))))

(defun query-id (q)
  (lispify-sql-id (query-name q)))

(defmethod statement-vars ((s string))
  (statement-vars (parse 'statement s)))

(defun parse-statement (s)
  (let* ((statement (parse 'statement s))
         (positional positional-args))
    (loop for part in statement
          if (eql part placeholder)
            collect (pop positional)
          else collect part)))

(defun print-sql (x s)
  (if (listp x)
      (loop for (each . more?) on x
            do (print-sql each s)
               (when more?
                 (write-string ", " s)))
      (prin1 x s)))

(defmethod parse-query ((s string))
  (apply #'make-query
         (parse 'query (ensure-trailing-newline s))))

(defmethod parse-query ((p pathname))
  (parse-query (read-file-into-string p)))

(defun parse-queries (s)
  (let ((*package* (find-package :cl-yesql-user)))
    (etypecase s
      (string
       (mapply #'make-query
               (parse 'queries (ensure-trailing-newline s))))
      (pathname
       (parse-queries (read-file-into-string s)))
      (stream
       (assert (input-stream-p s))
       (parse-queries (read-stream-content-into-string s))))))

(defun yesql-reader (path stream)
  (declare (ignore path))
  (let ((defquery (overlord:reintern 'defquery)))
    (loop for query in (parse-queries stream)
          collect `(,defquery ,(query-id query) ,(query-args query)
                     ,(query-docstring query)
                     ,query))))

(defun read-module (source stream)
  (overlord:with-meta-language (source stream)
    (yesql-reader source stream)))

(defun ensure-trailing-newline (s)
  (let ((nl #.(string #\Newline)))
    (if (string$= nl s)
        s
        (concat s nl))))

(defun query-args (q)
  (mvlet* ((positional keyword (partition #'positional-arg? (query-vars q)))
           ;; Keyword arguments are not optional.
           (keyword
            (mapcar (op `(,_1 (required-argument ',_1))) keyword))
           (args (append positional (cons '&key keyword))))
    (assert (equal args (nub args)))
    args))

(defun query-affix (q)
  (let ((name (query-name q)))
    (cond ((string$= "!" name) :execute)
          ((string$= "<!" name) :last-id)
          ((string^= "count-" name) :single)
          ((or (string$= "-p" name)
               (string$= "?" name))
           :single)
          (t nil))))

(defmethod query-annotation :around ((self query))
  (or (query-affix self) (call-next-method)))

(defun yesql-static-exports (file)
  #+ () (mapcar #'query-id (parse-queries file))
  ;; Should this just be a regex?
  (with-input-from-file (in file)
    (loop for line = (read-line in nil nil)
          while line
          for name = (ignore-errors
                      (car
                       (parse 'name (concat line #.(string #\Newline)))))
          when name
            collect (lispify-sql-id name :package :keyword))))
