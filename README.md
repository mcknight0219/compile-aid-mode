# compile-aid-mode

Compiling C/C++ source code could be painful especially when wandering
through a junggle of error and warning results. This minor mode helps
this process by showing results directly on source code.

## Usage
Firstly, put `compile-aid-mode.el` to your usual lisp folder

Optionally, you can trigger this mode automatically
```elisp
(add-to-hook 'c-mode-hook
	'(lambda ()
		(compile-aid-mode)))
```

Inside this mode, you can cycle through errors/warnings by pressing `[Tab]`.
You can also just cycle through errors using `[M-TAB]`. If you are on the
right line, you can re-show the message using `[M-s]`.

All highlights are disabled when disabling the mode


