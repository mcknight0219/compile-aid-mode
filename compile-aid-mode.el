

(defgroup compile-aid-mode nil
  "Displaying compiling results on source code buffer"
  :prefix "ca-"
  :group 'tools)

;;;; Internal variables

(defvar compile-aid-mode nil
  "Dummy variable to suppress compiler warnings.")

(defvar ca-c-compiler "gcc"
  "Default compiler for c source files")

(defvar ca-c++-compiler "g++"
  "Default compiler for c++ source files")

(defvar ca-cflag "-c -std=gnu99 -O2"
  "Compile without linking and disable optimization to 
generate most reliable error messages")

(defvar ca-buffer "ca-output-buffer"
  "Buffer to hold compiling output")

(defvar ca-highlight-line-overlay (make-overlay 1 1)
  "Overlay used to highlight current error/warning line")

(defvar ca-mode-map (make-sparse-keymap)
  "Compile mode map.")

(defvar ca-my-map
  (let ((map (make-sparse-keymap)))
    (define-key map [tab] 'ca-cycle-error)
    (define-key map (kbd "M-TAB") 'ca-cycle-error-only)
    (define-key map (kbd "M-s") 'ca-fetch-and-show-info)
    map))

(defface ca-error-line-face
  '((t (:foreground "white" :background "red")))
  "Face for compile errors"
  :group 'compile-aid)

(defface ca-warning-line-face
  '((t (:foreground "cyan" :background "blue")))
  "Face for compile warnings"
  :group 'compile-aid)

(defface ca-error-col-face
  '((t (:box "yellow")))
  :group 'compile-aid)

(defface ca-warning-col-face
  '((t (:box "green")))
  :group 'compile-aid)

(defun ca-error (&optional var)
  "Report and error and disable `compiler-aid`."
  (ignore-errors
    (message "Fatal error: %s" var)
    var))


(defun ca-check-valid-char (x)
  (eq (string-match "[_A-Za-z0-9\\.]" x) 0)) 

(defun ca-clean-file-name (x)
  (if (eq (length x) 0)
      ""
    (let ((out "") 
	  (in x))
      (while (> (length in) 0)
	(if (ca-check-valid-char in)
	    (setq out (concat out (substring in 0 1))))
	(setq in (substring in 1)))
      out)))

(defun ca-get-buffer-string (buf)
  (let ((old-cb (current-buffer))
	(content nil))
    (if (buffer-live-p buf)
	(progn
	  (set-buffer buf)
	  (setq content (buffer-string))
	  (set-buffer old-cb)))
    content))

(defun ca-debug-list (lst)
  (let ((output ""))
    (if (listp lst)
	(progn
	  (while (> (length lst) 0)
	    (setq output (concat  output " " (number-to-string (car lst))))
	    (setq lst (cdr lst)))))
    (message output)))


(defun ca-erase-buffer ()
  (let ((old (current-buffer))
	(our (get-buffer ca-buffer)))
    (if our
	(progn
	  (set-buffer our)
	  (erase-buffer)
	  (set-buffer old)))))

(defun ca-get-file-name ()
  (expand-file-name
   (ca-clean-file-name 
    (buffer-name))))


(defun ca-check-file-extension (path)
  (let ((ext (file-name-extension path)))
    (cond
     ((string= ext "c"))
     ((string= ext "cpp"))
     ((string= ext "cc")))))

;; choose compiler depending on file extension
(defun ca-choose-compiler (path)
  (if (string= (file-name-extension path) "c")
      ca-c-compiler
    ca-c++-compiler))  

;; insert a space between two concated parts
(defun ca-concat (&rest ns)
  (let* ((orig ns)
	(output nil)
	(i (length ns)))
    (while (>= i 0)
      (setq output (concat (concat (nth i ns) " ") output))
      (setq i (- i 1)))
    (concat output)))
   

;; compile the file and return results as a big string whether
;; it's successful or failing. Nil is returned if there is any
;; error. Inside this function no check is done for extension
;; and such.
(defun ca-compile-file (file)
  (let* ((compiler (ca-choose-compiler file))
	 (cmd (ca-concat compiler ca-cflag file))
	 (buf (get-buffer-create ca-buffer))
	 (ret 0))
    (ca-erase-buffer)
    (setq ret 
	  (call-process-shell-command cmd nil buf))))
     
;; highlight specific line
(defun ca-highlight-line (line type)
  (if (string= type "error")
      (overlay-put ca-highlight-line-overlay 'face 'ca-error-line-face)
    (overlay-put ca-highlight-line-overlay 'face 'ca-warning-line-face))
  (save-excursion
    (let ()
      (goto-line line)
      (let* ((b (line-beginning-position))
	     (e (line-end-position)))
	(overlay-buffer ca-highlight-line-overlay)
	(move-overlay ca-highlight-line-overlay b e (current-buffer))))))


;; stop ca mode and clean resources such as overlay
(defun ca-quit ()
  (setq indexing-result nil)
  (delete-overlay ca-highlight-line-overlay))


(defmacro _get (l k)
  (list 'cdr (list 'assoc k l)))


(defvar indexing-result nil)
(defvar current-error-number nil)
(defun ca-cycle-error ()
  (interactive)
  (let* ((n (length indexing-result))
	 (current 0)
	 (l 0) (c 0))
    (unless (= n 0)
      (if (not current-error-number)
	  (setq current-error-number 0))
      (setq current 
	    (nth current-error-number indexing-result))
      (setq l (string-to-int (cdr (assoc 'line current))))
      (setq c (string-to-int (cdr (assoc 'column current))))	     
      (ca-highlight-line l
			 (cdr (assoc 'type current)))
      (goto-line l)
      (goto-char (- (+ c (line-beginning-position)) 1))
      (message "[%s] %s"
	       (cdr (assoc 'type current))
	       (cdr (assoc 'content current)))
      (setq current-error-number
	    (mod (+ 1 current-error-number) n)))))


(defun ca-cycle-error-only ()
  (interactive)
  (let ((n (length indexing-result))
	(current nil)
	(l 0) (c 0))
    (unless (= n 0)
      (if (not current-error-number)
	  (setq current-error-number 0))
      (setq current 
	    (nth current-error-number indexing-result))
      (while (and (< current-error-number n)
		  (string= "warning" (_get current 'type)))
	(setq current-error-number 
	      (1+ current-error-number))
	(setq current
	      (nth current-error-number indexing-result)))
      (if (= n current-error-number)
	  (setq current-error-number 0)
	(progn
	  (setq l (string-to-int (_get current 'line)))
	  (setq c (string-to-int (_get current 'column)))
	  (ca-highlight-line l "error")
	  (goto-line l)
	  (goto-char (1- (+ c (line-beginning-position))))
	  (message "[error] %s"
		   (_get current 'content))
	  (setq current-error-number
		(mod (1+ current-error-number) n)))))))

;; Show message if there is on on current line.
;; Also move cursor to its column 
(defun ca-fetch-and-show-info ()
  (interactive)
  (let ((i 0)
	(l (line-number-at-pos))
	(c (- (point) (line-beginning-position)))
	(len (length indexing-result))
	(candidates nil))
    (while (< i len)
      (setq current 
	    (nth i indexing-result))
      (if (= l (string-to-int (_get current 'line)))
	     (setq candidates (cons i candidates)))
      (setq i (1+ i)))
    ;; pick the neareast error/warning if there're more 
    ;; than one result
    (setq min most-positive-fixnum)
    (unless (not candidates)
      (dolist (var candidates n)
	(setq current 
	      (nth var indexing-result))
	(setq gap
	      (abs (- (string-to-int (_get current 'column)) c))) 
	(if (< gap min)
	    (progn
	      (setq min gap)
	      (setq n var))))
      (setq current 
	    (nth n indexing-result))
      (goto-char (+ (line-beginning-position)
		    (string-to-int
		     (_get current 'column))))
      (message "[%s] %s"
	       (_get current 'type)
	       (_get current 'content)))))


;; parse the compiling result and organize the data
;; structure for displaying to source file buffer  
(defun ca-parse-buf ()
  (if (not (get-buffer ca-buffer))
      (message "Cannot find compiling buffer")
    (progn
      (if (eq 0 (buffer-size (get-buffer ca-buffer)))
	  (message "Wow! clean compiling")
	(progn
	  (setq indexing-result
		(ca-index-result (get-buffer ca-buffer))))))))

;; determine if compilers exist on machine
(defun ca-check-environment ()
  (let ((cc  (call-process-shell-command ca-c-compiler nil nil))
	(c++ (call-process-shell-command ca-c++-compiler nil nil)))
    (if (or (eq cc 127) (eq c++ 127))
	(progn 
	  (message "Compiler for C or C++ cannot be found")
	  nil)
      t)))

;; extract text from buffer constrained by a pair of marker
;; buffer can be inferred from marker itself
(defun ca-extract-markers (beg end)
  (save-excursion
    (let ((buf (marker-buffer beg))
	   (subs ""))
      (set-buffer buf)
      (setq subs
	    (buffer-substring-no-properties (marker-position beg) (marker-position end)))
      subs)))

(defun ca-extract-position (buf beg end)
  (save-excursion
    (set-buffer buf)
    (buffer-substring-no-properties beg end)))
    

;; index the output of compiler. Extract keywords and group
;; information to relevent keyword which is the used to present
;; to minor mode to display on source buffer
(defun ca-index-result (buffer)
  (let* ((result nil)
	 (old-buf (current-buffer))
	 (header-re "\\([^:]+\\):\\([0-9]+\\):\\([0-9]+\\): \\(error\\|warning\\): \\(.+\\)$"))
    ;; we are only concerned with line with line and column number
    (set-buffer buffer)
    (goto-char (point-min))
    (while (re-search-forward header-re nil t)
      (setq matched (match-data))
      (setq record
	    `((filename . ,(ca-extract-markers (nth 2 matched) (nth 3 matched)))
              (line     . ,(ca-extract-markers (nth 4 matched) (nth 5 matched)))
	      (column   . ,(ca-extract-markers (nth 6 matched) (nth 7 matched)))
	      (type     . ,(ca-extract-markers (nth 8 matched) (nth 9 matched)))
	      (content  . ,(ca-extract-markers (nth 10 matched) (nth 11 matched)))))
      (setq result 
	    (cons record result)))
    (set-buffer old-buf)
    result))
  


;; The starting point 
(defun ca-compile ()
  (let ((filename (ca-get-file-name)))
    (if (not (ca-check-file-extension filename))
	(message "Not a C/C++ source file")
      (progn
	(ca-compile-file filename)
	(ca-parse-buf)
	(if (boundp 'current-error-number)
	    (setq current-error-number 0))
	(ca-cycle-error)
	(if (buffer-live-p (get-buffer ca-buffer))
	    (ca-erase-buffer))))))

(defun ca-handle-after-change ()
  (if (boundp 'ca-highlight-col-overlay)
      (delete-overlay ca-highlight-line-overlay))
  (ca-compile))

 (define-minor-mode compile-aid-mode
   "A minor mode for compile-aid"
   :lighter " CA"
   :keymap ca-mode-map
   :group 'compile-aid
   (if compile-aid-mode
       (progn
	 (ca-compile)
	 (add-hook 'after-save-hook 'ca-handle-after-change nil t)
	 (ca-compile)
	 (use-local-map ca-my-map))
     (remove-hook 'after-save-hook 'ca-handle-after-change t)
     (ca-quit)))
    

(provide 'compile-aid-mode)

;;; compile-aid-mode.el ends here












 