%%% markup.ily -- generic markup commands
%%%
%%% Author: Nicolas Sceaux <nicolas.sceaux@free.fr>
%%%
%%% Markup commands
%%% ===============
%%%   \vspace <amount>
%%%     like \hspace, but for vertical space
%%%
%%%   \smallCaps <string>
%%%     like built-in \smallCaps, but dealing with accented letters
%%%
%%%   \when-property <symbol> <markup>
%%%     if symbol is find in properties, interpret the markup
%%%     otherwise, return an empty stencil
%%%
%%%   \line-width-ratio <ratio> <markup>
%%%     interpret markup with a line-width set to current line-width * ratio
%%%
%%%   \copyright
%%%     build a copyight line, using the maintainer and copyrightYear
%%%     header variables.
%%%
%%%   \wordwrap-center <markup-list>
%%%     like wordwrap, but center align the lines
%%%
%%% Markup lines commands
%%% =====================
%%%   \wordwrap-center-lines <markup-list>
%%%     make a markup list composed centered lines of text.

#(define-markup-command (vspace layout props amount) (number?)
  "This produces a invisible object taking vertical space."
  (let ((amount (* amount 3.0)))
    (if (> amount 0)
        (ly:make-stencil "" (cons -1 1) (cons 0 amount))
        (ly:make-stencil "" (cons -1 1) (cons amount amount)))))

#(define-markup-command (copyright layout props) ()
  (let* ((maintainer (chain-assoc-get 'header:maintainer props))
         (this-year (+ 1900 (tm:year (gmtime (current-time)))))
         (year (string->number (or (chain-assoc-get 'header:copyrightYear props)
                                   (number->string this-year)))))
    (interpret-markup layout props
     (markup "Copyright ©" 
             (if (= year this-year)
                 (format #f "~a" this-year)
                 (format #f "~a-~a" year this-year))
             maintainer))))

#(define-markup-command (today layout props) ()
  (let ((today (gmtime (current-time))))
   (interpret-markup layout props
     (format #f "~a-~a-~a"
             (+ 1900 (tm:year today))
             (1+ (tm:mon today))
             (tm:mday today)))))

#(define-markup-command (when-property layout props symbol markp) (symbol? markup?)
  (if (chain-assoc-get symbol props)
      (interpret-markup layout props markp)
      (ly:make-stencil '()  '(1 . -1) '(1 . -1))))

#(define-markup-command (apply-fromproperty layout props fn symbol)
  (procedure? symbol?)
  (let ((m (chain-assoc-get symbol props)))
    (if (markup? m)
        (interpret-markup layout props (fn m))
        empty-stencil)))

#(define-markup-command (line-width-ratio layout props width-ratio arg)
  (number? markup?)
  (interpret-markup layout props
   (markup #:override (cons 'line-width (* width-ratio
                                           (chain-assoc-get 'line-width props)))
           arg)))

#(define-markup-list-command (line-width-ratio-lines layout props width-ratio args)
  (number? markup-list?)
  (interpret-markup-list layout props
    (make-override-lines-markup-list
      (cons 'line-width (* width-ratio
                           (chain-assoc-get 'line-width props)))
      args)))

#(define-markup-list-command (wordwrap-center-lines layout props args)
  (markup-list?)
  (map (lambda (stencil)
        (interpret-markup layout props (markup #:fill-line (#:stencil stencil))))
   (interpret-markup-list layout props (make-wordwrap-lines-markup-list args))))

#(define-markup-list-command (centered-lines layout props args)
  (markup-list?)
  (let ((baseline-skip (chain-assoc-get 'baseline-skip props)))
    (space-lines baseline-skip
      (interpret-markup-list layout props
        (map (lambda (arg) (markup #:fill-line (arg)))
             args)))))

#(define-markup-command (wordwrap-center layout props args) (markup-list?)
  (interpret-markup layout props
   (make-column-markup
    (make-wordwrap-center-lines-markup-list args))))

#(define (page-ref-aux layout props label gauge next)
  (let* ((gauge-stencil (interpret-markup layout props gauge))
	 (x-ext (ly:stencil-extent gauge-stencil X))
	 (y-ext (ly:stencil-extent gauge-stencil Y)))
    (ly:make-stencil
     `(delay-stencil-evaluation
       ,(delay (ly:stencil-expr
		(let* ((table (ly:output-def-lookup layout 'label-page-table))
		       (label-page (and (list? table) (assoc label table)))
		       (page-number (and label-page (cdr label-page)))
		       (page-markup (if page-number
                                        (markup #:concat ((format "~a" page-number) next))
                                        "?"))
		       (page-stencil (interpret-markup layout props page-markup))
		       (gap (- (interval-length x-ext)
			       (interval-length (ly:stencil-extent page-stencil X)))))
		  (interpret-markup layout props
				    (markup #:concat (page-markup #:hspace gap)))))))
     x-ext
     y-ext)))

#(define-markup-command (page-refI layout props label next)
  (symbol? markup?)
  (page-ref-aux layout props label "0" next))

#(define-markup-command (page-refII layout props label next)
  (symbol? markup?)
  (page-ref-aux layout props label "00" next))

#(define-markup-command (page-refIII layout props label next)
  (symbol? markup?)
  (page-ref-aux layout props label "000" next))

#(define-markup-command (super layout props arg) (markup?)
  (ly:stencil-translate-axis
   (interpret-markup
    layout
    (cons `((font-size . ,(- (chain-assoc-get 'font-size props 0) 3))) props)
    arg)
   (* 0.25 (chain-assoc-get 'baseline-skip props))
   Y))

#(define-markup-list-command (paragraph layout props text) (markup-list?)
  (let ((indentation (markup #:pad-to-box (cons 0 3) (cons 0 0) #:null)))
    (interpret-markup-list layout props
       (make-justified-lines-markup-list (cons indentation text)))))

#(define-markup-list-command (columns paper props text) (markup-list?)
  (interpret-markup-list paper props
    (make-column-lines-markup-list text)))

#(define-markup-command (separation-line layout props width) (number?)
  (interpret-markup layout props
   (markup #:fill-line (#:draw-line (cons (/ (* 20 width) (*staff-size*)) 0)))))

#(define-markup-command (boxed-justify layout props text) (markup-list?)
  (interpret-markup layout props
   (make-override-markup '(box-padding . 1)
    (make-box-markup
     (make-column-markup
      (make-justified-lines-markup-list text))))))

%%% Guile does not deal with accented letters
#(use-modules (ice-9 regex))
%%;; actually defined below, in a closure
#(define-public string-upper-case #f)
#(define accented-char-upper-case? #f)
#(define accented-char-lower-case? #f)

%%;; an accented character is seen as two characters by guile
#(let ((lower-case-accented-string "éèêëáàâäíìîïóòôöúùûüçœæ")
       (upper-case-accented-string "ÉÈÊËÁÀÂÄÍÌÎÏÓÒÔÖÚÙÛÜÇŒÆ"))
   (define (group-by-2 chars result)
      (if (or (null? chars) (null? (cdr chars)))
          (reverse! result)
          (group-by-2 (cddr chars)
                      (cons (string (car chars) (cadr chars))
                            result))))
   (let ((lower-case-accented-chars
          (group-by-2 (string->list lower-case-accented-string) (list)))
         (upper-case-accented-chars
          (group-by-2 (string->list upper-case-accented-string) (list))))
     (set! string-upper-case
           (lambda (str)
             (define (replace-chars str froms tos)
               (if (null? froms)
                   str
                   (replace-chars (regexp-substitute/global #f (car froms) str
                                                            'pre (car tos) 'post)
                                  (cdr froms)
                                  (cdr tos))))
             (string-upcase (replace-chars str
                                           lower-case-accented-chars
                                           upper-case-accented-chars))))
     (set! accented-char-upper-case?
           (lambda (char1 char2)
             (member (string char1 char2) upper-case-accented-chars string=?)))
     (set! accented-char-lower-case?
           (lambda (char1 char2)
             (member (string char1 char2) lower-case-accented-chars string=?)))))

#(define-markup-command (smallCaps layout props text) (markup?)
  "Turn @code{text}, which should be a string, to small caps.
@example
\\markup \\small-caps \"Text between double quotes\"
@end example"
  (define (string-list->markup strings lower)
    (let ((final-string (string-upper-case
                         (apply string-append (reverse strings)))))
      (if lower
          (markup #:fontsize -2 final-string)
          final-string)))
  (define (make-small-caps rest-chars currents current-is-lower prev-result)
    (if (null? rest-chars)
        (make-concat-markup (reverse! (cons (string-list->markup
                                              currents current-is-lower)
                                            prev-result)))
        (let* ((ch1 (car rest-chars))
               (ch2 (and (not (null? (cdr rest-chars))) (cadr rest-chars)))
               (this-char-string (string ch1))
               (is-lower (char-lower-case? ch1))
               (next-rest-chars (cdr rest-chars)))
          (cond ((and ch2 (accented-char-lower-case? ch1 ch2))
                 (set! this-char-string (string ch1 ch2))
                 (set! is-lower #t)
                 (set! next-rest-chars (cddr rest-chars)))
                ((and ch2 (accented-char-upper-case? ch1 ch2))
                 (set! this-char-string (string ch1 ch2))
                 (set! is-lower #f)
                 (set! next-rest-chars (cddr rest-chars))))
          (if (or (and current-is-lower is-lower)
                  (and (not current-is-lower) (not is-lower)))
              (make-small-caps next-rest-chars
                               (cons this-char-string currents)
                               is-lower
                               prev-result)
              (make-small-caps next-rest-chars
                               (list this-char-string)
                               is-lower
                               (if (null? currents)
                                   prev-result
                                   (cons (string-list->markup
                                            currents current-is-lower)
                                         prev-result)))))))
  (interpret-markup layout props
    (if (string? text)
        (make-small-caps (string->list text) (list) #f (list))
        text)))