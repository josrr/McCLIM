;;; -*- Mode: Lisp; Package: CLIM-INTERNALS -*-

;;;  (c) copyright 1998,1999,2000 by Michael McDonald (mikemac@mikemac.com)
;;;  (c) copyright 2014 by Robert Strandh (robert.strandh@gmail.com)

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

(in-package :clim-internals)

(defclass graft (sheet-multiple-child-mixin mirrored-sheet-mixin basic-sheet)
  ((orientation :initform :default
		:initarg :orientation
		:reader graft-orientation)
   (units :initform :device
	  :initarg :units
	  :reader graft-units)
   (mirror :initarg :mirror)))

(defun graftp (x)
  (typep x 'graft))

(defmethod graft ((graft graft))
  graft)

(defmethod sheet-grafted-p ((sheet basic-sheet))
  (if (sheet-parent sheet)
      (sheet-grafted-p (sheet-parent sheet))
      nil))

(defmethod sheet-grafted-p ((graft graft))
  t)

(defmethod sheet-viewable-p ((graft graft))
  (sheet-enabled-p graft))

(defmethod sheet-native-transformation ((sheet graft))
  +identity-transformation+)

(defmethod sheet-native-region ((sheet graft))
  +everywhere+)

(defmacro with-graft-locked (graft &body body)
  `(let ((graft ,graft))
     ,@body))

(defmethod graft-pixel-aspect-ratio ((graft graft))
  (let ((x/inch (graft-pixels-per-inch graft :orientation :horizontal))
        (y/inch (graft-pixels-per-inch graft :orientation :vertical)))
    (if (= x/inch y/inch)
        (values 1 1)
        (values x/inch y/inch))))

(defun graft-pixels-per-millimeter (graft &key (orientation :horizontal))
  (ecase orientation
    (:horizontal
     (/ (graft-width graft :units :device)
        (graft-width graft :units :millimeters)))
    (:vertical
     (/ (graft-height graft :units :device)
        (graft-height graft :units :millimeters)))))

(defun graft-pixels-per-inch (graft &key (orientation :horizontal))
  (ecase orientation
    (:horizontal
     (/ (graft-width graft :units :device)
        (graft-width graft :units :inches)))
    (:vertical
     (/ (graft-height graft :units :device)
        (graft-height graft :units :inches)))))

