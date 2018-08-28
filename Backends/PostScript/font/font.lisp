;;; -*- Mode: Lisp; Package: CLIM-POSTSCRIPT -*-

;;;  (c) copyright 2002 by
;;;           Alexey Dejneka (adejneka@comail.ru)

;;; This library is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU Library General Public
;;; License as published by the Free Software Foundation; either
;;; version 2 of the License, or (at your option) any later version.
;;;
;;; This library is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; Library General Public License for more details.
;;;
;;; You should have received a copy of the GNU Library General Public
;;; License along with this library; if not, write to the
;;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;;; Boston, MA  02111-1307  USA.

;;; TODO:
;;;
;;; - Kerning, ligatures.
;;; - device fonts

(in-package :clim-postscript-font)

(defclass postscript-font-medium (basic-medium)
  ((device-fonts :initform nil
		 :accessor device-fonts)))

(defclass postscript-font-port (basic-port) ())

(defclass font-info ()
  ((name :type string :initarg :name :reader font-info-name)
   (ascent :initarg :ascent :reader font-info-ascent)
   (descent :initarg :descent :reader font-info-descent)
   (italic-angle :initarg :italic-angle :reader font-info-italic-angle)
   (char-names :initform (make-array 256 :initial-element nil)
               :reader font-info-char-names)
   (char-infos :initform (make-hash-table :test 'equal)
               :reader font-info-char-infos)))

(defclass char-metrics ()
  ((width :initarg :width :reader char-width)
   (ascent :initarg :ascent :reader char-ascent)
   (descent :initarg :descent :reader char-descent)
   (xmin :initarg :xmin :reader char-xmin)
   (xmax :initarg :xmax :reader char-xmax)))

(defvar *font-metrics* (make-hash-table :test 'equal))

(defstruct postscript-device-font-name
  (font-file (error "missing argument"))
  (metrics-file (error "missing argument"))
  (size (error "missing argument")))

(defun get-font-info (font-name)
  (gethash font-name *font-metrics*))

(defun font-name-size (font-name)
  (etypecase font-name
    (postscript-device-font-name (postscript-device-font-name-size font-name))
    (cons (cdr font-name))))

(defun font-name-metrics-key (font-name)
  (etypecase font-name
    (postscript-device-font-name font-name)
    (cons (car font-name))))

(defun define-font-metrics (name ascent descent angle char-infos &optional (font-name nil))
  (let ((font-info (make-instance 'font-info
                                  :name name
                                  :ascent ascent
                                  :descent descent
                                  :italic-angle angle)))
    (setf (gethash (or font-name name) *font-metrics*) font-info)
    (loop for (code name width ascent descent xmin xmax) in char-infos
         do (when (>= code 0)
              (setf (aref (font-info-char-names font-info) code)
                    name))
         (setf (gethash name (font-info-char-infos font-info))
               (make-instance 'char-metrics
                              :width width
                              :ascent ascent
                              :descent descent
			      :xmin xmin
			      :xmax xmax)))))

;;;
(defun text-size-in-font (font-name size string start end)
  (declare (string string))
  (unless end (setq end (length string)))
  (let* ((font-info (or (gethash font-name *font-metrics*)
                        (error "Unknown font ~S." font-name)))
         (char-metrics (font-info-char-infos font-info))
         (scale (/ size 1000))
         (width 0) (upper-width 0)
         (upper-height 0)
         (descent 0) (ascent 0) (upper-baseline 0))
    (loop for i from start below end
       for char = (aref string i)
       do (cond ((char= char #\Newline)
                 (maxf upper-width width) (setf width 0)
                 (incf upper-baseline (+ ascent descent))
                 (maxf upper-height (+ ascent descent))
                 (setf descent 0) (setf ascent 0))
                (t (let ((metrics (gethash (aref *iso-latin-1-symbolic-names* (char-code char))
                                           char-metrics)))
                     (incf width (char-width metrics))
                     (maxf ascent (char-ascent metrics))
                     (maxf descent (char-descent metrics))))))
    (values (* scale (max width upper-width))
            (* scale (+ ascent descent upper-height))
            (* scale width)
            (* scale upper-height)
            (* scale (+ upper-height ascent))))) ;?

;;;
(defconstant +postscript-fonts+
  '(:fix ((:roman . "Courier")
          (:bold . "Courier-Bold")
          (:italic . "Courier-Oblique")
          ((:bold :italic) . "Courier-BoldOblique"))
    :serif ((:roman . "Times-Roman")
            (:bold . "Times-Bold")
            (:italic . "Times-Italic")
            ((:bold :italic) . "Times-BoldItalic"))
    :sans-serif ((:roman . "Helvetica")
                 (:bold . "Helvetica-Bold")
                 (:italic . "Helvetica-Oblique")
                 ((:bold :italic) . "Helvetica-BoldOblique"))))

(defconstant +postscript-font-sizes+
  '(:normal 14
    :tiny 8
    :very-small 10
    :small 12
    :large 18
    :very-large 20
    :huge 24))

(defmethod text-style-mapping ((port postscript-font-port) text-style
                               &optional character-set)
  (declare (ignore character-set))
  (or (gethash text-style (port-text-style-mappings port))
      (multiple-value-bind (family face size) (text-style-components text-style)
        (let* ((family-fonts (or (getf +postscript-fonts+ family)
                                 (getf +postscript-fonts+ :fix)))
               (font-name (cdr (or (assoc face family-fonts :test #'equal)
                                   (assoc :roman family-fonts))))
               (size-number (if (numberp size)
                                (round size)
                                (or (getf +postscript-font-sizes+ size)
                                    (getf +postscript-font-sizes+ :normal)))))
          (cons font-name size-number)))))

(defmethod (setf text-style-mapping)
    (mapping (port postscript-font-port) (text-style text-style)
     &optional character-set)
  (declare (ignore character-set))
  (cond 
    ((and (consp mapping)
	  (stringp (car mapping))
	  (numberp (cdr mapping)))
     (when (not (gethash (car mapping) *font-metrics*))
       (cerror "Ignore." "Mapping text style ~S to an unknown font ~S."
	       text-style (car mapping)))
     (setf (gethash text-style (port-text-style-mappings port))
	   mapping))
    (t
     (when (not (gethash mapping *font-metrics*))
       (cerror "Ignore." "Mapping text style ~S to an unknown font ~S."
	       text-style mapping))
     (setf (gethash text-style (port-text-style-mappings port))
	   mapping))))

;; The following four functions should be rewritten: AFM contains all
;; needed information
(defmethod text-style-ascent (text-style (medium postscript-font-medium))
  (let* ((font-name (text-style-mapping (port medium)
					(merge-text-styles text-style
							   (medium-merged-text-style medium))))
	 (font-info (or (gethash (font-name-metrics-key font-name)
                                 *font-metrics*)
                        (error "Unknown font ~S." font-name)))
         (size (font-name-size font-name)))
    (* (/ size 1000) (font-info-ascent font-info))))
	 

(defmethod text-style-descent (text-style (medium postscript-font-medium))
  (let* ((font-name (text-style-mapping (port medium)
					(merge-text-styles text-style
							   (medium-merged-text-style medium))))
	 (font-info (or (gethash (font-name-metrics-key font-name)
                                 *font-metrics*)
                        (error "Unknown font ~S." font-name)))
         (size (font-name-size font-name)))
    (* (/ size 1000) (font-info-descent font-info))))

(defmethod text-style-height (text-style (medium postscript-font-medium))
  (multiple-value-bind (width height final-x final-y baseline)
      (text-size medium "Iq" :text-style text-style)
    (declare (ignore width final-x final-y baseline))
    height))

(defmethod text-style-width (text-style (medium postscript-font-medium))
  (multiple-value-bind (width height final-x final-y baseline)
      (text-size medium "M" :text-style text-style)
    (declare (ignore height final-x final-y baseline))
    width))

(defmethod climi::text-bounding-rectangle*
    ((medium postscript-font-medium) string
     &key text-style (start 0) end)
  (when (characterp string)
    (setf string (make-string 1 :initial-element string)))
  (unless end (setf end (length string)))
  (unless text-style (setf text-style (medium-text-style medium)))
  (let* ((font-name
          (text-style-mapping (port medium)
                              (merge-text-styles 
                               text-style
                               (medium-merged-text-style medium))))
         (metrics-key (font-name-metrics-key font-name))
         (size (font-name-size font-name)))
    (let ((scale (/ size 1000)))
      (cond ((= start end)
             (values 0 0 0 0))
            (t
             (let ((position-newline (position #\newline string :start start)))
               (cond ((not (null position-newline))
                      (multiple-value-bind (width ascent descent left right
                                                  font-ascent font-descent
                                                  direction first-not-done)
                          (psfont-text-extents metrics-key string
                                               :start start :end position-newline)
			(declare (ignore width font-ascent font-descent direction first-not-done))
                        (multiple-value-bind (minx miny maxx maxy)
                            (climi::text-bounding-rectangle*
                             medium string :text-style text-style
                             :start (1+ position-newline) :end end)
			  (declare (ignore miny))
                          (values (* scale (min minx left))
                                  (* scale (- ascent))
                                  (* scale (max maxx right))
                                  (* scale (+ descent maxy))))))
                     (t
                      (multiple-value-bind (width ascent descent left right
                                                  font-ascent font-descent
                                                  direction first-not-done)
                          (psfont-text-extents metrics-key string
                                               :start start :end end)
			(declare (ignore width font-ascent font-descent direction first-not-done))
                        (values (* scale left)
                                (* scale (- ascent))
                                (* scale right)
                                (* scale descent)))))))))))

(defun psfont-text-extents (metrics-key string &key (start 0) (end (length string)))
  (unless (< start (length string))
    (psfont-text-extents metrics-key ""))
  (let* ((font-info (or (gethash metrics-key *font-metrics*)
			(error "Unknown font ~S." metrics-key)))
	 (char-metrics (font-info-char-infos font-info))
	 (width (loop for i from start below end
		   sum (char-width (gethash (aref *iso-latin-1-symbolic-names* (char-code (char string i)))
					    char-metrics))))
         (ascent (loop for i from start below end
                       maximize (char-ascent (gethash (aref *iso-latin-1-symbolic-names* (char-code (char string i)))
                                                      char-metrics))))
         (descent (loop for i from start below end
                       maximize (char-descent (gethash (aref *iso-latin-1-symbolic-names* (char-code (char string i)))
                                                       char-metrics)))))
    (values
     width
     ascent
     descent
     (char-xmin (gethash (aref *iso-latin-1-symbolic-names* (char-code (char string start)))
			 char-metrics))
     (- width (- (char-width (gethash (aref *iso-latin-1-symbolic-names* (char-code (char string (1- end))))
				      char-metrics))
		 (char-xmax (gethash (aref *iso-latin-1-symbolic-names* (char-code (char string (1- end))))
				     char-metrics))))
     (font-info-ascent font-info)
     (font-info-descent font-info)
     0 end)))
     



(defmethod text-size ((medium postscript-font-medium) string
                      &key text-style (start 0) end)
  (when (characterp string) (setq string (string string)))
  (unless end (setq end (length string)))
  (let* ((font-name (text-style-mapping (port medium)
                                        (merge-text-styles text-style
                                                           (medium-merged-text-style medium))))
         (size (font-name-size font-name))
         (metrics-key (font-name-metrics-key font-name)))
    (text-size-in-font metrics-key size
                       string start (or end (length string)))))

(defmethod invoke-with-text-style :around
    ((medium postscript-font-medium)
     continuation
     (text-style clim-internals::device-font-text-style))
  (unless (member text-style (device-fonts medium))
    (push text-style (device-fonts medium)))
  (call-next-method))

(defmethod make-device-font-text-style ((port postscript-font-port) font-name)
  (check-type font-name postscript-device-font-name)
  (let ((text-style (make-instance 'clim-internals::device-font-text-style
				   :display-device port
				   :device-font-name font-name)))
    (multiple-value-bind (dict-name ascent descent angle char-infos)
	(with-open-file (stream (postscript-device-font-name-metrics-file font-name)
                                :direction :input
                                :external-format :latin-1)
	  (read-afm-stream stream))
      (define-font-metrics dict-name ascent descent angle char-infos font-name))
    (setf (text-style-mapping port text-style) font-name)
    text-style))
