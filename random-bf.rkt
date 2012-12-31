#lang racket

(provide random-bf)

; generate a random valid bf program
(define (random-bf n)
  (list->string
   (let step ([n n] [stk 0])
     (define c (string-ref "<>+-.,[]" (random 8)))
     (cond
       ; done, just output
       [(= n 0)
        '()]
       ; invalid brackets, skip this
       [(and (eq? c #\]) (= stk 0))
        (step n stk)]
       ; need to finish brackets
       [(= n stk)
        (cons #\] (step (- n 1) (- stk 1)))]
       ; open a bracket
       [(eq? c #\[)
        (cons #\[ (step (- n 1) (+ stk 1)))]
       ; close a bracket
       [(eq? c #\])
        (cons #\] (step (- n 1) (- stk 1)))]
       ; all others
       [else
        (cons c (step (- n 1) stk))]))))