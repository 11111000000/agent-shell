;;; agent-shell-performance-tests.el --- Performance metrics for agent-shell -*- lexical-binding: t; -*-

(require 'ert)
(require 'agent-shell)
(require 'agent-shell-ui)

(defun agent-shell-performance--metrics-dir ()
  "Return the directory for performance metrics files."
  (expand-file-name ".org/metrics/" (project-root (project-current t))))

(defun agent-shell-performance--measure (fn)
  "Return a plist with timing and GC metrics for FN."
  (let ((gc-before gcs-done)
        (gc-elapsed-before gc-elapsed)
        (cons-before cons-cells-consed)
        (time (benchmark-run 1 (funcall fn))))
    (list :time (nth 0 time)
          :gcs (- gcs-done gc-before)
          :gc-time (- gc-elapsed gc-elapsed-before)
          :conses (- cons-cells-consed cons-before))))

(defmacro agent-shell-performance-with-temp-buffer (&rest body)
  `(with-temp-buffer
     (let ((inhibit-read-only t)
           (buffer-undo-list t)
           (agent-shell-show-busy-indicator nil)
           (agent-shell-show-context-usage-indicator nil)
           (agent-shell-header-style 'text)
           (agent-shell-section-functions nil)
           (agent-shell-highlight-blocks nil))
       ,@body)))

(ert-deftest agent-shell-performance-ui-fragment-baseline-test ()
  "Record baseline metrics for `agent-shell-ui-update-fragment'."
  (agent-shell-performance-with-temp-buffer
    (let* ((major-mode 'agent-shell-mode)
           (state `((:buffer . ,(current-buffer))))
           (result (agent-shell-performance--measure
                    (lambda ()
                      (dotimes (i 20)
                        (agent-shell-ui-update-fragment
                         (agent-shell-ui-make-fragment-model
                          :namespace-id "perf"
                          :block-id (format "tc-%d" i)
                          :label-left "Read"
                          :label-right "file.el"
                          :body (format "line %d\nline %d" i i))
                         :create-new t
                         :expanded t))))))
      (make-directory (agent-shell-performance--metrics-dir) t)
      (with-temp-file (expand-file-name "perf-ui-update-fragment-baseline.org"
                                        (agent-shell-performance--metrics-dir))
        (insert "* Baseline\n\n"
                (format "- time: %.6f\n" (plist-get result :time))
                (format "- gc-time: %.6f\n" (plist-get result :gc-time))
                (format "- gcs: %s\n" (plist-get result :gcs))
                (format "- conses: %s\n" (plist-get result :conses))
                "\n"))
      (should (plist-get result :time)))))

(ert-deftest agent-shell-performance-header-baseline-test ()
  "Record baseline metrics for `agent-shell--make-header'."
  (agent-shell-performance-with-temp-buffer
    (let* ((major-mode 'agent-shell-mode)
           (state `((:buffer . ,(current-buffer))
                    (:session . ((:id . "s-1")
                                 (:model-id . "m-1")
                                 (:modes [((:id . "default") (:name . "Default"))])))
                    (:agent-config . ((:buffer-name . "perf") (:icon-name . nil)))
                    (:usage . ((:context-used . 1000) (:context-size . 2000) (:total-tokens . 1000)))
                    (:heartbeat . ((:status . busy) (:value . 1)))))
           (result (agent-shell-performance--measure
                    (lambda ()
                      (dotimes (_ 200)
                        (agent-shell--make-header state :qualifier "[1/1][View]" :bindings nil))))))
      (make-directory (agent-shell-performance--metrics-dir) t)
      (with-temp-file (expand-file-name "perf-make-header-baseline.org"
                                        (agent-shell-performance--metrics-dir))
        (insert "* Baseline\n\n"
                (format "- time: %.6f\n" (plist-get result :time))
                (format "- gc-time: %.6f\n" (plist-get result :gc-time))
                (format "- gcs: %s\n" (plist-get result :gcs))
                (format "- conses: %s\n" (plist-get result :conses))
                "\n"))
      (should (plist-get result :time)))))

(provide 'agent-shell-performance-tests)
;;; agent-shell-performance-tests.el ends here
