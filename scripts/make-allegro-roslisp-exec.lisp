(in-package :cl-user)

;(load "~/clinit.cl")



(let ((pkg (sys:command-line-argument 1))
	  (system (sys:command-line-argument 2))
	  (entry (sys:command-line-argument 3))
	  (output-path (pathname (sys:command-line-argument 4)))
	  fasls)
  (defmethod asdf:perform :around ((o asdf:load-op)
								   (c asdf:cl-source-file))
	(setf fasls (append fasls (asdf:input-files o c)))
	(call-next-method o c))
  (handler-case
	  (let ((ros-load:*current-ros-package* pkg))
		(asdf:load-system system))
	(error (e)
	  (format *error-output* "Compilation failed due to condition: ~a~&" e)
	  (exit 1)))
  (print fasls)
  
  (let ((tmp-file (sys:make-temp-file-name "ros" "/tmp/")))
	(format t "Writing ROS launch script to: ~a~%" tmp-file)
	(with-open-file (strm tmp-file :if-exists :supersede :direction :output)
	  (format strm "(in-package :cl-user)~%")
	  (format strm
			  "(defun start-ros-app ()
  (handler-bind ((interrupt-signal #'(lambda (c)
                                       (format t \"Shutting Down.\")
									   (invoke-restart 'roslisp:shutdown-ros-node)
									   (exit))))
	(funcall (symbol-function '~a))))" entry))



	(compile-file tmp-file)
	(load tmp-file)

	(cl-user::generate-application
	 (pathname-name output-path)
	 (directory-namestring output-path)
	 (append
	  '(:process :list2 :seq2)
	  '(:defsys)
	  '(:asdf)
	  (list (or (probe-file (pathname "~/clinit.cl"))
				(probe-file (pathname "~/.clinit.cl"))))
	  fasls
	  (list tmp-file))
	 :restart-init-function nil
	 :restart-app-function 'start-ros-app
	 #-mswindows
	 :application-administration
	 #-mswindows ;; Quiet startup (See below for Windows version of this.)
	 '(:resource-command-line "-Q")
	 :read-init-files nil			; don't read ACL init files
	 ;;:init-file-names '(".clinit.cl" "clinit.cl")

	 :print-startup-message nil	; don't print ACL startup messages
	 :ignore-command-line-arguments t ; ignore ACL (not app) cmd line options
	 :suppress-allegro-cl-banner t

	 ;; Adds the compiler, required for loading asdf.
	 :include-compiler t
	 :discard-compiler t
	 
	 ;; Change the following to `t', if:
	 ;; - the program (vs. data) is large
	 ;; - you'll have lots of users of the app (so sharing the code is important)
	 :purify nil
	 
	 ;; don't give autoload warning, but you should still be aware that
	 ;; autoloads.out will contain a list of autoloadable names.
	 :autoload-warning nil
	 
	 :include-debugger nil
	 :include-tpl nil
	 :include-ide nil
	 :include-devel-env nil
	 ;;:include-compiler nil
	 :discard-arglists T
	 :discard-local-name-info T
	 :discard-source-file-info T
	 :discard-xref-info T
	 
	 ;; for debugging:
	 :verbose nil
	 :build-debug nil
	 :build-input nil
	 :build-output nil
	 
	 ;; for file handling
	 :allow-existing-directory t

	 :runtime :standard
	 ))

)
