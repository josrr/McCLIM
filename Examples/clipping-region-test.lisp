(in-package :clim-demo)

(defparameter *initial-radius* 25)

(define-application-frame clipping-region-test ()
  ((radius :initform *initial-radius*))
  (:panes
   (canvas (make-pane 'application-pane
                      :name 'canvas
                      :width 500
                      :height 700
                      :max-height 700
                      :min-height 700
                      :display-time nil
                      :display-function 'display-pane
                      :scroll-bars nil))
   (slider (make-pane 'slider-pane
                      :name 'radius
                      :value *initial-radius*
                      :min-value *initial-radius*
                      :max-value 200
                      :orientation :horizontal
                      :value-changed-callback 'change-radius
                      :show-value-p t)))
  (:layouts
   (default
    (vertically (:height 800 :max-height 800 :min-height 800
                 :width 500 :max-width 500 :min-width 500)
      canvas
      (labelling (:label "Radius")
        slider)))))

(defun change-radius (pane value)
  (declare (ignore pane))
  (setf (slot-value *application-frame* 'radius)
        (ceiling value))
  (redisplay-frame-pane *application-frame* 'canvas :force-p t))

(defun display-pane (frame stream)
  (let ((width (ceiling (bounding-rectangle-width (sheet-region stream))))
        (height (ceiling (bounding-rectangle-height (sheet-region stream)))))
    (draw-rectangle* stream 40 40 (- width 40) (- height 40)
                     :ink +red+ :filled t)
    (draw-rectangle* stream 50 50 (- width 50) (- height 50)
                     :ink +gray90+ :filled t)
    (with-drawing-options (stream :clipping-region (make-rectangle* 50 50
                                                                    (- width 50)
                                                                    (- height 50)))
      (draw-circle* stream 50 50 (slot-value frame 'radius) :ink +cyan+)
      (draw-circle* stream (- width 50) (- height 50)
                    (slot-value frame 'radius) :ink +cyan+))
    (draw-text* stream (format nil "~A x ~A"
                               (bounding-rectangle-width (sheet-region stream))
                               (bounding-rectangle-height (sheet-region stream)))
                20 20 :ink +black+)))

(defun run-clipping-region-test ()
  (run-frame-top-level (make-application-frame
                        'clipping-region-test)))


