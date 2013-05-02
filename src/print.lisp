;;; print.lisp --- 

;; Copyright (C) 2012, 2013 David Vazquez
;; Copyright (C) 2012 Raimon Grau

;; JSCL is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.
;;
;; JSCL is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with JSCL.  If not, see <http://www.gnu.org/licenses/>.

;;; Printer

(defun special-symbol-name (s &key uppercase)
  (let ((dots-only t))
    (dotimes (i (length s))
      (let ((ch (char s i)))
        (setf dots-only (and dots-only (char= ch #\.)))
        (when (or (terminalp ch)
                  (char= ch #\:)
                  (and uppercase (not (char= ch (char (string-upcase (string ch)) 0))))
                  (char= ch #\\)
                  (char= ch #\|))
          (return-from special-symbol-name t))))
    dots-only))

(defun potential-number (s)
  (let ((i 0)
        (n (length s))
        (ch nil))
    (flet ((next ()
             (setf ch (and (< i n) (char s (1- (incf i)))))))
      (next)
      (cond
       ((null ch) (return-from potential-number))
       ((digit-char-p ch))
       ((char= ch #\.))
       ((char= ch #\+) (next))
       ((char= ch #\-) (next))
       (t (return-from potential-number)))
      (when ch
        (while (and ch (digit-char-p ch)) (next))
        (when (null ch)
          (return-from potential-number t)))
      (when (char= ch #\.)
        (next)
        (when ch
          (while (and ch (digit-char-p ch)) (next))))
      (when (or (char= ch #\E) (char= ch #\e)
                (char= ch #\D) (char= ch #\d)
                (char= ch #\F) (char= ch #\f)
                (char= ch #\L) (char= ch #\l))
        (next)
        (cond
         ((null ch) (return-from potential-number))
         ((digit-char-p ch))
         ((char= ch #\+) (next))
         ((char= ch #\-) (next))
         (t (return-from potential-number)))
        (unless (and ch (digit-char-p ch))
          (return-from potential-number))
        (while (and ch (digit-char-p ch)) (next)))
      (null ch))))

(defun special-escape (s package)
  (if (or (potential-number s)
          (special-symbol-name s :uppercase (not (eq package (find-package "JS")))))
      (let ((result "|"))
        (dotimes (i (length s))
          (let ((ch (char s i)))
            (when (or (char= ch #\|)
                      (char= ch #\\))
              (setf result (concat result "\\")))
            (setf result (concat result (string ch)))))
        (concat result "|"))
      s))

(defun prin1-to-string (form)
  (cond
    ((null form) "NIL")
    ((symbolp form)
     (multiple-value-bind (found-symbol status)
         (find-symbol (symbol-name form))
       (if (eq found-symbol form)
           (special-escape (symbol-name form) *package*)
           (let ((package (symbol-package form))
                 (name (symbol-name form)))
             (concat (cond
                      ((null package) "#")
                      ((eq package (find-package "KEYWORD")) "")
                      (t (package-name package)))
                     ":"
                     (if (eq (cadr (multiple-value-list (find-symbol name package)))
                             :internal)
                         ":"
                         "")
                     (special-escape name package))))))
    ((integerp form) (integer-to-string form))
    ((floatp form) (float-to-string form))
    ((characterp form)
     (concat "#\\"
             (case form
               (#\newline "newline")
               (#\space "space")
               (otherwise (string form)))))
    ((stringp form) (concat "\"" (escape-string form) "\""))
    ((functionp form)
     (let ((name (oget form "fname")))
       (if name
           (concat "#<FUNCTION " name ">")
           (concat "#<FUNCTION>"))))
    ((listp form)
     (concat "("
             (join-trailing (mapcar #'prin1-to-string (butlast form)) " ")
             (let ((last (last form)))
               (if (null (cdr last))
                   (prin1-to-string (car last))
                   (concat (prin1-to-string (car last)) " . " (prin1-to-string (cdr last)))))
             ")"))
    ((arrayp form)
     (concat "#" (if (zerop (length form))
                     "()"
                     (prin1-to-string (vector-to-list form)))))
    ((packagep form)
     (concat "#<PACKAGE " (package-name form) ">"))
    (t
     (concat "#<javascript object>"))))

(defun write-line (x)
  (write-string x)
  (write-string *newline*)
  x)

(defun warn (string)
  (write-string "WARNING: ")
  (write-line string))

(defun print (x)
  (write-line (prin1-to-string x))
  x)
